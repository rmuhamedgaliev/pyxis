# =============================================================================
# gRPC Scenario: Auth → CreateOrder → ListOrders
#
# Запуск:
#   pandora grpc_config.yaml
#
# Для проверки вручную:
#   grpcurl -plaintext localhost:9090 list
#   grpcurl -plaintext -d '{"login":"user001","password":"pass001"}' \
#     localhost:9090 order.AuthService/Login
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

# ── gRPC Calls ────────────────────────────────────────────────────────────────

# Шаг 1: Авторизация
call "grpc_auth" {
  call = "order.AuthService.Login"
  tag  = "grpc_auth"

  metadata = {
    "x-request-id" = "{{uuid}}"
  }

  preprocessor "prepare" {
    mapping = {
      user = "source.users[next]"
    }
  }

  payload = <<EOF
{
  "login":    "{{.request.grpc_auth.preprocessor.user.login}}",
  "password": "{{.request.grpc_auth.preprocessor.user.password}}"
}
EOF

  postprocessor "assert/response" {
    payload     = ["token", "user_id"]
    status_code = 200
  }
}

# Шаг 2: Создание заказа (используем userId из ответа на auth)
call "grpc_create_order" {
  call = "order.OrderService.CreateOrder"
  tag  = "grpc_create_order"

  metadata = {
    "x-request-id" = "{{uuid}}"
  }

  preprocessor "prepare" {
    mapping = {
      product = "source.products[rand]"
    }
  }

  payload = <<EOF
{
  "user_id":    "{{.request.grpc_auth.postprocessor.user_id}}",
  "product_id": "{{.request.grpc_create_order.preprocessor.product.product_id}}",
  "quantity":  {{randInt 1 5}}
}
EOF

  postprocessor "assert/response" {
    payload     = ["order_id"]
    status_code = 200
  }
}

# Шаг 3: Список заказов пользователя
call "grpc_list_orders" {
  call = "order.OrderService.ListOrders"
  tag  = "grpc_list_orders"

  metadata = {
    "x-request-id" = "{{uuid}}"
  }

  payload = <<EOF
{
  "user_id": "{{.request.grpc_auth.postprocessor.user_id}}",
  "limit":  10
}
EOF

  postprocessor "assert/response" {
    status_code = 200
  }
}

# ── Сценарии ──────────────────────────────────────────────────────────────────

scenario "grpc_full_flow" {
  weight           = 60
  min_waiting_time = 500

  requests = [
    "grpc_auth",
    "sleep(50)",
    "grpc_create_order",
    "sleep(100)",
    "grpc_list_orders",
  ]
}

scenario "grpc_read_only" {
  weight           = 40
  min_waiting_time = 200

  requests = [
    "grpc_auth",
    "sleep(50)",
    "grpc_list_orders(2, 100)",  # 2 раза
  ]
}
