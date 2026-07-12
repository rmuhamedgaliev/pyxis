package com.workshop.app.observability;

import io.grpc.ForwardingServerCall.SimpleForwardingServerCall;
import io.grpc.Metadata;
import io.grpc.ServerCall;
import io.grpc.ServerCallHandler;
import io.grpc.ServerInterceptor;
import io.grpc.Status;
import net.devh.boot.grpc.server.interceptor.GrpcGlobalServerInterceptor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@GrpcGlobalServerInterceptor
public class GrpcAccessLogInterceptor implements ServerInterceptor {

    private static final Logger ACCESS_LOG = LoggerFactory.getLogger("ACCESS");

    @Override
    public <Q, R> ServerCall.Listener<Q> interceptCall(
            ServerCall<Q, R> call,
            Metadata headers,
            ServerCallHandler<Q, R> next
    ) {
        long startNanos = System.nanoTime();
        String method = call.getMethodDescriptor().getFullMethodName();

        return next.startCall(new SimpleForwardingServerCall<>(call) {
            @Override
            public void close(Status status, Metadata trailers) {
                long durationMs = (System.nanoTime() - startNanos) / 1_000_000;
                ACCESS_LOG.info(
                        "event=access route={} method=GRPC code={} duration_ms={}",
                        method,
                        status.getCode(),
                        durationMs
                );
                super.close(status, trailers);
            }
        }, headers);
    }
}
