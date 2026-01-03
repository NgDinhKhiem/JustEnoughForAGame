package com.natsu.jefag.common.registry;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Consumer;
import java.util.stream.Collectors;

/**
 * Central registry for all service configurations.
 * 
 * <p>Provides a unified way to register and retrieve configurations for
 * databases, caches, message queues, and other services.
 * 
 * <p>Usage:
 * <pre>
 * // Register configurations
 * ServicesRegistry.register(DatabaseConfig.mysql("mydb", "localhost", 3306, "test"));
 * ServicesRegistry.register(CacheConfig.builder("session").maxSize(10000).build());
 * ServicesRegistry.register(MessageQueueConfig.local("events"));
 * 
 * // Retrieve configurations
 * DatabaseConfig dbConfig = ServicesRegistry.get("mydb", ServiceType.DATABASE);
 * CacheConfig cacheConfig = ServicesRegistry.get("session", ServiceType.CACHE);
 * 
 * // Get all configs of a type
 * List&lt;DatabaseConfig&gt; allDbs = ServicesRegistry.getAll(ServiceType.DATABASE);
 * 
 * // Listen for registration events
 * ServicesRegistry.onRegister(ServiceType.DATABASE, config -&gt; {
 *     System.out.println("Database registered: " + config.getName());
 * });
 * </pre>
 */
public final class ServicesRegistry {

    /**
     * Composite key for the registry: name + type.
     */
    private record ConfigKey(String name, ServiceType type) {}

    private static final Map<ConfigKey, ServiceConfig> registry = new ConcurrentHashMap<>();
    private static final Map<ServiceType, List<Consumer<ServiceConfig>>> listeners = new ConcurrentHashMap<>();

    private ServicesRegistry() {
        // Utility class
    }

    // ==================== Registration ====================

    /**
     * Registers a service configuration.
     *
     * @param config the configuration to register
     * @throws IllegalArgumentException if config is null
     * @throws IllegalStateException if a config with the same name and type already exists
     */
    public static void register(ServiceConfig config) {
        register(config, false);
    }

    /**
     * Registers a service configuration, optionally allowing overwrite.
     *
     * @param config the configuration to register
     * @param allowOverwrite if true, allows overwriting existing config
     * @throws IllegalArgumentException if config is null
     * @throws IllegalStateException if a config exists and allowOverwrite is false
     */
    public static void register(ServiceConfig config, boolean allowOverwrite) {
        Objects.requireNonNull(config, "Config cannot be null");
        config.validate();

        ConfigKey key = new ConfigKey(config.getName(), config.getServiceType());
        
        if (!allowOverwrite && registry.containsKey(key)) {
            throw new IllegalStateException(
                    "Configuration already registered: " + config.getDescription()
            );
        }

        registry.put(key, config);
        notifyListeners(config);
    }

    /**
     * Registers a configuration if not already present.
     *
     * @param config the configuration to register
     * @return true if the config was registered, false if already exists
     */
    public static boolean registerIfAbsent(ServiceConfig config) {
        Objects.requireNonNull(config, "Config cannot be null");
        config.validate();

        ConfigKey key = new ConfigKey(config.getName(), config.getServiceType());
        ServiceConfig existing = registry.putIfAbsent(key, config);
        
        if (existing == null) {
            notifyListeners(config);
            return true;
        }
        return false;
    }

    /**
     * Registers multiple configurations at once.
     *
     * @param configs the configurations to register
     */
    public static void registerAll(ServiceConfig... configs) {
        for (ServiceConfig config : configs) {
            register(config);
        }
    }

    /**
     * Registers multiple configurations at once.
     *
     * @param configs the configurations to register
     */
    public static void registerAll(Collection<? extends ServiceConfig> configs) {
        for (ServiceConfig config : configs) {
            register(config);
        }
    }

    // ==================== Retrieval ====================

    /**
     * Gets a configuration by name and type.
     *
     * @param name the configuration name
     * @param type the service type
     * @param <T> the configuration type
     * @return the configuration
     * @throws NoSuchElementException if not found
     */
    @SuppressWarnings("unchecked")
    public static <T extends ServiceConfig> T get(String name, ServiceType type) {
        ConfigKey key = new ConfigKey(name, type);
        ServiceConfig config = registry.get(key);
        
        if (config == null) {
            throw new NoSuchElementException(
                    "Configuration not found: " + type.name().toLowerCase() + ":" + name
            );
        }
        
        return (T) config;
    }

    /**
     * Gets a configuration by name and type, or null if not found.
     *
     * @param name the configuration name
     * @param type the service type
     * @param <T> the configuration type
     * @return the configuration, or null
     */
    @SuppressWarnings("unchecked")
    public static <T extends ServiceConfig> T getOrNull(String name, ServiceType type) {
        ConfigKey key = new ConfigKey(name, type);
        return (T) registry.get(key);
    }

    /**
     * Gets a configuration by name and type, or a default if not found.
     *
     * @param name the configuration name
     * @param type the service type
     * @param defaultConfig the default configuration
     * @param <T> the configuration type
     * @return the configuration, or the default
     */
    @SuppressWarnings("unchecked")
    public static <T extends ServiceConfig> T getOrDefault(String name, ServiceType type, T defaultConfig) {
        ConfigKey key = new ConfigKey(name, type);
        ServiceConfig config = registry.get(key);
        return config != null ? (T) config : defaultConfig;
    }

    /**
     * Gets all configurations of a specific type.
     *
     * @param type the service type
     * @param <T> the configuration type
     * @return list of configurations
     */
    @SuppressWarnings("unchecked")
    public static <T extends ServiceConfig> List<T> getAll(ServiceType type) {
        return registry.entrySet().stream()
                .filter(e -> e.getKey().type() == type)
                .map(e -> (T) e.getValue())
                .collect(Collectors.toList());
    }

    /**
     * Gets all registered configurations.
     *
     * @return all configurations
     */
    public static Collection<ServiceConfig> getAll() {
        return Collections.unmodifiableCollection(registry.values());
    }

    /**
     * Gets the names of all configurations of a specific type.
     *
     * @param type the service type
     * @return set of configuration names
     */
    public static Set<String> getNames(ServiceType type) {
        return registry.keySet().stream()
                .filter(k -> k.type() == type)
                .map(ConfigKey::name)
                .collect(Collectors.toSet());
    }

    // ==================== Query ====================

    /**
     * Checks if a configuration exists.
     *
     * @param name the configuration name
     * @param type the service type
     * @return true if exists
     */
    public static boolean contains(String name, ServiceType type) {
        return registry.containsKey(new ConfigKey(name, type));
    }

    /**
     * Gets the count of configurations of a specific type.
     *
     * @param type the service type
     * @return the count
     */
    public static int count(ServiceType type) {
        return (int) registry.keySet().stream()
                .filter(k -> k.type() == type)
                .count();
    }

    /**
     * Gets the total count of all configurations.
     *
     * @return the total count
     */
    public static int size() {
        return registry.size();
    }

    /**
     * Checks if the registry is empty.
     *
     * @return true if empty
     */
    public static boolean isEmpty() {
        return registry.isEmpty();
    }

    // ==================== Removal ====================

    /**
     * Unregisters a configuration.
     *
     * @param name the configuration name
     * @param type the service type
     * @return true if the configuration was removed
     */
    public static boolean unregister(String name, ServiceType type) {
        return registry.remove(new ConfigKey(name, type)) != null;
    }

    /**
     * Unregisters a configuration.
     *
     * @param config the configuration to unregister
     * @return true if the configuration was removed
     */
    public static boolean unregister(ServiceConfig config) {
        return unregister(config.getName(), config.getServiceType());
    }

    /**
     * Clears all configurations of a specific type.
     *
     * @param type the service type
     * @return the number of configurations removed
     */
    public static int clearType(ServiceType type) {
        List<ConfigKey> toRemove = registry.keySet().stream()
                .filter(k -> k.type() == type)
                .toList();
        toRemove.forEach(registry::remove);
        return toRemove.size();
    }

    /**
     * Clears all configurations.
     */
    public static void clear() {
        registry.clear();
    }

    // ==================== Listeners ====================

    /**
     * Registers a listener for configuration registration events.
     *
     * @param type the service type to listen for
     * @param listener the listener callback
     */
    public static void onRegister(ServiceType type, Consumer<ServiceConfig> listener) {
        listeners.computeIfAbsent(type, k -> new ArrayList<>()).add(listener);
    }

    /**
     * Removes all listeners for a service type.
     *
     * @param type the service type
     */
    public static void removeListeners(ServiceType type) {
        listeners.remove(type);
    }

    /**
     * Removes all listeners.
     */
    public static void clearListeners() {
        listeners.clear();
    }

    private static void notifyListeners(ServiceConfig config) {
        List<Consumer<ServiceConfig>> typeListeners = listeners.get(config.getServiceType());
        if (typeListeners != null) {
            for (Consumer<ServiceConfig> listener : typeListeners) {
                try {
                    listener.accept(config);
                } catch (Exception e) {
                    // Log but don't propagate listener exceptions
                    System.err.println("Listener error for " + config.getDescription() + ": " + e.getMessage());
                }
            }
        }
    }

    // ==================== Debugging ====================

    /**
     * Gets a summary of all registered configurations.
     *
     * @return a summary string
     */
    public static String summary() {
        StringBuilder sb = new StringBuilder("ServicesRegistry {\n");
        
        for (ServiceType type : ServiceType.values()) {
            List<ServiceConfig> configs = getAll(type);
            if (!configs.isEmpty()) {
                sb.append("  ").append(type.name()).append(": [\n");
                for (ServiceConfig config : configs) {
                    sb.append("    ").append(config.getDescription()).append("\n");
                }
                sb.append("  ]\n");
            }
        }
        
        sb.append("}");
        return sb.toString();
    }

    /**
     * Resets the registry (for testing).
     */
    public static void reset() {
        clear();
        clearListeners();
    }
}
