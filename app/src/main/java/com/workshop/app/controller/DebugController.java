package com.workshop.app.controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
public class DebugController {

    private static final int BYTES_IN_MB = 1024 * 1024;
    private static final int MAX_MB_PER_REQUEST = 128;
    private static final int MAX_BLOCK_MS = 30_000;
    private static final List<byte[]> RETAINED_HEAP = new ArrayList<>();

    @GetMapping("/debug/threads/block")
    public ResponseEntity<?> blockThread(@RequestParam(defaultValue = "5000") int ms) throws InterruptedException {
        int boundedMs = Math.max(1, Math.min(ms, MAX_BLOCK_MS));
        log.warn("debug_thread_block start ms={}", boundedMs);
        Thread.sleep(boundedMs);
        log.warn("debug_thread_block finish ms={}", boundedMs);
        return ResponseEntity.ok(Map.of(
                "blockedMs", boundedMs,
                "thread", Thread.currentThread().getName()
        ));
    }

    @GetMapping("/debug/oom/allocate")
    public ResponseEntity<?> allocateHeap(@RequestParam(defaultValue = "32") int mb) {
        int boundedMb = Math.max(1, Math.min(mb, MAX_MB_PER_REQUEST));
        byte[] block = new byte[boundedMb * BYTES_IN_MB];

        synchronized (RETAINED_HEAP) {
            RETAINED_HEAP.add(block);
            long retainedMb = RETAINED_HEAP.stream()
                    .mapToLong(bytes -> bytes.length / BYTES_IN_MB)
                    .sum();
            log.warn("debug_oom_allocate mb={} retained_blocks={} retained_mb={}",
                    boundedMb, RETAINED_HEAP.size(), retainedMb);
            return ResponseEntity.ok(Map.of(
                    "allocatedMb", boundedMb,
                    "retainedBlocks", RETAINED_HEAP.size(),
                    "retainedMb", retainedMb
            ));
        }
    }

    @DeleteMapping("/debug/oom/reset")
    public ResponseEntity<?> resetHeap() {
        int removedBlocks;
        synchronized (RETAINED_HEAP) {
            removedBlocks = RETAINED_HEAP.size();
            RETAINED_HEAP.clear();
        }
        System.gc();
        log.warn("debug_oom_reset removed_blocks={}", removedBlocks);
        return ResponseEntity.ok(Map.of("removedBlocks", removedBlocks));
    }
}
