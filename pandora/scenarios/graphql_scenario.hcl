# =============================================================================
# GraphQL Scenario: Login mutation → products query → createOrder mutation
#
# GraphQL в Pandora = обычный HTTP POST на /graphql
# Используем тип: http/scenario
#
# Запуск:
#   pandora graphql_config.yaml
#
# Для ручной проверки: http://localhost:8080/graphiql
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

variable_source "search_terms" "variables" {
  variables = {
    terms = "laptop,phone,book,watch,shoes"
  }
}

# ── Локальные переменные ──────────────────────────────────────────────────────

locals {
  graphql_headers = {
    Content-Type = "application/json"
    Accept       = "application/json"
  }
}

# ── Запросы ───────────────────────────────────────────────────────────────────

# Mutation: login
request "gql_login" {
  method  = "POST"
  uri     = "/graphql"
  headers = local.graphql_headers
  tag     = "gql_login"

  preprocessor {
    mapping = {
      user = "source.users[next]"
    }
  }

  body = <<EOF
{
  "operationName": "Login",
  "query": "mutation Login($login: String!, $password: String!) { login(login: $login, password: $password) { token userId } }",
  "variables": {
    "login":    "{{.request.gql_login.preprocessor.user.login}}",
    "password": "{{.request.gql_login.preprocessor.user.password}}"
  }
}
EOF

  # ВАЖНО: GraphQL всегда возвращает HTTP 200, даже при ошибках
  # Ошибки лежат в $.errors, успех — в $.data
  postprocessor "var/jsonpath" {
    mapping = {
      token  = "$.data.login.token"
      userId = "$.data.login.userId"
    }
  }

  postprocessor "assert/response" {
    status_code = 200
    body        = ["data"]  # нет поля errors
  }
}

# Query: поиск продуктов
request "gql_search_products" {
  method  = "POST"
  uri     = "/graphql"
  headers = local.graphql_headers
  tag     = "gql_products"

  body = <<EOF
{
  "operationName": "SearchProducts",
  "query": "query SearchProducts($search: String, $limit: Int) { products(search: $search, limit: $limit) { id name category price stock } }",
  "variables": {
    "search": "{{randString 3 5}}",
    "limit":  10
  }
}
EOF

  postprocessor "assert/response" {
    status_code = 200
    body        = ["data"]
  }
}

# Query: конкретный продукт
request "gql_get_product" {
  method  = "POST"
  uri     = "/graphql"
  headers = local.graphql_headers
  tag     = "gql_product_detail"

  preprocessor {
    mapping = {
      prod_id = "source.products[rand].product_id"
    }
  }

  body = <<EOF
{
  "operationName": "GetProduct",
  "query": "query GetProduct($id: ID!) { product(id: $id) { id name price stock } }",
  "variables": {
    "id": "{{.request.gql_get_product.preprocessor.prod_id}}"
  }
}
EOF

  postprocessor "var/jsonpath" {
    mapping = {
      product_id = "$.data.product.id"
    }
  }

  postprocessor "assert/response" {
    status_code = 200
  }
}

# Mutation: создание заказа
request "gql_create_order" {
  method  = "POST"
  uri     = "/graphql"
  headers = local.graphql_headers
  tag     = "gql_create_order"

  body = <<EOF
{
  "operationName": "CreateOrder",
  "query": "mutation CreateOrder($token: String!, $productId: String!, $quantity: Int) { createOrder(token: $token, productId: $productId, quantity: $quantity) { id status total } }",
  "variables": {
    "token":     "{{.request.gql_login.postprocessor.token}}",
    "productId": "{{.request.gql_get_product.postprocessor.product_id}}",
    "quantity":  {{randInt 1 3}}
  }
}
EOF

  postprocessor "assert/response" {
    status_code = 200
    body        = ["data"]
  }
}

# Query: мои заказы
request "gql_my_orders" {
  method  = "POST"
  uri     = "/graphql"
  headers = local.graphql_headers
  tag     = "gql_orders"

  body = <<EOF
{
  "operationName": "MyOrders",
  "query": "query MyOrders($userId: String!, $limit: Int) { orders(userId: $userId, limit: $limit) { id status total productId } }",
  "variables": {
    "userId": "{{.request.gql_login.postprocessor.userId}}",
    "limit":  5
  }
}
EOF

  postprocessor "assert/response" {
    status_code = 200
  }
}

# ── Сценарии ──────────────────────────────────────────────────────────────────

# Полный GraphQL флоу с покупкой
scenario "gql_buyer" {
  weight           = 40
  min_waiting_time = 2000

  requests = [
    "gql_login",
    "sleep(150)",
    "gql_search_products",
    "sleep(300)",
    "gql_get_product",
    "sleep(400)",
    "gql_create_order",
    "sleep(100)",
    "gql_my_orders",
  ]
}

# Только чтение — поиск и просмотр
scenario "gql_browser" {
  weight           = 60
  min_waiting_time = 500

  requests = [
    "gql_search_products(3, 200)",  # 3 страницы поиска
    "sleep(200)",
    "gql_get_product(2, 150)",
  ]
}
