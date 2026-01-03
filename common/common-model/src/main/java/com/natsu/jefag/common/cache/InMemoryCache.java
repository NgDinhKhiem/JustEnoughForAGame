package com.natsu.jefag.common.cache;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import java.util.function.Supplier;

/**
 * In-memory cache implementation with LRU eviction, TTL support, and statistics.
 *
 * <p>Usage:
 * <pre>
 * CacheConfig config = CacheConfig.builder("users")
 *     .maxSize(1000)
 *     .defaultTtl(Duration.ofMinutes(10))
 *     .evictionPolicy(EvictionPolicy.LRU)
 *     .build();
 *
 * Cache&lt;String, User&gt; cache = new InMemoryCache&lt;&gt;(config);
 * cache.put("user:123", user);
 * Optional&lt;User&gt; user = cache.get("user:123");
 * </pre>
 *
 * @param <K> the key type
 * @param <V> the value type
 */
public class InMemoryCache<K, V> implements Cache<K, V> {

    private final String name;
    private final CacheConfig config;
    private final Map<K, CacheEntry<V>> storage;
    private final LinkedHashMap<K, Long> accessOrder;
    private final ReentrantReadWriteLock lock = new ReentrantReadWriteLock();
    private final CacheStats stats;
    private final ScheduledExecutorService cleanupExecutor;

    /**
     * Creates a cache with the given configuration.
     *
     * @param config the cache configuration
     */
    public InMemoryCache(CacheConfig config) {
        this.name = config.getName();
        this.config = config;
        this.storage = new ConcurrentHashMap<>();
        this.accessOrder = new LinkedHashMap<>(16, 0.75f, true);
        this.stats = config.isRecordStats() ? new CacheStats() : null;

        // Start cleanup scheduler
        this.cleanupExecutor = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "cache-cleanup-" + name);
            t.setDaemon(true);
            return t;
        });

        // Schedule periodic cleanup every minute
        cleanupExecutor.scheduleAtFixedRate(this::evictExpired, 1, 1, TimeUnit.MINUTES);
    }

    /**
     * Creates a cache with default configuration.
     *
     * @param name the cache name
     */
    public InMemoryCache(String name) {
        this(CacheConfig.defaultConfig(name));
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public Optional<V> get(K key) {
        if (key == null) {
            return Optional.empty();
        }

        CacheEntry<V> entry = storage.get(key);
        if (entry == null) {
            recordMiss();
            return Optional.empty();
        }

        if (entry.isExpired()) {
            remove(key);
            if (stats != null) {
                stats.recordExpiration();
            }
            recordMiss();
            return Optional.empty();
        }

        // Check idle time
        if (config.getMaxIdleTime() != null && entry.getIdleTime().compareTo(config.getMaxIdleTime()) > 0) {
            remove(key);
            recordMiss();
            return Optional.empty();
        }

        entry.recordAccess();
        updateAccessOrder(key);
        recordHit();

        return Optional.of(entry.getValue());
    }

    @Override
    public V getOrCompute(K key, Supplier<V> loader) {
        return getOrCompute(key, loader, config.getDefaultTtl());
    }

    @Override
    public V getOrCompute(K key, Supplier<V> loader, Duration ttl) {
        Optional<V> cached = get(key);
        if (cached.isPresent()) {
            return cached.get();
        }

        V value = loader.get();
        if (value != null) {
            put(key, value, ttl);
        }
        return value;
    }

    @Override
    public void put(K key, V value) {
        put(key, value, config.getDefaultTtl());
    }

    @Override
    public void put(K key, V value, Duration ttl) {
        if (key == null) {
            return;
        }

        lock.writeLock().lock();
        try {
            // Evict if at capacity
            while (storage.size() >= config.getMaxSize()) {
                evictOne();
            }

            CacheEntry<V> entry = CacheEntry.of(value, ttl);
            storage.put(key, entry);
            accessOrder.put(key, System.nanoTime());
            recordPut();
        } finally {
            lock.writeLock().unlock();
        }
    }

    @Override
    public boolean putIfAbsent(K key, V value) {
        return putIfAbsent(key, value, config.getDefaultTtl());
    }

    @Override
    public boolean putIfAbsent(K key, V value, Duration ttl) {
        if (key == null) {
            return false;
        }

        lock.writeLock().lock();
        try {
            if (exists(key)) {
                return false;
            }
            put(key, value, ttl);
            return true;
        } finally {
            lock.writeLock().unlock();
        }
    }

    @Override
    public boolean remove(K key) {
        if (key == null) {
            return false;
        }

        lock.writeLock().lock();
        try {
            CacheEntry<V> removed = storage.remove(key);
            accessOrder.remove(key);
            return removed != null;
        } finally {
            lock.writeLock().unlock();
        }
    }

    @Override
    public boolean exists(K key) {
        if (key == null) {
            return false;
        }

        CacheEntry<V> entry = storage.get(key);
        if (entry == null) {
            return false;
        }

        if (entry.isExpired()) {
            remove(key);
            return false;
        }

        return true;
    }

    @Override
    public Map<K, V> getAll(Set<K> keys) {
        Map<K, V> result = new HashMap<>();
        for (K key : keys) {
            get(key).ifPresent(v -> result.put(key, v));
        }
        return result;
    }

    @Override
    public void putAll(Map<K, V> entries) {
        putAll(entries, config.getDefaultTtl());
    }

    @Override
    public void putAll(Map<K, V> entries, Duration ttl) {
        for (Map.Entry<K, V> entry : entries.entrySet()) {
            put(entry.getKey(), entry.getValue(), ttl);
        }
    }

    @Override
    public int removeAll(Set<K> keys) {
        int count = 0;
        for (K key : keys) {
            if (remove(key)) {
                count++;
            }
        }
        return count;
    }

    @Override
    public void clear() {
        lock.writeLock().lock();
        try {
            storage.clear();
            accessOrder.clear();
        } finally {
            lock.writeLock().unlock();
        }
    }

    @Override
    public long size() {
        return storage.size();
    }

    @Override
    public CacheStats getStats() {
        return stats;
    }

    @Override
    public void evictExpired() {
        lock.writeLock().lock();
        try {
            Iterator<Map.Entry<K, CacheEntry<V>>> it = storage.entrySet().iterator();
            int evicted = 0;
            while (it.hasNext()) {
                Map.Entry<K, CacheEntry<V>> entry = it.next();
                if (entry.getValue().isExpired()) {
                    it.remove();
                    accessOrder.remove(entry.getKey());
                    evicted++;
                }
            }
            if (stats != null && evicted > 0) {
                stats.recordExpirations(evicted);
            }
        } finally {
            lock.writeLock().unlock();
        }
    }

    @Override
    public void close() {
        cleanupExecutor.shutdown();
        try {
            cleanupExecutor.awaitTermination(5, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        clear();
    }

    private void evictOne() {
        switch (config.getEvictionPolicy()) {
            case LRU -> evictLru();
            case FIFO -> evictFifo();
            case LFU -> evictLfu();
            default -> evictLru();
        }
    }

    private void evictLru() {
        if (accessOrder.isEmpty()) {
            return;
        }

        // Get the least recently used key
        K lruKey = accessOrder.keySet().iterator().next();
        storage.remove(lruKey);
        accessOrder.remove(lruKey);

        if (stats != null) {
            stats.recordEviction();
        }
    }

    private void evictFifo() {
        if (storage.isEmpty()) {
            return;
        }

        // Find oldest entry by creation time
        K oldestKey = null;
        Instant oldestTime = Instant.MAX;

        for (Map.Entry<K, CacheEntry<V>> entry : storage.entrySet()) {
            if (entry.getValue().getCreatedAt().isBefore(oldestTime)) {
                oldestTime = entry.getValue().getCreatedAt();
                oldestKey = entry.getKey();
            }
        }

        if (oldestKey != null) {
            storage.remove(oldestKey);
            accessOrder.remove(oldestKey);

            if (stats != null) {
                stats.recordEviction();
            }
        }
    }

    private void evictLfu() {
        if (storage.isEmpty()) {
            return;
        }

        // Find least frequently used entry
        K lfuKey = null;
        long minAccess = Long.MAX_VALUE;

        for (Map.Entry<K, CacheEntry<V>> entry : storage.entrySet()) {
            if (entry.getValue().getAccessCount() < minAccess) {
                minAccess = entry.getValue().getAccessCount();
                lfuKey = entry.getKey();
            }
        }

        if (lfuKey != null) {
            storage.remove(lfuKey);
            accessOrder.remove(lfuKey);

            if (stats != null) {
                stats.recordEviction();
            }
        }
    }

    private void updateAccessOrder(K key) {
        lock.writeLock().lock();
        try {
            accessOrder.put(key, System.nanoTime());
        } finally {
            lock.writeLock().unlock();
        }
    }

    private void recordHit() {
        if (stats != null) {
            stats.recordHit();
        }
    }

    private void recordMiss() {
        if (stats != null) {
            stats.recordMiss();
        }
    }

    private void recordPut() {
        if (stats != null) {
            stats.recordPut();
        }
    }
}
