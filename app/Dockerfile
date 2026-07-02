FROM eclipse-temurin:25-jdk AS build
WORKDIR /build
# Cache dependencies layer
COPY gradlew build.gradle.kts settings.gradle.kts ./
COPY gradle ./gradle
RUN chmod +x ./gradlew && ./gradlew help --no-daemon -q
COPY src ./src
RUN ./gradlew bootJar --no-daemon -q

FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /build/build/libs/pandora-target-app-1.0.0.jar app.jar
WORKDIR /app/crash-dumps

EXPOSE 8080 9090

ENTRYPOINT ["java", \
  "-Xms512m", "-Xmx512m", \
  "-XX:+UseG1GC", \
  "-XX:+HeapDumpOnOutOfMemoryError", \
  "-XX:+CrashOnOutOfMemoryError", \
  "-XX:+CreateCoredumpOnCrash", \
  "-XX:HeapDumpPath=/app/crash-dumps", \
  "-XX:ErrorFile=/app/crash-dumps/hs_err_pid%p.log", \
  "-Xlog:gc*:file=/tmp/gc.log", \
  "-jar", "/app/app.jar"]
