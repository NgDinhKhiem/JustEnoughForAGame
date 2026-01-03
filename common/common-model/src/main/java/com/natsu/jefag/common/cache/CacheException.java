package com.natsu.jefag.common.cache;

/**
 * Exception thrown for cache-related errors.
 */
public class CacheException extends RuntimeException {

    private final String cacheName;
    private final Object key;

    public CacheException(String message) {
        super(message);
        this.cacheName = null;
        this.key = null;
    }

    public CacheException(String message, Throwable cause) {
        super(message, cause);
        this.cacheName = null;
        this.key = null;
    }

    public CacheException(String cacheName, String message) {
        super("[" + cacheName + "] " + message);
        this.cacheName = cacheName;
        this.key = null;
    }

    public CacheException(String cacheName, String message, Throwable cause) {
        super("[" + cacheName + "] " + message, cause);
        this.cacheName = cacheName;
        this.key = null;
    }

    public CacheException(String cacheName, Object key, String message) {
        super("[" + cacheName + "] key=" + key + ": " + message);
        this.cacheName = cacheName;
        this.key = key;
    }

    public CacheException(String cacheName, Object key, String message, Throwable cause) {
        super("[" + cacheName + "] key=" + key + ": " + message, cause);
        this.cacheName = cacheName;
        this.key = key;
    }

    /**
     * Gets the cache name where the error occurred.
     *
     * @return the cache name, or null if not applicable
     */
    public String getCacheName() {
        return cacheName;
    }

    /**
     * Gets the key involved in the error.
     *
     * @return the key, or null if not applicable
     */
    public Object getKey() {
        return key;
    }
}
