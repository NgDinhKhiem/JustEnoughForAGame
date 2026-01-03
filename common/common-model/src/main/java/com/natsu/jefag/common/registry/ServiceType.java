package com.natsu.jefag.common.registry;

/**
 * Types of services that can be registered in the ServicesRegistry.
 */
public enum ServiceType {
    
    /**
     * Database services (SQL and NoSQL).
     */
    DATABASE,
    
    /**
     * Cache services (in-memory, distributed).
     */
    CACHE,
    
    /**
     * Message queue services (local, socket, Redis, RabbitMQ).
     */
    MESSAGE_QUEUE,
    
    /**
     * Generic/custom service type.
     */
    CUSTOM
}
