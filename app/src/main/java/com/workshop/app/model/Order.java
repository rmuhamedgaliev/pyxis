package com.workshop.app.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Order {
    private String id;
    private String userId;
    private String productId;
    private int quantity;
    private String status;
    private double total;
    private Instant createdAt;

    public static Order create(String userId, String productId, int quantity) {
        return Order.builder()
                .id(UUID.randomUUID().toString())
                .userId(userId)
                .productId(productId)
                .quantity(quantity)
                .status("CREATED")
                .total(quantity * 99.99)
                .createdAt(Instant.now())
                .build();
    }
}
