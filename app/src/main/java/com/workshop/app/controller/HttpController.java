package com.workshop.app.controller;

import com.workshop.app.model.Order;
import com.workshop.app.model.Product;
import com.workshop.app.service.StoreService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

@Slf4j
@RestController
@RequiredArgsConstructor
public class HttpController {

    private final StoreService store;

    // ── Auth ──────────────────────────────────────────────────────────────────

    @PostMapping("/api/auth/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> body) {
        try {
            String token = store.login(body.get("login"), body.get("password"));
            String userId = store.getUserId(token);
            return ResponseEntity.ok(Map.of(
                    "token",  token,
                    "userId", userId
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // ── Orders ────────────────────────────────────────────────────────────────

    @PostMapping("/api/v1/orders")
    public ResponseEntity<?> createOrder(
            @RequestHeader("Authorization") String authHeader,
            @RequestBody Map<String, Object> body
    ) {
        try {
            String token  = extractToken(authHeader);
            String userId = store.getUserId(token);
            String productId = (String) body.get("productId");
            int quantity = body.containsKey("quantity")
                    ? ((Number) body.get("quantity")).intValue() : 1;

            Order order = store.createOrder(userId, productId, quantity);
            return ResponseEntity.status(HttpStatus.CREATED).body(orderToMap(order));
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", e.getMessage()));
        } catch (NoSuchElementException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/api/v1/orders/{orderId}")
    public ResponseEntity<?> getOrder(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable String orderId
    ) {
        try {
            store.getUserId(extractToken(authHeader)); // validate token
            Order order = store.getOrder(orderId);
            return ResponseEntity.ok(orderToMap(order));
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", e.getMessage()));
        } catch (NoSuchElementException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/api/v1/orders")
    public ResponseEntity<?> listOrders(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam(defaultValue = "20") int limit
    ) {
        try {
            String userId = store.getUserId(extractToken(authHeader));
            List<Order> orders = store.listOrders(userId, limit);
            return ResponseEntity.ok(Map.of(
                    "orders", orders.stream().map(this::orderToMap).toList(),
                    "total",  orders.size()
            ));
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", e.getMessage()));
        }
    }

    // ── Products ──────────────────────────────────────────────────────────────

    @GetMapping("/api/v1/products")
    public ResponseEntity<?> listProducts(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String category,
            @RequestParam(defaultValue = "10") int limit
    ) {
        List<Product> products = store.searchProducts(search, category, limit);
        return ResponseEntity.ok(Map.of(
                "products", products,
                "total",    products.size()
        ));
    }

    @GetMapping("/api/v1/products/{productId}")
    public ResponseEntity<?> getProduct(@PathVariable String productId) {
        try {
            return ResponseEntity.ok(store.getProduct(productId));
        } catch (NoSuchElementException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", e.getMessage()));
        }
    }

    // ── Health ────────────────────────────────────────────────────────────────

    @GetMapping("/ping")
    public ResponseEntity<?> ping() {
        return ResponseEntity.ok(Map.of("status", "ok"));
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private String extractToken(String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            throw new SecurityException("Missing or invalid Authorization header");
        }
        return authHeader.substring(7);
    }

    private Map<String, Object> orderToMap(Order o) {
        return Map.of(
                "orderId",   o.getId(),
                "userId",    o.getUserId(),
                "productId", o.getProductId(),
                "quantity",  o.getQuantity(),
                "status",    o.getStatus(),
                "total",     o.getTotal()
        );
    }
}
