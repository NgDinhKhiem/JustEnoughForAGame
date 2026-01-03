# Logging System Guide

A flexible, configurable logging system for the JEFAG common utilities library. Supports multiple output targets (console, file, database) with configuration integration.

## Table of Contents

- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Logger Usage](#logger-usage)
- [Configuration](#configuration)
- [Appenders](#appenders)
- [Advanced Usage](#advanced-usage)
- [Integration with Configuration System](#integration-with-configuration-system)

---

## Quick Start

### Basic Logging

```java
import com.natsu.jefag.common.log.Logger;
import com.natsu.jefag.common.log.LoggerFactory;

public class MyService {
    private static final Logger logger = LoggerFactory.getLogger(MyService.class);

    public void doSomething() {
        logger.info("Service started");
        logger.debug("Processing item: {}", itemId);
        
        try {
            // ... work
        } catch (Exception e) {
            logger.error("Failed to process", e);
        }
    }
}
```

### With Configuration

```java
import com.natsu.jefag.common.config.Configuration;
import com.natsu.jefag.common.log.LoggerFactory;

// Load and apply logging configuration
ConfigSection config = Configuration.fromFile("logging.yml").load();
LoggerFactory.configure(config);

// Now all loggers use the configured appenders
Logger logger = LoggerFactory.getLogger("my.app");
logger.info("Logging configured from file!");
```

---

## Core Concepts

### Log Levels

The system supports these log levels (in order of severity):

| Level | Description |
|-------|-------------|
| `TRACE` | Finest-grained debugging information |
| `DEBUG` | Debugging information |
| `INFO` | General informational messages |
| `WARN` | Warning conditions |
| `ERROR` | Error conditions |
| `OFF` | Turn off all logging |

Logs at a level are only output if that level is enabled. For example, if level is set to `WARN`, only `WARN` and `ERROR` messages are logged.

### Message Formatting

Use `{}` placeholders for argument substitution:

```java
logger.info("User {} logged in from {}", username, ipAddress);
// Output: User john logged in from 192.168.1.1

logger.debug("Processing {} items in {} ms", count, duration);
// Output: Processing 42 items in 156 ms
```

### Exceptions

Pass exceptions as the last argument:

```java
try {
    riskyOperation();
} catch (Exception e) {
    logger.error("Operation failed", e);
    // or with context:
    logger.error("Operation failed for user {}", userId, e);
}
```

---

## Logger Usage

### Getting a Logger

```java
// By class (recommended)
Logger logger = LoggerFactory.getLogger(MyClass.class);

// By name
Logger logger = LoggerFactory.getLogger("com.myapp.module");
```

### Log Methods

Each level has multiple method overloads:

```java
// Simple message
logger.info("Message");

// Message with placeholders
logger.info("Hello, {}!", name);
logger.info("User {} did {} on {}", user, action, target);

// Message with exception
logger.error("Failed to connect", exception);

// Message with placeholders and exception
logger.error("Failed to process {}", itemId, exception);
```

### Checking Level

Avoid expensive operations when level is disabled:

```java
if (logger.isDebugEnabled()) {
    logger.debug("Detailed state: {}", expensiveSerialize(state));
}
```

### Setting Level Per-Logger

```java
Logger logger = LoggerFactory.getLogger("com.myapp.verbose");
logger.setLevel(LogLevel.TRACE);  // More verbose for this logger
```

---

## Configuration

### YAML Configuration

```yaml
logging:
  level: INFO  # Root level
  
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
  
  # Per-logger level overrides
  loggers:
    com.myapp.database: DEBUG
    com.myapp.security: TRACE
    com.noisy.library: WARN
```

### JSON Configuration

```json
{
  "logging": {
    "level": "INFO",
    "appenders": {
      "console": {
        "enabled": true,
        "colorEnabled": true,
        "level": "DEBUG"
      },
      "file": {
        "enabled": true,
        "directory": "logs",
        "pattern": "app-{date}.log",
        "level": "INFO",
        "maxFileSize": "10MB"
      }
    },
    "loggers": {
      "com.myapp.database": "DEBUG"
    }
  }
}
```

### TOML Configuration

```toml
[logging]
level = "INFO"

[logging.appenders.console]
enabled = true
colorEnabled = true
level = "DEBUG"

[logging.appenders.file]
enabled = true
directory = "logs"
pattern = "app-{date}.log"
level = "INFO"
maxFileSize = "10MB"
maxHistory = 7
compress = true

[logging.loggers]
"com.myapp.database" = "DEBUG"
"com.myapp.security" = "TRACE"
```

### Applying Configuration

```java
// From file
ConfigSection config = Configuration.fromFile("config/logging.yml").load();
LoggerFactory.configure(config);

// From classpath
ConfigSection config = Configuration.fromClasspath("/logging.yml").load();
LoggerFactory.configure(config);
```

---

## Appenders

### Console Appender

Outputs colored log messages to stdout/stderr.

```java
import com.natsu.jefag.common.log.appender.ConsoleLogAppender;

ConsoleLogAppender appender = ConsoleLogAppender.builder()
    .name("console")
    .level(LogLevel.DEBUG)
    .colorEnabled(true)      // ANSI colors
    .errorToStderr(true)     // WARN/ERROR to stderr
    .build();

LoggerFactory.addAppender(appender);
```

**Color Scheme:**
- TRACE: Cyan
- DEBUG: White
- INFO: Green
- WARN: Yellow
- ERROR: Red (bold)

### File Appender

Outputs to log files with rotation support.

```java
import com.natsu.jefag.common.log.appender.FileLogAppender;

FileLogAppender appender = FileLogAppender.builder()
    .name("file")
    .directory("logs")
    .fileNamePattern("app-{date}.log")  // {date} -> 2024-01-15
    .level(LogLevel.INFO)
    .maxFileSize(10 * 1024 * 1024)      // 10 MB
    .maxHistory(7)                       // Keep 7 days
    .compressRotated(true)               // Gzip old logs
    .build();

LoggerFactory.addAppender(appender);
```

**File Rotation:**
- By size: Rotates when file exceeds `maxFileSize`
- By date: New file each day if using `{date}` pattern
- Compressed: Old files gzipped with `.gz` extension
- History: Old files deleted after `maxHistory` days

### Database Appender

Abstract base for database logging. Extend to implement your database:

```java
import com.natsu.jefag.common.log.appender.DatabaseLogAppender;

public class JdbcLogAppender extends DatabaseLogAppender {
    private Connection connection;
    private PreparedStatement stmt;

    public JdbcLogAppender(String name, String jdbcUrl) {
        super(name, LogLevel.INFO, 100, 5000); // batch: 100, flush: 5s
        this.jdbcUrl = jdbcUrl;
    }

    @Override
    protected void doConnect() throws Exception {
        connection = DriverManager.getConnection(jdbcUrl);
        stmt = connection.prepareStatement(
            "INSERT INTO logs (timestamp, level, logger, message, thread, exception) " +
            "VALUES (?, ?, ?, ?, ?, ?)"
        );
    }

    @Override
    protected void doInsert(List<LogRecord> records) throws Exception {
        for (LogRecord record : records) {
            stmt.setTimestamp(1, Timestamp.from(record.timestamp()));
            stmt.setString(2, record.level());
            stmt.setString(3, record.loggerName());
            stmt.setString(4, record.formattedMessage());
            stmt.setString(5, record.threadName());
            stmt.setString(6, record.stackTrace());
            stmt.addBatch();
        }
        stmt.executeBatch();
    }

    @Override
    protected void doDisconnect() throws Exception {
        if (stmt != null) stmt.close();
        if (connection != null) connection.close();
    }
}
```

**Features:**
- Async writing via background thread
- Batched inserts for performance
- Configurable batch size and flush interval
- Graceful shutdown with flush

---

## Advanced Usage

### Custom Appender

Implement `LogAppender` or extend `AbstractLogAppender`:

```java
import com.natsu.jefag.common.log.appender.AbstractLogAppender;

public class SlackLogAppender extends AbstractLogAppender {
    private final String webhookUrl;

    public SlackLogAppender(String name, String webhookUrl) {
        super(name, LogLevel.ERROR);  // Only errors to Slack
        this.webhookUrl = webhookUrl;
    }

    @Override
    protected void doAppend(LogEvent event) {
        String message = LogFormatter.formatForFile(event);
        sendToSlack(webhookUrl, message);
    }
}
```

### Multiple Appenders

```java
// Add multiple appenders for different outputs
LoggerFactory.addAppender(consoleAppender);
LoggerFactory.addAppender(fileAppender);
LoggerFactory.addAppender(databaseAppender);
```

### Logger Hierarchy

Child loggers inherit from root:

```java
// Root level
LoggerFactory.setRootLevel(LogLevel.INFO);

// Specific logger can be more verbose
Logger dbLogger = LoggerFactory.getLogger("com.myapp.database");
dbLogger.setLevel(LogLevel.DEBUG);

// This logger uses root level (INFO)
Logger appLogger = LoggerFactory.getLogger("com.myapp");
```

### Programmatic Configuration

```java
// Reset to clean state
LoggerFactory.reset();

// Set root level
LoggerFactory.setRootLevel(LogLevel.DEBUG);

// Add appenders
LoggerFactory.addAppender(
    ConsoleLogAppender.builder()
        .name("console")
        .colorEnabled(true)
        .build()
);

LoggerFactory.addAppender(
    FileLogAppender.builder()
        .name("file")
        .directory("logs")
        .maxFileSize(50 * 1024 * 1024)
        .build()
);
```

### Shutdown

Always shut down logging on application exit:

```java
Runtime.getRuntime().addShutdownHook(new Thread(() -> {
    LoggerFactory.shutdown();
}));
```

---

## Integration with Configuration System

### Combined Application Configuration

```yaml
# application.yml
app:
  name: MyApplication
  version: 1.0.0

database:
  url: jdbc:postgresql://localhost:5432/mydb
  pool:
    size: 10

logging:
  level: INFO
  appenders:
    console:
      enabled: true
      colorEnabled: true
    file:
      enabled: true
      directory: logs
      pattern: "{date}-myapp.log"
  loggers:
    com.myapp: DEBUG
```

### Unified Loading

```java
public class Application {
    private static final Logger logger = LoggerFactory.getLogger(Application.class);

    public static void main(String[] args) {
        // Load configuration
        ConfigSection config = Configuration.fromFile("application.yml").load();

        // Configure logging first
        LoggerFactory.configure(config);

        // Now logging works with file config
        logger.info("Application starting: {}", config.getString("app.name"));

        // Use other config sections
        String dbUrl = config.getString("database.url");
        int poolSize = config.getInt("database.pool.size");
        
        logger.debug("Database: {}, Pool: {}", dbUrl, poolSize);
    }
}
```

### Hot Reloading

```java
// Watch for config changes
ConfigurationManager manager = new ConfigurationManager();
manager.watchForChanges(Paths.get("config"));

manager.addChangeListener((path, section) -> {
    if (path.getFileName().toString().contains("logging")) {
        logger.info("Reloading logging configuration");
        LoggerFactory.configure(section);
    }
});
```

---

## Best Practices

### 1. Use Static Logger Fields

```java
// Good - single logger instance
private static final Logger logger = LoggerFactory.getLogger(MyClass.class);

// Avoid - creates new instance each time
public void method() {
    Logger logger = LoggerFactory.getLogger(MyClass.class);  // Don't do this
}
```

### 2. Use Placeholders Instead of Concatenation

```java
// Good - lazy formatting
logger.debug("User {} processed {} items", user, count);

// Avoid - always builds string even if debug disabled
logger.debug("User " + user + " processed " + count + " items");
```

### 3. Log at Appropriate Levels

```java
logger.trace("Entering method with param: {}", param);  // Method entry/exit
logger.debug("Cache miss for key: {}", key);            // Debugging details
logger.info("Server started on port {}", port);         // Operational info
logger.warn("Connection pool low: {}/{}", used, max);   // Warning conditions
logger.error("Failed to save user", exception);         // Errors
```

### 4. Include Context in Messages

```java
// Good - includes context
logger.error("Failed to process order {} for user {}", orderId, userId, ex);

// Less helpful
logger.error("Order processing failed", ex);
```

### 5. Don't Log Sensitive Data

```java
// Avoid logging passwords, tokens, PII
logger.debug("User logged in: {}", user.getUsername());  // OK
logger.debug("Password: {}", password);                   // Don't!
```

---

## API Reference

### LogLevel

```java
LogLevel.TRACE    // isEnabledFor(TRACE) = true for all except OFF
LogLevel.DEBUG    // isEnabledFor(DEBUG) = true for DEBUG and above
LogLevel.INFO     // isEnabledFor(INFO) = true for INFO and above
LogLevel.WARN     // isEnabledFor(WARN) = true for WARN and ERROR
LogLevel.ERROR    // isEnabledFor(ERROR) = true for ERROR only
LogLevel.OFF      // Disables all logging

// Parse from string
LogLevel level = LogLevel.fromString("INFO");
```

### Logger

```java
Logger logger = LoggerFactory.getLogger(MyClass.class);

// Logging methods
logger.trace(message, args...);
logger.debug(message, args...);
logger.info(message, args...);
logger.warn(message, args...);
logger.error(message, args...);
logger.error(message, throwable);

// Level checking
boolean enabled = logger.isDebugEnabled();

// Configuration
logger.setLevel(LogLevel.DEBUG);
logger.addAppender(appender);
logger.removeAppender(appender);
```

### LoggerFactory

```java
// Get loggers
Logger logger = LoggerFactory.getLogger(MyClass.class);
Logger logger = LoggerFactory.getLogger("name");
Logger root = LoggerFactory.getRootLogger();

// Configuration
LoggerFactory.configure(configSection);
LoggerFactory.setRootLevel(LogLevel.INFO);
LoggerFactory.addAppender(appender);
LoggerFactory.removeAppender(appender);

// Lifecycle
LoggerFactory.shutdown();  // Close all appenders
LoggerFactory.reset();     // Reset to defaults
```
