package com.natsu.jefag.common.services;

import com.natsu.jefag.common.log.Logger;
import com.natsu.jefag.common.log.LoggerFactory;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public final class ServiceRegistry {

    private static final Logger logger = LoggerFactory.getLogger(ServiceRegistry.class);
    private static final Map<Class<?>, Object> services = new ConcurrentHashMap<>();

    private ServiceRegistry() {
        // prevent instantiation
    }

    public static void clear(){
        services.clear();
    }

    /**
     * Register a service instance for a given type.
     * Logs error if already registered.
     */
    public static <T> void register(Class<T> type, T instance) {
        if (type == null || instance == null) {
            throw new IllegalArgumentException("Type and instance cannot be null.");
        }

        Object existing = services.putIfAbsent(type, instance);
        if (existing != null) {
            logger.error("Service already registered for type: {}", type.getName());
        } else {
            logger.info("Registered service: {}", type.getName());
        }
    }

    @SuppressWarnings("unchecked")
    public static <T> void register(T instance) {
        Class<T> type = (Class<T>) instance.getClass();
        if (type == null || instance == null) {
            throw new IllegalArgumentException("Type and instance cannot be null.");
        }

        Object existing = services.putIfAbsent(type, instance);
        if (existing != null) {
            logger.error("Service already registered for type: {}", type.getName());
        } else {
            logger.info("Registered service: {}", type.getName());
        }
    }

    /**
     * Get a registered service, creating a new instance if not registered.
     */
    @SuppressWarnings("unchecked")
    public static <T> T get(Class<T> type) {
        return (T) services.computeIfAbsent(type, ServiceRegistry::createInstance);
    }

    @SuppressWarnings("unchecked")
    public static <T> Optional<T> getIfExist(Class<T> type) {
        if(services.containsKey(type)){
            return Optional.ofNullable((T)services.get(type));
        }else return Optional.empty();
    }

    /**
     * Check if a service is registered.
     */
    public static boolean isRegistered(Class<?> type) {
        return services.containsKey(type);
    }

    /**
     * Remove a registered service.
     */
    public static void unregister(Class<?> type) {
        services.remove(type);
    }

    /**
     * Create an instance of the given class via reflection (default constructor).
     */
    private static <T> T createInstance(Class<T> type) {
        try {
            return type.getDeclaredConstructor().newInstance();
        } catch (Exception e) {
            throw new IllegalStateException("Could not create instance for: " + type.getName(), e);
        }
    }
}

/** Usage
        ServiceRegistry.register(TaskService.class, new TaskService(4));

        // Get service
        TaskService tasks = ServiceRegistry.get(TaskService.class);
        tasks.runAsync(() -> System.out.println("Hello from async!"));

        // Auto-create service if not registered
        AutoService auto = ServiceRegistry.get(AutoService.class);
        auto.sayHi();
 */
