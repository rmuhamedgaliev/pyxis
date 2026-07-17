# Pandora Workshop

Учебное Spring Boot приложение для нагрузочного тестирования через Yandex Pandora. В проекте есть HTTP REST, GraphQL, gRPC, мониторинг через Actuator/Prometheus/Grafana и сбор логов в Loki.

## Требования

- JDK 25
- Docker + Docker Compose
- `make`
- Pandora CLI в `PATH`: `pandora`

## Быстрый старт

```bash
make up
make health
make grafana
```

Сервисы:

- App: `http://localhost:8080`
- gRPC: `localhost:9090`
- Prometheus: `http://localhost:9091`
- Grafana metrics: `http://localhost:3000/d/pandora-target-app/pandora-target-app`
- Grafana logs: `http://localhost:3000/d/pandora-target-app-logs/pandora-target-app-logs`

Остановка:

```bash
make down
```

## Makefile

Основные команды:

```bash
make build
make up
make restart
make ps
make logs-app
make health
make metrics
```

Pandora scenario-стрельбы:

```bash
make shoot-http
make shoot-grpc
make shoot-graphql
```

Pandora jsonline-стрельбы без HCL-сценариев:

```bash
make shoot-http-jsonline
make shoot-grpc-jsonline
make shoot-graphql-jsonline
```

Короткие прогоны:

```bash
make shoot-http-short DURATION=25s
make shoot-http-jsonline-short DURATION=25s
make shoot-all-short DURATION=25s
make shoot-all-jsonline-short DURATION=25s
```

Специальные stress-профили:

```bash
make shoot-threads-jsonline-short DURATION=30s
make shoot-oom-jsonline-short DURATION=12s
```

## Структура

```text
.
├── app/                         # Spring Boot app, Java 25
│   ├── Dockerfile
│   └── src/main/
│       ├── java/com/workshop/app/
│       │   ├── controller/      # REST + debug endpoints
│       │   ├── graphql/         # GraphQL mappings
│       │   ├── grpc/            # gRPC services
│       │   ├── observability/   # access logs + custom thread metrics
│       │   └── service/         # in-memory StoreService
│       ├── proto/order.proto
│       └── resources/
├── monitoring/
│   ├── prometheus.yml
│   ├── loki-config.yml
│   ├── promtail-config.yml
│   └── grafana/
├── pandora/
│   ├── ammo/                    # csv + jsonline ammo
│   ├── scenarios/               # HCL scenarios
│   ├── *_config.yaml            # scenario configs
│   └── *_jsonline_config.yaml   # jsonline configs
├── docker-compose.yml
└── Makefile
```

## Приложение

HTTP REST и GraphQL работают на `8080`, gRPC на `9090`.

Проверка:

```bash
curl http://localhost:8080/ping
curl http://localhost:8080/actuator/prometheus
```

REST:

- `POST /api/auth/login`
- `GET /api/v1/products`
- `GET /api/v1/products/{productId}`
- `POST /api/v1/orders`
- `GET /api/v1/orders`
- `GET /api/v1/orders/{orderId}`

GraphQL:

- endpoint: `POST /graphql`
- GraphiQL: `http://localhost:8080/graphiql`

gRPC:

- `order.AuthService/Login`
- `order.OrderService/CreateOrder`
- `order.OrderService/ListOrders`
- reflection включён.

## Мониторинг

Prometheus scrape:

```text
app:8080/actuator/prometheus
```

Grafana содержит два дашборда:

- `Pandora Target App` - latency p50/p95/p99/p99.9, RPS, error rate, heap, GC, HTTP/gRPC/JVM threads, CPU, file descriptors, access logs.
- `Pandora Target App Logs` - общий поток логов приложения, log count и access table.

Access log пишется асинхронно в читаемом `logfmt`:

```text
event=access route=/ping method=GET code=200 request_id=... duration_ms=19
```

`/actuator/*` исключён из access log.

## Pandora

Scenario-конфиги используют HCL:

- `pandora/http_config.yaml`
- `pandora/grpc_config.yaml`
- `pandora/graphql_config.yaml`

Jsonline-конфиги без сценариев:

- `pandora/http_jsonline_config.yaml`
- `pandora/grpc_jsonline_config.yaml`
- `pandora/graphql_jsonline_config.yaml`

Результаты Pandora пишутся в:

```text
pandora/results/
```

Папка игнорируется Git. Очистка:

```bash
make clean-phout
```

### Визуализация phout-логов

Требования: `uv` в `PATH`.

```bash
# Все phout-файлы из pandora/results/
make phout

# Конкретный файл
make phout PHOUT_FILE=pandora/results/http_phout.log

# Своя папка для вывода
make phout PHOUT_OUT=pandora/results/charts
```

Графики сохраняются в `pandora/results/charts/` (по одному PNG на файл):

- RPS по времени
- Response time p50/p95/p99 по времени
- Error rate по времени
- Гистограмма распределения времени ответа
- Перцентили по сценариям
- Распределение статус-кодов

## Stress Examples

### Thread Pool Saturation

Tomcat pool намеренно ограничен:

```yaml
server.tomcat.threads.max: 32
server.tomcat.accept-count: 64
```

Ручка:

```text
GET /debug/threads/block?ms=5000
```

Запуск:

```bash
make shoot-threads-jsonline-short DURATION=30s
```

Что смотреть:

- `HTTP, gRPC and JVM threads`
- `HTTP waiting`
- p99/p99.9 latency
- `discarded` в `pandora/results/threads_jsonline_phout.log`

### OOM / Crash

Ручки:

```text
GET /debug/oom/allocate?mb=64
DELETE /debug/oom/reset
```

Запуск:

```bash
make shoot-oom-jsonline-short DURATION=12s
```

JVM настроена на:

- heap dump on OOM
- crash on OOM
- fatal error log
- попытку core dump

Артефакты пишутся в:

```text
app/crash-dumps/
```

Папка игнорируется Git. Очистка:

```bash
make clean-crash-dumps
```

Проверка конфигурации crash/core:

```bash
make crash-info
```

Если `kernel.core_pattern` на хосте начинается с `|`, Linux отдаёт ELF core dump системному обработчику, например `systemd-coredump`, а не пишет `core.*` в директорию проекта. Heap dump и `hs_err_pid*.log` всё равно пишутся в `app/crash-dumps/`.

## Generated Artifacts

Игнорируются Git:

- `pandora/results/`
- `app/crash-dumps/`
- `app/heap-dumps/` legacy
- `*.log`
- Gradle build/cache directories

Очистка:

```bash
make clean-phout
make clean-crash-dumps
```

## Notes

- Хранилище in-memory, база данных не нужна.
- Авторизация упрощена: логин принимает любой непустой login.
- `StoreService` намеренно добавляет задержки, чтобы графики под нагрузкой были выразительными.
- GraphQL в учебных сценариях передаёт токен аргументом, без HTTP Authorization header.
