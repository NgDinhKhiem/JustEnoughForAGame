package com.natsu.jefag.common.cache;

import com.natsu.jefag.common.registry.ServiceType;
import com.natsu.jefag.common.registry.ServicesRegistry;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;

/**
 * Factory for creating and managing cache instances.
 *
 * <p>Supports loading configurations from {@link ServicesRegistry}.
 *
 * <p>Usage:
 * <pre>
 * // Get or create a cache
 * Cache&lt;String, User&gt; userCache = CacheManager.getCache("users");
 *
 * // With custom configuration
 * CacheConfig config = CacheConfig.builder("sessions")
 *     .maxSize(10000)
 *     .defaultTtl(Duration.ofMinutes(30))
 *     .build();
 * Cache&lt;String, Session&gt; sessionCache = CacheManager.getCache(config);
 *
 * // Get existing cache
 * Cache&lt;String, User&gt; sameCache = CacheManager.getCache("users");
 *
 * // From registry
 * ServicesRegistry.register(config);
 * Cache&lt;String, Session&gt; fromRegistry = CacheManager.getCacheFromRegistry("sessions");
 *
 * // Remove a cache
 * CacheManager.removeCache("users");
 *
 * // Clear all caches
 * CacheManager.clearAll();
 * </pre>
 */
public final class CacheManager {

    private static final Map<String, Cache<?, ?>> caches = new ConcurrentHashMap<>();
    private static volatile Function<CacheConfig, Cache<?, ?>> cacheFactory = InMemoryCache::new;

    private CacheManager() {
        // Utility class
    }

    /**
     * Gets or creates a cache with the given name using default configuration.
     *
     * @param name the cache name
     * @param <K> the key type
     * @param <V> the value type
     * @return the cache instance
     */
    @SuppressWarnings("unchecked")
    public static <K, V> Cache<K, V> getCache(String name) {
        return (Cache<K, V>) caches.computeIfAbsent(name, n -> 
            cacheFactory.apply(CacheConfig.defaultConfig(n))
        );
    }

    /**
     * Gets or creates a cache with the given configuration.
     *
     * @param config the cache configuration
     * @param <K> the key type
     * @param <V> the value type
     * @return the cache instance
     */
    @SuppressWarnings("unchecked")
    public static <K, V> Cache<K, V> getCache(CacheConfig config) {
        return (Cache<K, V>) caches.computeIfAbsent(config.getName(), n -> 
            cacheFactory.apply(config)
        );
    }

    /**
     * Gets an existing cache by name.
     *
     * @param name the cache name
     * @param <K> the key type
     * @param <V> the value type
     * @return the cache, or null if not found
     */
    @SuppressWarnings("unchecked")
    public static <K, V> Cache<K, V> getExistingCache(String name) {
        return (Cache<K, V>) caches.get(name);
    }

    /**
     * Checks if a cache exists.
     *
     * @param name the cache name
     * @return true if the cache exists
     */
    public static boolean hasCache(String name) {
        return caches.containsKey(name);
    }

    /**
     * Removes a cache by name.
     *
     * @param name the cache name
     * @return true if the cache was removed
     */
    public static boolean removeCache(String name) {
        Cache<?, ?> cache = caches.remove(name);
        if (cache != null) {
            cache.close();
            return true;
        }
        return false;
    }

    /**
     * Clears all entries from a specific cache.
     *
     * @param name the cache name
     */
    public static void clearCache(String name) {
        Cache<?, ?> cache = caches.get(name);
        if (cache != null) {
            cache.clear();
        }
    }

    /**
     * Clears all entries from all caches.
     */
    public static void clearAll() {
        for (Cache<?, ?> cache : caches.values()) {
            cache.clear();
        }
    }

    /**
     * Closes and removes all caches.
     */
    public static void shutdown() {
        for (Cache<?, ?> cache : caches.values()) {
            try {
                cache.close();
            } catch (Exception e) {
                // Ignore
            }
        }
        caches.clear();
    }

    /**
     * Gets all cache names.
     *
     * @return the set of cache names
     */
    public static java.util.Set<String> getCacheNames() {
        return java.util.Set.copyOf(caches.keySet());
    }

    /**
     * Gets statistics for all caches.
     *
     * @return a map of cache name to statistics
     */
    public static Map<String, CacheStats> getAllStats() {
        Map<String, CacheStats> allStats = new ConcurrentHashMap<>();
        for (Map.Entry<String, Cache<?, ?>> entry : caches.entrySet()) {
            CacheStats stats = entry.getValue().getStats();
            if (stats != null) {
                allStats.put(entry.getKey(), stats);
            }
        }
        return allStats;
    }

    /**
     * Sets a custom cache factory for creating cache instances.
     * This allows using different cache implementations (e.g., Redis).
     *
     * @param factory the cache factory function
     */
    public static void setCacheFactory(Function<CacheConfig, Cache<?, ?>> factory) {
        cacheFactory = factory;
    }

    /**
     * Resets the cache factory to the default (InMemoryCache).
     */
    public static void resetCacheFactory() {
        cacheFactory = InMemoryCache::new;
    }

    /**
     * Registers an existing cache instance.
     *
     * @param cache the cache to register
     * @param <K> the key type
     * @param <V> the value type
     */
    public static <K, V> void registerCache(Cache<K, V> cache) {
        caches.put(cache.getName(), cache);
    }

    // ==================== ServicesRegistry Integration ====================

    /**
     * Gets or creates a cache from a configuration registered in ServicesRegistry.
     *
     * @param name the configuration name in the registry
     * @param <K> the key type
     * @param <V> the value type
     * @return the cache instance
     */
    @SuppressWarnings("unchecked")
    public static <K, V> Cache<K, V> getCacheFromRegistry(String name) {
        Cache<?, ?> existing = caches.get(name);
        if (existing != null) {
            return (Cache<K, V>) existing;
        }
        
        CacheConfig config = ServicesRegistry.get(name, ServiceType.CACHE);
        return getCache(config);
    }

    /**
     * Creates all caches from configurations registered in ServicesRegistry.
     */
    public static void createAllFromRegistry() {
        for (CacheConfig config : ServicesRegistry.<CacheConfig>getAll(ServiceType.CACHE)) {
            getCache(config);
        }
    }
}
