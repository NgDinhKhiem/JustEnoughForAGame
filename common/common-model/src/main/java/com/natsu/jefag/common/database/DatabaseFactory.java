package com.natsu.jefag.common.database;

import com.natsu.jefag.common.database.nosql.*;
import com.natsu.jefag.common.database.sql.*;
import com.natsu.jefag.common.registry.ServiceType;
import com.natsu.jefag.common.registry.ServicesRegistry;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Factory for creating database instances.
 * 
 * <p>Supports loading configurations from {@link ServicesRegistry}.
 */
public class DatabaseFactory {

    private static final Map<String, Database> databases = new ConcurrentHashMap<>();

    private DatabaseFactory() {
    }

    /**
     * Creates a SQL database from configuration.
     *
     * @param config the database configuration
     * @return the SQL database instance
     */
    public static SqlDatabase createSql(DatabaseConfig config) {
        SqlDatabase db = switch (config.getType()) {
            case MYSQL -> createMySql(config);
            case POSTGRESQL -> createPostgreSql(config);
            case CLICKHOUSE -> createClickHouse(config);
            case H2 -> createH2(config);
            case SQLITE -> createSqlite(config);
            default -> throw new IllegalArgumentException("Not a SQL database type: " + config.getType());
        };
        
        registerDatabase(config.getName(), db);
        return db;
    }

    /**
     * Creates a NoSQL database from configuration.
     *
     * @param config the database configuration
     * @param clientAdapter the client adapter for the specific database
     * @param <T> the adapter type
     * @return the NoSQL database instance
     */
    @SuppressWarnings("unchecked")
    public static <T> NoSqlDatabase createNoSql(DatabaseConfig config, T clientAdapter) {
        NoSqlDatabase db = switch (config.getType()) {
            case MONGODB -> MongoDatabase.create(
                    config.getName(),
                    (MongoDatabase.MongoClientAdapter) clientAdapter,
                    config.getDatabase()
            );
            case FIREBASE -> FirebaseDatabase.create(
                    config.getName(),
                    (FirebaseDatabase.FirebaseClientAdapter) clientAdapter
            );
            case DYNAMODB -> DynamoDatabase.create(
                    config.getName(),
                    (DynamoDatabase.DynamoClientAdapter) clientAdapter
            );
            case REDIS -> RedisDatabase.create(
                    config.getName(),
                    (RedisDatabase.RedisClientAdapter) clientAdapter,
                    config.getDatabase() + ":"
            );
            case CASSANDRA -> CassandraDatabase.create(
                    config.getName(),
                    (CassandraDatabase.CassandraClientAdapter) clientAdapter,
                    config.getDatabase()
            );
            default -> throw new IllegalArgumentException("Not a NoSQL database type: " + config.getType());
        };
        
        registerDatabase(config.getName(), db);
        return db;
    }

    /**
     * Creates an in-memory NoSQL database for testing.
     *
     * @param name the database name
     * @return the in-memory NoSQL database
     */
    public static InMemoryNoSqlDatabase createInMemoryNoSql(String name) {
        InMemoryNoSqlDatabase db = InMemoryNoSqlDatabase.create(name);
        registerDatabase(name, db);
        return db;
    }

    /**
     * Creates an in-memory H2 database for testing.
     *
     * @param name the database name
     * @return the H2 SQL database
     */
    public static SqlDatabase createInMemorySql(String name) {
        DatabaseConfig config = DatabaseConfig.h2InMemory(name);
        return createSql(config);
    }

    // SQL database creation helpers

    private static SqlDatabase createMySql(DatabaseConfig config) {
        String jdbcUrl = config.toJdbcUrl();
        String username = config.getUsername();
        String password = config.getPassword();
        DatabaseConfig.PoolingConfig pooling = config.getPooling();

        if (pooling.getPoolType() == DatabaseConfig.PoolingConfig.PoolType.HIKARI) {
            return MySqlDatabase.createWithHikari(
                    config.getName(),
                    jdbcUrl,
                    username,
                    password
            );
        } else {
            return MySqlDatabase.create(
                    config.getName(),
                    jdbcUrl,
                    username,
                    password
            );
        }
    }

    private static SqlDatabase createPostgreSql(DatabaseConfig config) {
        String jdbcUrl = config.toJdbcUrl();
        String username = config.getUsername();
        String password = config.getPassword();
        DatabaseConfig.PoolingConfig pooling = config.getPooling();

        if (pooling.getPoolType() == DatabaseConfig.PoolingConfig.PoolType.HIKARI) {
            return PostgreSqlDatabase.createWithHikari(
                    config.getName(),
                    jdbcUrl,
                    username,
                    password
            );
        } else {
            return PostgreSqlDatabase.create(
                    config.getName(),
                    jdbcUrl,
                    username,
                    password
            );
        }
    }

    private static SqlDatabase createClickHouse(DatabaseConfig config) {
        String jdbcUrl = config.toJdbcUrl();
        String username = config.getUsername();
        String password = config.getPassword();
        DatabaseConfig.PoolingConfig pooling = config.getPooling();

        if (pooling.getPoolType() == DatabaseConfig.PoolingConfig.PoolType.HIKARI) {
            return ClickHouseDatabase.createWithHikari(
                    config.getName(),
                    jdbcUrl,
                    username,
                    password
            );
        } else {
            return ClickHouseDatabase.create(
                    config.getName(),
                    jdbcUrl,
                    username,
                    password
            );
        }
    }

    private static SqlDatabase createH2(DatabaseConfig config) {
        // H2 uses the database field as part of the URL
        String database = config.getDatabase();
        String jdbcUrl;
        
        if (database.startsWith("mem:")) {
            jdbcUrl = "jdbc:h2:" + database;
        } else if (database.startsWith("file:") || database.startsWith("tcp:")) {
            jdbcUrl = "jdbc:h2:" + database;
        } else {
            jdbcUrl = "jdbc:h2:file:" + database;
        }

        DatabaseConfig.PoolingConfig pooling = config.getPooling();
        ConnectionPool pool;

        if (pooling.getPoolType() == DatabaseConfig.PoolingConfig.PoolType.HIKARI) {
            HikariConnectionPool.HikariConfig hikariConfig = HikariConnectionPool.HikariConfig.create(jdbcUrl)
                    .username(config.getUsername())
                    .password(config.getPassword())
                    .maxPoolSize(pooling.getMaxSize())
                    .minPoolSize(pooling.getMinSize());
            pool = HikariConnectionPool.create(hikariConfig);
        } else {
            pool = SimpleConnectionPool.builder()
                    .jdbcUrl(jdbcUrl)
                    .username(config.getUsername())
                    .password(config.getPassword())
                    .minPoolSize(pooling.getMinSize())
                    .maxPoolSize(pooling.getMaxSize())
                    .build();
        }

        return new AbstractSqlDatabase(config.getName(), DatabaseType.H2, pool) {};
    }

    private static SqlDatabase createSqlite(DatabaseConfig config) {
        String jdbcUrl = "jdbc:sqlite:" + config.getDatabase();
        
        // SQLite doesn't support multiple connections well, so we limit pool size
        ConnectionPool pool = SimpleConnectionPool.builder()
                .jdbcUrl(jdbcUrl)
                .minPoolSize(1)
                .maxPoolSize(1)
                .build();

        return new AbstractSqlDatabase(config.getName(), DatabaseType.SQLITE, pool) {};
    }

    // Registry methods

    /**
     * Registers a database instance.
     *
     * @param name the database name
     * @param database the database instance
     */
    public static void registerDatabase(String name, Database database) {
        databases.put(name, database);
    }

    /**
     * Gets a registered database by name.
     *
     * @param name the database name
     * @return the database instance, or null if not found
     */
    public static Database getDatabase(String name) {
        return databases.get(name);
    }

    /**
     * Gets a registered SQL database by name.
     *
     * @param name the database name
     * @return the SQL database instance
     */
    public static SqlDatabase getSqlDatabase(String name) {
        Database db = databases.get(name);
        if (db instanceof SqlDatabase) {
            return (SqlDatabase) db;
        }
        throw new IllegalArgumentException("Database '" + name + "' is not a SQL database");
    }

    /**
     * Gets a registered NoSQL database by name.
     *
     * @param name the database name
     * @return the NoSQL database instance
     */
    public static NoSqlDatabase getNoSqlDatabase(String name) {
        Database db = databases.get(name);
        if (db instanceof NoSqlDatabase) {
            return (NoSqlDatabase) db;
        }
        throw new IllegalArgumentException("Database '" + name + "' is not a NoSQL database");
    }

    /**
     * Removes a database from the registry.
     *
     * @param name the database name
     * @return the removed database, or null if not found
     */
    public static Database unregisterDatabase(String name) {
        return databases.remove(name);
    }

    /**
     * Disconnects and removes all registered databases.
     */
    public static void shutdown() {
        for (Database db : databases.values()) {
            try {
                db.disconnect();
            } catch (Exception e) {
                // Ignore disconnection errors during shutdown
            }
        }
        databases.clear();
    }

    /**
     * Gets all registered database names.
     *
     * @return the set of database names
     */
    public static java.util.Set<String> getDatabaseNames() {
        return java.util.Set.copyOf(databases.keySet());
    }

    // ==================== ServicesRegistry Integration ====================

    /**
     * Creates a SQL database from a configuration registered in ServicesRegistry.
     *
     * @param name the configuration name in the registry
     * @return the SQL database instance
     */
    public static SqlDatabase createSqlFromRegistry(String name) {
        DatabaseConfig config = ServicesRegistry.get(name, ServiceType.DATABASE);
        return createSql(config);
    }

    /**
     * Creates a NoSQL database from a configuration registered in ServicesRegistry.
     *
     * @param name the configuration name in the registry
     * @param clientAdapter the client adapter for the specific database
     * @param <T> the adapter type
     * @return the NoSQL database instance
     */
    public static <T> NoSqlDatabase createNoSqlFromRegistry(String name, T clientAdapter) {
        DatabaseConfig config = ServicesRegistry.get(name, ServiceType.DATABASE);
        return createNoSql(config, clientAdapter);
    }

    /**
     * Gets a SQL database, creating it from registry if not already created.
     *
     * @param name the database/config name
     * @return the SQL database instance
     */
    public static SqlDatabase getOrCreateSql(String name) {
        Database existing = databases.get(name);
        if (existing instanceof SqlDatabase) {
            return (SqlDatabase) existing;
        }
        return createSqlFromRegistry(name);
    }

    /**
     * Creates all SQL databases from configurations registered in ServicesRegistry.
     */
    public static void createAllFromRegistry() {
        for (DatabaseConfig config : ServicesRegistry.<DatabaseConfig>getAll(ServiceType.DATABASE)) {
            if (config.getType().isSql()) {
                createSql(config);
            }
        }
    }
}
