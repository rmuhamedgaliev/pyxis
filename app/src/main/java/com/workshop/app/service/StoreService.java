package com.workshop.app.service;

import com.workshop.app.model.Order;
import com.workshop.app.model.Product;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * Simple in-memory store.
 * Simulates realistic delays to make load test results interesting.
 */
@Service
public class StoreService {

    // Simulated latency ranges (ms): normal op vs "heavy" op
    private static final int FAST_MIN = 5;
    private static final int FAST_MAX = 20;
    private static final int SLOW_MIN = 50;
    private static final int SLOW_MAX = 200;

    private final Map<String, Order>   orders   = new ConcurrentHashMap<>();
    private final Map<String, Product> products = new ConcurrentHashMap<>();
    private final Map<String, String>  tokens   = new ConcurrentHashMap<>(); // token → userId
    private final Random               rnd      = new Random();

    // ── Seed data ─────────────────────────────────────────────────────────────

    @PostConstruct
    public void seed() {
        List<String> categories = List.of("electronics", "clothing", "food", "books");
        List<String> names = List.of(
                "Laptop Pro", "Wireless Headphones", "Running Shoes",
                "Coffee Beans", "Java Programming", "Smart Watch",
                "Backpack", "Water Bottle", "Keyboard", "Monitor"
        );
        for (int i = 1; i <= 100; i++) {
            String id = "prod-" + i;
            products.put(id, Product.builder()
                    .id(id)
                    .name(names.get(rnd.nextInt(names.size())) + " " + i)
                    .category(categories.get(rnd.nextInt(categories.size())))
                    .price(Math.round(rnd.nextDouble() * 900 + 10) / 1.0)
                    .stock(rnd.nextInt(500))
                    .build());
        }
    }

    // ── Auth ──────────────────────────────────────────────────────────────────

    public String login(String login, String password) {
        simulateDelay(FAST_MIN, FAST_MAX);
        // Accept any non-empty credentials for workshop simplicity
        if (login == null || login.isBlank()) {
            throw new IllegalArgumentException("Login is required");
        }
        String token = UUID.randomUUID().toString();
        // Use login as userId
        tokens.put(token, login);
        return token;
    }

    public String getUserId(String token) {
        String userId = tokens.get(token);
        if (userId == null) throw new SecurityException("Invalid token: " + token);
        return userId;
    }

    // ── Orders ────────────────────────────────────────────────────────────────

    public Order createOrder(String userId, String productId, int quantity) {
        simulateDelay(FAST_MIN, FAST_MAX);
        Product product = products.get(productId);
        if (product == null) throw new NoSuchElementException("Product not found: " + productId);

        Order order = Order.builder()
                .id(UUID.randomUUID().toString())
                .userId(userId)
                .productId(productId)
                .quantity(quantity)
                .status("CREATED")
                .total(product.getPrice() * quantity)
                .createdAt(java.time.Instant.now())
                .build();
        orders.put(order.getId(), order);
        return order;
    }

    public Order getOrder(String orderId) {
        simulateDelay(FAST_MIN, FAST_MAX);
        Order order = orders.get(orderId);
        if (order == null) throw new NoSuchElementException("Order not found: " + orderId);
        return order;
    }

    public List<Order> listOrders(String userId, int limit) {
        // Heavier operation — simulates a DB query with index
        simulateDelay(SLOW_MIN, SLOW_MAX);
        return orders.values().stream()
                .filter(o -> o.getUserId().equals(userId))
                .limit(limit > 0 ? limit : 20)
                .collect(Collectors.toList());
    }

    // ── Products ──────────────────────────────────────────────────────────────

    public List<Product> searchProducts(String term, String category, int limit) {
        // Heaviest operation — simulates full-text search
        simulateDelay(SLOW_MIN, SLOW_MAX * 2);
        return products.values().stream()
                .filter(p -> term == null || p.getName().toLowerCase().contains(term.toLowerCase()))
                .filter(p -> category == null || p.getCategory().equalsIgnoreCase(category))
                .limit(limit > 0 ? limit : 10)
                .collect(Collectors.toList());
    }

    public Product getProduct(String productId) {
        simulateDelay(FAST_MIN, FAST_MAX);
        Product p = products.get(productId);
        if (p == null) throw new NoSuchElementException("Product not found: " + productId);
        return p;
    }

    public List<Product> getAllProducts(int limit) {
        simulateDelay(FAST_MIN, FAST_MAX * 2);
        return products.values().stream()
                .limit(limit > 0 ? limit : 20)
                .collect(Collectors.toList());
    }

    // ── Utils ─────────────────────────────────────────────────────────────────

    private void simulateDelay(int minMs, int maxMs) {
        try {
            Thread.sleep(minMs + rnd.nextInt(maxMs - minMs));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
