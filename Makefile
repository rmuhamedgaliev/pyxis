SHELL := /usr/bin/env bash

APP_DIR := app
PANDORA_DIR := pandora
PANDORA_RESULTS_DIR := $(PANDORA_DIR)/results
CRASH_DUMP_DIR := $(APP_DIR)/crash-dumps
GRADLE_USER_HOME := $(CURDIR)/$(APP_DIR)/.gradle
PANDORA ?= pandora
DURATION ?= 25s

DOCKER_COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo "docker compose"; fi)

.DEFAULT_GOAL := help

.PHONY: help
help:
	@printf "%s\n" "Targets:"
	@printf "  %-18s %s\n" "build" "Build Spring Boot app with Gradle"
	@printf "  %-18s %s\n" "run-local" "Run app locally with Gradle bootRun"
	@printf "  %-18s %s\n" "up" "Start app + Prometheus + Loki + Promtail + Grafana"
	@printf "  %-18s %s\n" "down" "Stop compose stack"
	@printf "  %-18s %s\n" "restart" "Rebuild and restart compose stack"
	@printf "  %-18s %s\n" "ps" "Show compose services"
	@printf "  %-18s %s\n" "logs" "Follow all compose logs"
	@printf "  %-18s %s\n" "logs-app" "Follow application logs"
	@printf "  %-18s %s\n" "health" "Check application /ping"
	@printf "  %-18s %s\n" "metrics" "Check actuator Prometheus endpoint"
	@printf "  %-18s %s\n" "shoot-http" "Run full HTTP Pandora scenario"
	@printf "  %-18s %s\n" "shoot-grpc" "Run full gRPC Pandora scenario"
	@printf "  %-18s %s\n" "shoot-graphql" "Run full GraphQL Pandora scenario"
	@printf "  %-18s %s\n" "shoot-http-jsonline" "Run full HTTP jsonline ammo"
	@printf "  %-18s %s\n" "shoot-grpc-jsonline" "Run full gRPC jsonline ammo"
	@printf "  %-18s %s\n" "shoot-graphql-jsonline" "Run full GraphQL jsonline ammo"
	@printf "  %-18s %s\n" "shoot-threads-jsonline" "Run HTTP thread pool saturation ammo"
	@printf "  %-18s %s\n" "shoot-oom-jsonline" "Run dangerous OOM jsonline ammo"
	@printf "  %-18s %s\n" "shoot-http-short" "Run HTTP scenario for DURATION=$(DURATION)"
	@printf "  %-18s %s\n" "shoot-grpc-short" "Run gRPC scenario for DURATION=$(DURATION)"
	@printf "  %-18s %s\n" "shoot-graphql-short" "Run GraphQL scenario for DURATION=$(DURATION)"
	@printf "  %-18s %s\n" "shoot-http-jsonline-short" "Run HTTP jsonline ammo for DURATION=$(DURATION)"
	@printf "  %-18s %s\n" "shoot-grpc-jsonline-short" "Run gRPC jsonline ammo for DURATION=$(DURATION)"
	@printf "  %-18s %s\n" "shoot-graphql-jsonline-short" "Run GraphQL jsonline ammo for DURATION=$(DURATION)"
	@printf "  %-18s %s\n" "shoot-threads-jsonline-short" "Run thread pool saturation ammo for DURATION=$(DURATION)"
	@printf "  %-18s %s\n" "shoot-oom-jsonline-short" "Run dangerous OOM ammo for DURATION=$(DURATION)"
	@printf "  %-18s %s\n" "shoot-all-short" "Run all short scenarios sequentially"
	@printf "  %-18s %s\n" "shoot-all-jsonline-short" "Run all short jsonline ammos sequentially"
	@printf "  %-18s %s\n" "results" "Create and list Pandora results directory"
	@printf "  %-18s %s\n" "crash-dumps" "Create and list JVM crash dump directory"
	@printf "  %-18s %s\n" "crash-info" "Show JVM crash/core dump configuration"
	@printf "  %-18s %s\n" "heap-dumps" "Alias for crash-dumps"
	@printf "  %-18s %s\n" "clean-phout" "Remove Pandora phout logs"
	@printf "  %-18s %s\n" "clean-crash-dumps" "Remove JVM crash dumps"
	@printf "  %-18s %s\n" "clean-heap-dumps" "Alias for clean-crash-dumps"

.PHONY: build
build:
	cd $(APP_DIR) && GRADLE_USER_HOME=$(GRADLE_USER_HOME) ./gradlew clean build

.PHONY: run-local
run-local:
	cd $(APP_DIR) && GRADLE_USER_HOME=$(GRADLE_USER_HOME) ./gradlew bootRun

.PHONY: up
up: crash-dumps
	$(DOCKER_COMPOSE) up -d --build

.PHONY: down
down:
	$(DOCKER_COMPOSE) down

.PHONY: restart
restart: crash-dumps
	$(DOCKER_COMPOSE) up -d --build

.PHONY: ps
ps:
	$(DOCKER_COMPOSE) ps

.PHONY: logs
logs:
	$(DOCKER_COMPOSE) logs -f

.PHONY: logs-app
logs-app:
	$(DOCKER_COMPOSE) logs -f app

.PHONY: health
health:
	curl -fsS http://localhost:8080/ping

.PHONY: metrics
metrics:
	curl -fsS http://localhost:8080/actuator/prometheus >/dev/null
	@printf "%s\n" "OK: http://localhost:8080/actuator/prometheus"

.PHONY: grafana
grafana:
	@printf "%s\n" "Metrics: http://localhost:3000/d/pandora-target-app/pandora-target-app"
	@printf "%s\n" "Logs:    http://localhost:3000/d/pandora-target-app-logs/pandora-target-app-logs"

.PHONY: shoot-http
shoot-http: prepare-shoot
	cd $(PANDORA_DIR) && $(PANDORA) http_config.yaml

.PHONY: shoot-grpc
shoot-grpc: prepare-shoot
	cd $(PANDORA_DIR) && $(PANDORA) grpc_config.yaml

.PHONY: shoot-graphql
shoot-graphql: prepare-shoot
	cd $(PANDORA_DIR) && $(PANDORA) graphql_config.yaml

.PHONY: shoot-http-jsonline
shoot-http-jsonline: prepare-shoot
	cd $(PANDORA_DIR) && $(PANDORA) http_jsonline_config.yaml

.PHONY: shoot-grpc-jsonline
shoot-grpc-jsonline: prepare-shoot
	cd $(PANDORA_DIR) && $(PANDORA) grpc_jsonline_config.yaml

.PHONY: shoot-graphql-jsonline
shoot-graphql-jsonline: prepare-shoot
	cd $(PANDORA_DIR) && $(PANDORA) graphql_jsonline_config.yaml

.PHONY: shoot-threads-jsonline
shoot-threads-jsonline: prepare-shoot
	cd $(PANDORA_DIR) && $(PANDORA) threads_jsonline_config.yaml

.PHONY: shoot-oom-jsonline
shoot-oom-jsonline: prepare-shoot
	cd $(PANDORA_DIR) && $(PANDORA) oom_jsonline_config.yaml

.PHONY: shoot-http-short
shoot-http-short: prepare-shoot
	cd $(PANDORA_DIR) && timeout $(DURATION) $(PANDORA) http_config.yaml; code=$$?; test $$code -eq 0 -o $$code -eq 124

.PHONY: shoot-grpc-short
shoot-grpc-short: prepare-shoot
	cd $(PANDORA_DIR) && timeout $(DURATION) $(PANDORA) grpc_config.yaml; code=$$?; test $$code -eq 0 -o $$code -eq 124

.PHONY: shoot-graphql-short
shoot-graphql-short: prepare-shoot
	cd $(PANDORA_DIR) && timeout $(DURATION) $(PANDORA) graphql_config.yaml; code=$$?; test $$code -eq 0 -o $$code -eq 124

.PHONY: shoot-http-jsonline-short
shoot-http-jsonline-short: prepare-shoot
	cd $(PANDORA_DIR) && timeout $(DURATION) $(PANDORA) http_jsonline_config.yaml; code=$$?; test $$code -eq 0 -o $$code -eq 124

.PHONY: shoot-grpc-jsonline-short
shoot-grpc-jsonline-short: prepare-shoot
	cd $(PANDORA_DIR) && timeout $(DURATION) $(PANDORA) grpc_jsonline_config.yaml; code=$$?; test $$code -eq 0 -o $$code -eq 124

.PHONY: shoot-graphql-jsonline-short
shoot-graphql-jsonline-short: prepare-shoot
	cd $(PANDORA_DIR) && timeout $(DURATION) $(PANDORA) graphql_jsonline_config.yaml; code=$$?; test $$code -eq 0 -o $$code -eq 124

.PHONY: shoot-threads-jsonline-short
shoot-threads-jsonline-short: prepare-shoot
	cd $(PANDORA_DIR) && timeout $(DURATION) $(PANDORA) threads_jsonline_config.yaml; code=$$?; test $$code -eq 0 -o $$code -eq 124

.PHONY: shoot-oom-jsonline-short
shoot-oom-jsonline-short: prepare-shoot
	cd $(PANDORA_DIR) && timeout $(DURATION) $(PANDORA) oom_jsonline_config.yaml; code=$$?; test $$code -eq 0 -o $$code -eq 124

.PHONY: shoot-all-short
shoot-all-short: shoot-http-short shoot-grpc-short shoot-graphql-short

.PHONY: shoot-all-jsonline-short
shoot-all-jsonline-short: shoot-http-jsonline-short shoot-grpc-jsonline-short shoot-graphql-jsonline-short

.PHONY: results
results:
	mkdir -p $(PANDORA_RESULTS_DIR)
	@printf "%s\n" "$(PANDORA_RESULTS_DIR)"

.PHONY: crash-dumps
crash-dumps:
	mkdir -p $(CRASH_DUMP_DIR)
	@printf "%s\n" "$(CRASH_DUMP_DIR)"

.PHONY: crash-info
crash-info: crash-dumps
	@printf "%s\n" "Crash artifacts directory: $(CRASH_DUMP_DIR)"
	@printf "%s\n" "JVM writes heap dumps (*.hprof) and fatal error logs (hs_err_pid*.log) there."
	@printf "%s" "Host core_pattern: "
	@cat /proc/sys/kernel/core_pattern
	@printf "%s\n" "If core_pattern starts with '|', Linux sends ELF core dumps to that host handler instead of writing core.* into the project directory."

.PHONY: heap-dumps
heap-dumps: crash-dumps

.PHONY: prepare-shoot
prepare-shoot: results clean-crash-dumps

.PHONY: clean-phout
clean-phout:
	rm -f $(PANDORA_RESULTS_DIR)/*_phout.log

.PHONY: clean-crash-dumps
clean-crash-dumps: crash-dumps
	rm -f $(CRASH_DUMP_DIR)/*.hprof $(CRASH_DUMP_DIR)/hs_err_pid*.log $(CRASH_DUMP_DIR)/core $(CRASH_DUMP_DIR)/core.* $(CRASH_DUMP_DIR)/*.core

.PHONY: clean-heap-dumps
clean-heap-dumps: clean-crash-dumps
