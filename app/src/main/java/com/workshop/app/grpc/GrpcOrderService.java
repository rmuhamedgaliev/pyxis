package com.workshop.app.grpc;

import com.workshop.app.grpc.proto.*;
import com.workshop.app.model.Order;
import com.workshop.app.service.StoreService;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.devh.boot.grpc.server.service.GrpcService;

import java.util.NoSuchElementException;

@Slf4j
@GrpcService
@RequiredArgsConstructor
public class GrpcOrderService extends OrderServiceGrpc.OrderServiceImplBase {

    private final StoreService store;

    @Override
    public void createOrder(CreateOrderRequest req, StreamObserver<CreateOrderResponse> out) {
        try {
            Order order = store.createOrder(req.getUserId(), req.getProductId(), req.getQuantity());
            out.onNext(CreateOrderResponse.newBuilder()
                    .setOrderId(order.getId())
                    .setStatus(order.getStatus())
                    .setTotal(order.getTotal())
                    .build());
            out.onCompleted();
        } catch (NoSuchElementException e) {
            out.onError(Status.NOT_FOUND.withDescription(e.getMessage()).asRuntimeException());
        } catch (Exception e) {
            log.error("createOrder error", e);
            out.onError(Status.INTERNAL.withDescription(e.getMessage()).asRuntimeException());
        }
    }

    @Override
    public void getOrder(GetOrderRequest req, StreamObserver<OrderResponse> out) {
        try {
            Order order = store.getOrder(req.getOrderId());
            out.onNext(toProto(order));
            out.onCompleted();
        } catch (NoSuchElementException e) {
            out.onError(Status.NOT_FOUND.withDescription(e.getMessage()).asRuntimeException());
        }
    }

    @Override
    public void listOrders(ListOrdersRequest req, StreamObserver<ListOrdersResponse> out) {
        try {
            var orders = store.listOrders(req.getUserId(), req.getLimit());
            ListOrdersResponse.Builder resp = ListOrdersResponse.newBuilder()
                    .setTotalCount(orders.size());
            orders.forEach(o -> resp.addOrders(toProto(o)));
            out.onNext(resp.build());
            out.onCompleted();
        } catch (Exception e) {
            log.error("listOrders error", e);
            out.onError(Status.INTERNAL.withDescription(e.getMessage()).asRuntimeException());
        }
    }

    private OrderResponse toProto(Order o) {
        return OrderResponse.newBuilder()
                .setOrderId(o.getId())
                .setUserId(o.getUserId())
                .setProductId(o.getProductId())
                .setQuantity(o.getQuantity())
                .setStatus(o.getStatus())
                .setTotal(o.getTotal())
                .build();
    }
}
