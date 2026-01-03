package com.natsu.jefag.common.cache;

import java.time.Duration;
import java.util.*;
import java.util.function.Supplier;

/**
 * Abstract base class for cache implementations.
 * Provides common functionality and default implementations.
 *
 * @param <K> the key type
 * @param <V> the value type
 */
public abstract class AbstractCache<K, V> implements Cache<K, V> {

    protected final String name;
    protected final CacheConfig config;
    protected final CacheStats stats;

    protected AbstractCache(CacheConfig config) {
        this.name = config.getName();
        this.config = config;
        this.stats = config.isRecordStats() ? new CacheStats() : null;
    }

    protected AbstractCache(String name) {
        this(CacheConfig.defaultConfig(name));
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public V getOrDefault(K key, V defaultValue) {
        return get(key).orElse(defaultValue);
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
    public boolean putIfAbsent(K key, V value) {
        return putIfAbsent(key, value, config.getDefaultTtl());
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
    public CacheStats getStats() {
        return stats;
    }

    protected void recordHit() {
        if (stats != null) {
            stats.recordHit();
        }
    }

    protected void recordMiss() {
        if (stats != null) {
            stats.recordMiss();
        }
    }

    protected void recordPut() {
        if (stats != null) {
            stats.recordPut();
        }
    }

    protected void recordEviction() {
        if (stats != null) {
            stats.recordEviction();
        }
    }

    protected void recordExpiration() {
        if (stats != null) {
            stats.recordExpiration();
        }
    }

    protected CacheConfig getConfig() {
        return config;
    }
}
