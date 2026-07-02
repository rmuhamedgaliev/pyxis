import com.google.protobuf.gradle.id

plugins {
    java
    id("org.springframework.boot")          version "3.5.8"
    id("io.spring.dependency-management")   version "1.1.7"
    id("com.google.protobuf")               version "0.9.4"
}

group   = "com.workshop"
version = "1.0.0"

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

springBoot {
    mainClass = "com.workshop.app.PandoraTargetApp"
}

val grpcVersion      = "1.63.0"
val protobufVersion  = "3.25.3"
val lombokVersion    = "1.18.42"

dependencies {
    // HTTP REST
    implementation("org.springframework.boot:spring-boot-starter-web")

    // GraphQL
    implementation("org.springframework.boot:spring-boot-starter-graphql")

    // gRPC
    implementation("net.devh:grpc-server-spring-boot-starter:3.1.0.RELEASE")
    implementation("io.grpc:grpc-stub:$grpcVersion")
    implementation("io.grpc:grpc-protobuf:$grpcVersion")
    implementation("com.google.protobuf:protobuf-java:$protobufVersion")
    compileOnly("javax.annotation:javax.annotation-api:1.3.2")

    // Metrics
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("io.micrometer:micrometer-registry-prometheus")

    // Utils
    implementation("com.fasterxml.jackson.core:jackson-databind")
    compileOnly("org.projectlombok:lombok:$lombokVersion")
    annotationProcessor("org.projectlombok:lombok:$lombokVersion")

    // Test
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testCompileOnly("org.projectlombok:lombok:$lombokVersion")
    testAnnotationProcessor("org.projectlombok:lombok:$lombokVersion")
}

protobuf {
    protoc {
        artifact = "com.google.protobuf:protoc:$protobufVersion"
    }
    plugins {
        id("grpc") {
            artifact = "io.grpc:protoc-gen-grpc-java:$grpcVersion"
        }
    }
    generateProtoTasks {
        all().forEach {
            it.plugins {
                id("grpc")
            }
        }
    }
}

// Gradle protobuf plugin generates into build/generated/source/proto —
// make sure the compiler sees those sources
sourceSets {
    main {
        java {
            srcDirs(
                "build/generated/source/proto/main/java",
                "build/generated/source/proto/main/grpc",
            )
        }
    }
}

tasks.withType<Test> {
    useJUnitPlatform()
}
