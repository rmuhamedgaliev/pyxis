package com.workshop.app.grpc;

import com.workshop.app.grpc.proto.*;
import com.workshop.app.service.StoreService;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import lombok.RequiredArgsConstructor;
import net.devh.boot.grpc.server.service.GrpcService;

@GrpcService
@RequiredArgsConstructor
public class GrpcAuthService extends AuthServiceGrpc.AuthServiceImplBase {

    private final StoreService store;

    @Override
    public void login(LoginRequest req, StreamObserver<LoginResponse> out) {
        try {
            String token  = store.login(req.getLogin(), req.getPassword());
            String userId = store.getUserId(token);
            out.onNext(LoginResponse.newBuilder()
                    .setToken(token)
                    .setUserId(userId)
                    .build());
            out.onCompleted();
        } catch (IllegalArgumentException e) {
            out.onError(Status.INVALID_ARGUMENT.withDescription(e.getMessage()).asRuntimeException());
        }
    }
}
