# Common Utils

A collection of common utilities for the JustEnoughForAGame project, providing configuration management, logging, and service registry functionality.

## Table of Contents

- [Installation](#installation)
- [Configuration System](#configuration-system)
- [Logging System](#logging-system)
- [Service Registry](#service-registry)

---

## Installation

Add the dependency to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation(project(":common:common-utils"))
}
```

---

## Configuration System

A flexible, multi-format configuration system supporting YAML, JSON, and TOML formats with caching and file watching.

### Quick Start

```java
import com.natsu.jefag.common.config.Configuration;
import com.natsu.jefag.common.config.ConfigSection;

// Load from file
ConfigSection config = Configuration.fromFile("config/application.yml").load();

// Access values
String name = config.getString("app.name");
int port = config.getInt("server.port", 8080);
boolean debug = config.getBoolean("debug", false);
```

### Supported Formats

| Format | Extensions | Library |
|--------|-----------|---------|
| YAML | `.yml`, `.yaml` | SnakeYAML |
| JSON | `.json` | Jackson |
| TOML | `.toml` | toml4j |

### Loading Configuration

```java
// From file path
ConfigSection config = Configuration.fromFile("config.yml").load();

// From classpath resource
ConfigSection config = Configuration.fromClasspath("/application.yml").load();

// From input stream
ConfigSection config = Configuration.fromStream(inputStream, ConfigFormat.YAML).load();

// From string content
ConfigSection config = Configuration.fromString(yamlContent, ConfigFormat.YAML).load();
```

### Accessing Values

```java
// Basic types
String str = config.getString("key");
int num = config.getInt("key", 0);
long lng = config.getLong("key");
double dbl = config.getDouble("key", 0.0);
boolean bool = config.getBoolean("key", false);

// With defaults
String value = config.getString("key", "default");

// Nested paths (dot notation)
String dbHost = config.getString("database.connection.host");

// Lists
List<String> items = config.getStringList("items");
List<Integer> numbers = config.getIntList("numbers");

// Nested sections
ConfigSection dbConfig = config.getSection("database");
String host = dbConfig.getString("host");

// Duration parsing
Duration timeout = config.getDuration("timeout"); // "30s", "5m", "1h"
```

### Caching

Configuration files are cached automatically based on file modification time:

```java
// Uses cache if file unchanged
ConfigSection config = Configuration.fromFile("config.yml").load();

// Force reload (bypass cache)
ConfigSection config = Configuration.fromFile("config.yml").noCache().load();

// Clear all cached configurations
Configuration.clearCache();

// Clear specific file from cache
Configuration.invalidateCache(Paths.get("config.yml"));
```

### File Watching

```java
import com.natsu.jefag.common.config.ConfigurationManager;

ConfigurationManager manager = new ConfigurationManager();

// Watch a directory for changes
manager.watchForChanges(Paths.get("config"));

// Add change listener
manager.addChangeListener((path, section) -> {
    System.out.println("Config changed: " + path);
    // Reload your services with new config
});

// Stop watching
manager.stopWatching();
```

### Example Configuration (YAML)

```yaml
app:
  name: MyApplication
  version: 1.0.0

server:
  host: localhost
  port: 8080

database:
  url: jdbc:postgresql://localhost:5432/mydb
  pool:
    minSize: 5
    maxSize: 20
    timeout: 30s

features:
  - authentication
  - logging
  - caching
```

---

## Logging System

A configurable logging system with console, file, and database appender support.

### Quick Start

```java
import com.natsu.jefag.common.log.Logger;
import com.natsu.jefag.common.log.LoggerFactory;

public class MyService {
    private static final Logger logger = LoggerFactory.getLogger(MyService.class);

    public void doSomething() {
        logger.info("Service started");
        logger.debug("Processing {} items", count);
        
        try {
            // work
        } catch (Exception e) {
            logger.error("Operation failed", e);
        }
    }
}
```

### Log Levels

| Level | Description |
|-------|-------------|
| `TRACE` | Finest-grained debugging |
| `DEBUG` | Debugging information |
| `INFO` | General informational messages |
| `WARN` | Warning conditions |
| `ERROR` | Error conditions |
| `OFF` | Disable all logging |

### Message Formatting

Use `{}` placeholders for argument substitution:

```java
logger.info("User {} logged in from {}", username, ipAddress);
logger.debug("Processed {} items in {} ms", count, duration);
logger.error("Failed to process user {}", userId, exception);
```

### Configuration from File

```java
ConfigSection config = Configuration.fromFile("logging.yml").load();
LoggerFactory.configure(config);
```

**logging.yml:**
```yaml
logging:
  level: INFO
  
  appenders:
    console:
      enabled: true
      colorEnabled: true
      level: DEBUG
    
    file:
      enabled: true
      directory: logs
      pattern: app-{date}.log
      level: INFO
      maxFileSize: 10MB
      maxHistory: 7
      compress: true
  
  loggers:
    com.myapp.database: DEBUG
    com.myapp.security: TRACE
```

### Programmatic Configuration

```java
import com.natsu.jefag.common.log.appender.*;

// Console appender
ConsoleLogAppender console = ConsoleLogAppender.builder()
    .name("console")
    .level(LogLevel.DEBUG)
    .colorEnabled(true)
    .build();

// File appender with rotation
FileLogAppender file = FileLogAppender.builder()
    .name("file")
    .directory("logs")
    .fileNamePattern("app-{date}.log")
    .level(LogLevel.INFO)
    .maxFileSize(10 * 1024 * 1024)  // 10 MB
    .maxHistory(7)
    .compressRotated(true)
    .build();

// Add appenders
LoggerFactory.addAppender(console);
LoggerFactory.addAppender(file);
```

### Custom Database Appender

```java
public class JdbcLogAppender extends DatabaseLogAppender {
    private Connection connection;

    public JdbcLogAppender(String jdbcUrl) {
        super("jdbc", LogLevel.INFO, 1000, 100, 5000);
        this.jdbcUrl = jdbcUrl;
    }

    @Override
    protected void doConnect() throws Exception {
        connection = DriverManager.getConnection(jdbcUrl);
    }

    @Override
    protected void doInsert(List<LogRecord> records) throws Exception {
        // Batch insert records
    }

    @Override
    protected void doDisconnect() throws Exception {
        connection.close();
    }
}
```

### Shutdown

```java
Runtime.getRuntime().addShutdownHook(new Thread(() -> {
    LoggerFactory.shutdown();
}));
```

---

## Service Registry

A simple service locator pattern implementation for dependency management.

### Basic Usage

```java
import com.natsu.jefag.common.services.ServiceRegistry;

// Register a service
ServiceRegistry.register(MyService.class, new MyServiceImpl());

// Or register with auto type detection
ServiceRegistry.register(new MyServiceImpl());

// Get a service
MyService service = ServiceRegistry.get(MyService.class);

// Check if registered
if (ServiceRegistry.isRegistered(MyService.class)) {
    // ...
}

// Optional retrieval
Optional<MyService> service = ServiceRegistry.getIfExist(MyService.class);

// Unregister
ServiceRegistry.unregister(MyService.class);

// Clear all
ServiceRegistry.clear();
```

### Auto-instantiation

If a service is not registered, `get()` will attempt to create an instance using the default constructor:

```java
// Will create MyService if not registered
MyService service = ServiceRegistry.get(MyService.class);
```

---

## License

This project is part of the JustEnoughForAGame project.
