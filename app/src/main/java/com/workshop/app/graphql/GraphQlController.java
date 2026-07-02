package com.workshop.app.graphql;

import com.workshop.app.model.Order;
import com.workshop.app.model.Product;
import com.workshop.app.service.StoreService;
import lombok.RequiredArgsConstructor;
import org.springframework.graphql.data.method.annotation.Argument;
import org.springframework.graphql.data.method.annotation.MutationMapping;
import org.springframework.graphql.data.method.annotation.QueryMapping;
import org.springframework.stereotype.Controller;

import java.util.List;

@Controller
@RequiredArgsConstructor
public class GraphQlController {

    private final StoreService store;

    // ── Queries ───────────────────────────────────────────────────────────────

    @QueryMapping
    public List<Product> products(
            @Argument String search,
            @Argument String category,
            @Argument Integer limit
    ) {
        return store.searchProducts(search, category, limit != null ? limit : 10);
    }

    @QueryMapping
    public Product product(@Argument String id) {
        return store.getProduct(id);
    }

    @QueryMapping
    public List<Order> orders(@Argument String userId, @Argument Integer limit) {
        return store.listOrders(userId, limit != null ? limit : 20);
    }

    @QueryMapping
    public Order order(@Argument String id) {
        return store.getOrder(id);
    }

    // ── Mutations ─────────────────────────────────────────────────────────────

    @MutationMapping
    public AuthPayload login(@Argument String login, @Argument String password) {
        String token  = store.login(login, password);
        String userId = store.getUserId(token);
        return new AuthPayload(token, userId);
    }

    @MutationMapping
    public Order createOrder(
            @Argument String token,
            @Argument String productId,
            @Argument Integer quantity
    ) {
        String userId = store.getUserId(token);
        return store.createOrder(userId, productId, quantity != null ? quantity : 1);
    }

    // ── Inner types ───────────────────────────────────────────────────────────

    public record AuthPayload(String token, String userId) {}
}
