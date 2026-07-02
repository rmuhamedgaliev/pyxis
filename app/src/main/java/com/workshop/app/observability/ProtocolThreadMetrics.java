package com.workshop.app.observability;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Configuration;

import java.util.Locale;
import java.util.Set;

@Configuration
public class ProtocolThreadMetrics {

    public ProtocolThreadMetrics(MeterRegistry registry) {
        registerProtocolThreadGauge(registry, "http", "live");
        registerProtocolThreadGauge(registry, "http", "runnable");
        registerProtocolThreadGauge(registry, "http", "waiting");
        registerProtocolThreadGauge(registry, "http", "blocked");

        registerProtocolThreadGauge(registry, "grpc", "live");
        registerProtocolThreadGauge(registry, "grpc", "runnable");
        registerProtocolThreadGauge(registry, "grpc", "waiting");
        registerProtocolThreadGauge(registry, "grpc", "blocked");
    }

    private void registerProtocolThreadGauge(MeterRegistry registry, String protocol, String state) {
        Gauge.builder("app.protocol.threads", () -> countThreads(protocol, state))
                .description("Application protocol threads grouped by protocol and state")
                .tag("protocol", protocol)
                .tag("state", state)
                .register(registry);
    }

    private long countThreads(String protocol, String state) {
        Set<Thread> threads = Thread.getAllStackTraces().keySet();
        return threads.stream()
                .filter(thread -> belongsToProtocol(thread, protocol))
                .filter(thread -> matchesState(thread, state))
                .count();
    }

    private boolean belongsToProtocol(Thread thread, String protocol) {
        String name = thread.getName().toLowerCase(Locale.ROOT);
        if ("http".equals(protocol)) {
            return name.contains("http-nio") || name.contains("tomcat");
        }
        if ("grpc".equals(protocol)) {
            return name.contains("grpc");
        }
        return false;
    }

    private boolean matchesState(Thread thread, String state) {
        if ("live".equals(state)) {
            return true;
        }
        Thread.State threadState = thread.getState();
        if ("runnable".equals(state)) {
            return threadState == Thread.State.RUNNABLE;
        }
        if ("blocked".equals(state)) {
            return threadState == Thread.State.BLOCKED;
        }
        if ("waiting".equals(state)) {
            return threadState == Thread.State.WAITING || threadState == Thread.State.TIMED_WAITING;
        }
        return false;
    }
}
