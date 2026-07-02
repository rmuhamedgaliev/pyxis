#!/usr/bin/env bash
# build-and-run.sh — сборка и запуск без Docker
# Требования: JDK 25 (используется встроенный Gradle Wrapper)

set -e

echo "=== Pandora Workshop — Build & Run ==="

if ! command -v java &>/dev/null; then
  echo "❌ Java не найдена. Установите JDK 25: https://adoptium.net"
  exit 1
fi

JAVA_VER=$(java -version 2>&1 | head -1 | grep -o '[0-9]*' | head -1)
echo "✅ Java $JAVA_VER"

cd "$(dirname "$0")/app"

if [ -f "./gradlew" ]; then
  chmod +x ./gradlew
  GRADLE="./gradlew"
  echo "✅ Gradle Wrapper"
else
  echo "❌ Gradle Wrapper не найден."
  exit 1
fi

echo ""
echo "=== Сборка приложения ==="
$GRADLE bootJar --no-daemon -q
echo "✅ Сборка завершена: build/libs/pandora-target-app-1.0.0.jar"

echo ""
echo "=== Запуск ==="
echo "  HTTP:     http://localhost:8080"
echo "  gRPC:     localhost:9090"
echo "  GraphQL:  http://localhost:8080/graphiql"
echo "  Metrics:  http://localhost:8080/actuator/prometheus"
echo ""
echo "  Остановка: Ctrl+C"
echo ""

java \
  -Xms512m -Xmx512m \
  -XX:+UseG1GC \
  -Xlog:gc*:file=/tmp/gc-workshop.log:time,uptime:filecount=3,filesize=10m \
  -jar build/libs/pandora-target-app-1.0.0.jar
