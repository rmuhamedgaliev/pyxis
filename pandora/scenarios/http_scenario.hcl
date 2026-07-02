# =============================================================================
# HTTP Scenario: User Journey
# Покрывает: авторизация → просмотр продуктов → создание заказа → список заказов
#
# Запуск:
#   pandora http_config.yaml
# =============================================================================

# ── Источники данных ──────────────────────────────────────────────────────────

variable_source "users" "file/csv" {
  file              = "ammo/users.csv"
  fields            = ["login", "password"]
  ignore_first_line = true
  delimiter         = ","
}

variable_source "products" "file/csv" {
  file              = "ammo/products.csv"
  fields            = ["product_id"]
  ignore_first_line = true
  delimiter         = ","
}

# ── Локальные переменные (переиспользуемые заголовки) ─────────────────────────

locals {
  json_headers = {
    Content-Type = "application/json"
    Accept       = "application/json"
  }
}

# ── Запросы ───────────────────────────────────────────────────────────────────

# Шаг 1: Авторизация — получаем токен
request "auth" {
  method  = "POST"
  uri     = "/api/auth/login"
  headers = local.json_headers
  tag     = "auth"

  # Препроцессор: берём следующего юзера из CSV
  preprocessor {
    mapping = {
      login    = "source.users[next].login"
      password = "source.users[next].password"
    }
  }

  body = <<EOF
{"login": "{{.request.auth.preprocessor.login}}", "password": "{{.request.auth.preprocessor.password}}"}
EOF

  # Постпроцессор: сохраняем токен для следующих шагов
  postprocessor "var/jsonpath" {
    mapping = {
      token  = "$.token"
      userId = "$.userId"
    }
  }

  postprocessor "assert/response" {
    status_code = 200
    body        = ["token", "userId"]
  }
}

# Шаг 2: Листаем продукты (тяжёлый запрос — поиск)
request "search_products" {
  method  = "GET"
  uri     = "/api/v1/products?limit=10"
  headers = local.json_headers
  tag     = "products_list"

  postprocessor "assert/response" {
    status_code = 200
  }
}

# Шаг 3: Смотрим конкретный продукт
request "get_product" {
  method  = "GET"
  tag     = "product_detail"
  headers = local.json_headers

  preprocessor {
    mapping = {
      prod = "source.products[rand].product_id"
    }
  }

  uri = "/api/v1/products/{{.request.get_product.preprocessor.prod}}"

  postprocessor "var/jsonpath" {
    mapping = {
      selected_product = "$.id"
    }
  }

  postprocessor "assert/response" {
    status_code = 200
  }
}

# Шаг 4: Создаём заказ (используем токен из auth и продукт из get_product)
request "create_order" {
  method = "POST"
  uri    = "/api/v1/orders"
  tag    = "order_create"

  headers = merge(local.json_headers, {
    Authorization = "Bearer {{.request.auth.postprocessor.token}}"
  })

  body = <<EOF
{
  "productId": "{{.request.get_product.postprocessor.selected_product}}",
  "quantity": {{randInt 1 5}}
}
EOF

  postprocessor "var/jsonpath" {
    mapping = {
      order_id = "$.orderId"
    }
  }

  postprocessor "assert/response" {
    status_code = 201
    body        = ["orderId"]
  }
}

# Шаг 5: Смотрим свои заказы
request "list_orders" {
  method = "GET"
  uri    = "/api/v1/orders?limit=5"
  tag    = "orders_list"

  headers = merge(local.json_headers, {
    Authorization = "Bearer {{.request.auth.postprocessor.token}}"
  })

  postprocessor "assert/response" {
    status_code = 200
  }
}

# Шаг 6: Смотрим конкретный заказ (используем order_id из create_order)
request "get_order" {
  method = "GET"
  tag    = "order_detail"

  headers = merge(local.json_headers, {
    Authorization = "Bearer {{.request.auth.postprocessor.token}}"
  })

  uri = "/api/v1/orders/{{.request.create_order.postprocessor.order_id}}"

  postprocessor "assert/response" {
    status_code = 200
  }
}

# ── Сценарии ──────────────────────────────────────────────────────────────────

# Сценарий 1: "Покупатель" — полный флоу с заказом (30% трафика)
scenario "buyer_journey" {
  weight           = 30
  min_waiting_time = 3000  # минимум 3 сек на сценарий

  requests = [
    "auth",
    "sleep(200)",
    "search_products",
    "sleep(300)",
    "get_product",
    "sleep(500)",       # пауза "думаю, покупать или нет"
    "create_order",
    "sleep(100)",
    "get_order",
  ]
}

# Сценарий 2: "Браузер" — смотрит, но не покупает (70% трафика)
scenario "browse_only" {
  weight           = 70
  min_waiting_time = 1000

  requests = [
    "auth",
    "sleep(100)",
    "search_products(3, 200)",  # 3 раза с паузой 200мс — листает страницы
    "sleep(200)",
    "list_orders",
  ]
}
