# Services Registry Module

A unified configuration registry for all service types (databases, caches, message queues).

## Overview

The Services Registry provides a central location to register and retrieve service configurations, enabling a consistent approach to service management across the application.

## Components

### ServiceConfig Interface

Base interface that all service configurations must implement:

```java
public interface ServiceConfig {
    String getName();
    ServiceType getServiceType();
    void validate();
    Map<String, Object> toMap();
    String getDescription();
}
```

Implemented by:
- `DatabaseConfig` - Database connection configuration
- `CacheConfig` - Cache configuration
- `MessageQueueConfig` - Message queue configuration

### ServiceType Enum

```java
public enum ServiceType {
    DATABASE,
    CACHE,
    MESSAGE_QUEUE,
    CUSTOM
}
```

### ServicesRegistry

Central registry for all service configurations with the following capabilities:

- **Registration**: Register configs with automatic validation
- **Retrieval**: Get configs by name and type
- **Query**: Check existence, count, list names
- **Removal**: Unregister individual or all configs
- **Listeners**: React to registration events

## Usage

### Basic Registration and Retrieval

```java
// Create and register configs
DatabaseConfig dbConfig = DatabaseConfig.mysql("localhost", 3306, "mydb", "user", "pass");
CacheConfig cacheConfig = CacheConfig.builder("session")
    .maxSize(10000)
    .defaultTtl(Duration.ofMinutes(30))
    .build();
MessageQueueConfig mqConfig = MessageQueueConfig.local()
    .name("events")
    .build();

ServicesRegistry.register(dbConfig);
ServicesRegistry.register(cacheConfig);
ServicesRegistry.register(mqConfig);

// Retrieve configs
DatabaseConfig db = ServicesRegistry.get("mysql-db", ServiceType.DATABASE);
CacheConfig cache = ServicesRegistry.get("session", ServiceType.CACHE);
MessageQueueConfig mq = ServicesRegistry.get("events", ServiceType.MESSAGE_QUEUE);
```

### Register Multiple Configs

```java
ServicesRegistry.registerAll(dbConfig, cacheConfig, mqConfig);

// Or from a collection
List<ServiceConfig> configs = loadConfigs();
ServicesRegistry.registerAll(configs);
```

### Conditional Registration

```java
// Register only if not already present
if (ServicesRegistry.registerIfAbsent(config)) {
    System.out.println("Config registered");
}

// Register with overwrite
ServicesRegistry.register(newConfig, true);
```

### Retrieval Options

```java
// Throws NoSuchElementException if not found
DatabaseConfig db = ServicesRegistry.get("mydb", ServiceType.DATABASE);

// Returns null if not found
DatabaseConfig dbOrNull = ServicesRegistry.getOrNull("mydb", ServiceType.DATABASE);

// Returns default if not found
DatabaseConfig dbOrDefault = ServicesRegistry.getOrDefault(
    "mydb", 
    ServiceType.DATABASE, 
    DatabaseConfig.h2InMemory("default")
);

// Get all configs of a type
List<CacheConfig> allCaches = ServicesRegistry.getAll(ServiceType.CACHE);

// Get all config names of a type
Set<String> cacheNames = ServicesRegistry.getNames(ServiceType.CACHE);
```

### Query Operations

```java
// Check existence
boolean exists = ServicesRegistry.contains("mydb", ServiceType.DATABASE);

// Count configs
int dbCount = ServicesRegistry.count(ServiceType.DATABASE);
int total = ServicesRegistry.size();
boolean empty = ServicesRegistry.isEmpty();
```

### Removal

```java
// Remove single config
ServicesRegistry.unregister("mydb", ServiceType.DATABASE);
ServicesRegistry.unregister(config);

// Remove all of a type
int removed = ServicesRegistry.clearType(ServiceType.CACHE);

// Remove everything
ServicesRegistry.clear();
```

### Listeners

```java
// React to registration events
ServicesRegistry.onRegister(ServiceType.DATABASE, config -> {
    DatabaseConfig dbConfig = (DatabaseConfig) config;
    System.out.println("Database registered: " + dbConfig.getName());
    // Initialize database connection, etc.
});

// Remove listeners
ServicesRegistry.removeListeners(ServiceType.DATABASE);
ServicesRegistry.clearListeners();
```

### Integration with Factories

The factories (DatabaseFactory, CacheManager, MessageQueueFactory) can now load from the registry:

```java
// Register configs
ServicesRegistry.register(DatabaseConfig.mysql("localhost", 3306, "mydb", "user", "pass"));
ServicesRegistry.register(CacheConfig.builder("session").maxSize(10000).build());
ServicesRegistry.register(MessageQueueConfig.local().name("events").build());

// Create from registry
SqlDatabase db = DatabaseFactory.createSqlFromRegistry("mysql-db");
Cache<String, Session> cache = CacheManager.getCacheFromRegistry("session");
MessageQueue mq = MessageQueueFactory.getInstance().createFromRegistry("events");

// Or create all registered configs at once
DatabaseFactory.createAllFromRegistry();
CacheManager.createAllFromRegistry();
MessageQueueFactory.getInstance().createAllFromRegistry();
```

### Debugging

```java
// Get a summary of all registered configs
String summary = ServicesRegistry.summary();
System.out.println(summary);
// Output:
// ServicesRegistry {
//   DATABASE: [
//     database:mysql-db
//   ]
//   CACHE: [
//     cache:session
//   ]
//   MESSAGE_QUEUE: [
//     message_queue:events
//   ]
// }
```

## Namespace Isolation

Configs with the same name but different types are isolated:

```java
// All three can coexist
ServicesRegistry.register(DatabaseConfig.builder().type(DatabaseType.H2).name("test").database("mem:test").build());
ServicesRegistry.register(CacheConfig.defaultConfig("test"));
ServicesRegistry.register(MessageQueueConfig.local().name("test").build());

// Retrieve each separately
DatabaseConfig db = ServicesRegistry.get("test", ServiceType.DATABASE);
CacheConfig cache = ServicesRegistry.get("test", ServiceType.CACHE);
MessageQueueConfig mq = ServicesRegistry.get("test", ServiceType.MESSAGE_QUEUE);
```

## Thread Safety

The ServicesRegistry is fully thread-safe and can be used from multiple threads concurrently. All internal data structures use `ConcurrentHashMap`.

## Testing

Reset the registry in tests:

```java
@BeforeEach
void setUp() {
    ServicesRegistry.reset();
}

@AfterEach
void tearDown() {
    ServicesRegistry.reset();
}
```
