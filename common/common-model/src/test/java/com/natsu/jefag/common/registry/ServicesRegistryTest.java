package com.natsu.jefag.common.registry;

import com.natsu.jefag.common.cache.CacheConfig;
import com.natsu.jefag.common.database.DatabaseConfig;
import com.natsu.jefag.common.database.DatabaseType;
import com.natsu.jefag.common.message.MessageQueueConfig;
import org.junit.jupiter.api.*;

import java.time.Duration;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for ServicesRegistry.
 */
class ServicesRegistryTest {

    @BeforeEach
    void setUp() {
        ServicesRegistry.reset();
    }

    @AfterEach
    void tearDown() {
        ServicesRegistry.reset();
    }

    // ==================== Registration Tests ====================

    @Test
    void testRegisterDatabaseConfig() {
        DatabaseConfig config = DatabaseConfig.builder()
                .type(DatabaseType.MYSQL)
                .name("testdb")
                .host("localhost")
                .port(3306)
                .database("test")
                .build();

        ServicesRegistry.register(config);

        assertTrue(ServicesRegistry.contains("testdb", ServiceType.DATABASE));
        assertEquals(1, ServicesRegistry.size());
    }

    @Test
    void testRegisterCacheConfig() {
        CacheConfig config = CacheConfig.builder("testcache")
                .maxSize(1000)
                .defaultTtl(Duration.ofMinutes(5))
                .build();

        ServicesRegistry.register(config);

        assertTrue(ServicesRegistry.contains("testcache", ServiceType.CACHE));
        assertEquals(1, ServicesRegistry.size());
    }

    @Test
    void testRegisterMessageQueueConfig() {
        MessageQueueConfig config = MessageQueueConfig.local()
                .name("testqueue")
                .build();

        ServicesRegistry.register(config);

        assertTrue(ServicesRegistry.contains("testqueue", ServiceType.MESSAGE_QUEUE));
        assertEquals(1, ServicesRegistry.size());
    }

    @Test
    void testRegisterMultipleConfigs() {
        DatabaseConfig db = DatabaseConfig.mysql("localhost", 3306, "test", "user", "pass");
        CacheConfig cache = CacheConfig.defaultConfig("cache1");
        MessageQueueConfig mq = MessageQueueConfig.local().name("queue1").build();

        ServicesRegistry.registerAll(db, cache, mq);

        assertEquals(3, ServicesRegistry.size());
        assertEquals(1, ServicesRegistry.count(ServiceType.DATABASE));
        assertEquals(1, ServicesRegistry.count(ServiceType.CACHE));
        assertEquals(1, ServicesRegistry.count(ServiceType.MESSAGE_QUEUE));
    }

    @Test
    void testRegisterDuplicateThrowsException() {
        CacheConfig config1 = CacheConfig.defaultConfig("test");
        CacheConfig config2 = CacheConfig.builder("test").maxSize(2000).build();

        ServicesRegistry.register(config1);

        assertThrows(IllegalStateException.class, () -> 
            ServicesRegistry.register(config2));
    }

    @Test
    void testRegisterWithOverwrite() {
        CacheConfig config1 = CacheConfig.builder("test").maxSize(1000).build();
        CacheConfig config2 = CacheConfig.builder("test").maxSize(2000).build();

        ServicesRegistry.register(config1);
        ServicesRegistry.register(config2, true);

        CacheConfig retrieved = ServicesRegistry.get("test", ServiceType.CACHE);
        assertEquals(2000, retrieved.getMaxSize());
    }

    @Test
    void testRegisterIfAbsent() {
        CacheConfig config1 = CacheConfig.builder("test").maxSize(1000).build();
        CacheConfig config2 = CacheConfig.builder("test").maxSize(2000).build();

        assertTrue(ServicesRegistry.registerIfAbsent(config1));
        assertFalse(ServicesRegistry.registerIfAbsent(config2));

        CacheConfig retrieved = ServicesRegistry.get("test", ServiceType.CACHE);
        assertEquals(1000, retrieved.getMaxSize());
    }

    // ==================== Retrieval Tests ====================

    @Test
    void testGetExistingConfig() {
        DatabaseConfig original = DatabaseConfig.postgresql("localhost", 5432, "mydb", "user", "pass");
        ServicesRegistry.register(original);

        DatabaseConfig retrieved = ServicesRegistry.get("postgresql-db", ServiceType.DATABASE);

        assertEquals("postgresql-db", retrieved.getName());
        assertEquals(DatabaseType.POSTGRESQL, retrieved.getType());
    }

    @Test
    void testGetNonExistentThrowsException() {
        assertThrows(NoSuchElementException.class, () -> 
            ServicesRegistry.get("nonexistent", ServiceType.DATABASE));
    }

    @Test
    void testGetOrNullReturnsNull() {
        CacheConfig result = ServicesRegistry.getOrNull("nonexistent", ServiceType.CACHE);
        assertNull(result);
    }

    @Test
    void testGetOrDefaultReturnsDefault() {
        CacheConfig defaultConfig = CacheConfig.defaultConfig("default");
        
        CacheConfig result = ServicesRegistry.getOrDefault("nonexistent", ServiceType.CACHE, defaultConfig);
        
        assertEquals("default", result.getName());
    }

    @Test
    void testGetAll() {
        ServicesRegistry.register(CacheConfig.defaultConfig("cache1"));
        ServicesRegistry.register(CacheConfig.defaultConfig("cache2"));
        ServicesRegistry.register(CacheConfig.defaultConfig("cache3"));
        ServicesRegistry.register(DatabaseConfig.h2InMemory("db1"));

        List<CacheConfig> caches = ServicesRegistry.getAll(ServiceType.CACHE);

        assertEquals(3, caches.size());
    }

    @Test
    void testGetNames() {
        ServicesRegistry.register(CacheConfig.defaultConfig("alpha"));
        ServicesRegistry.register(CacheConfig.defaultConfig("beta"));
        ServicesRegistry.register(CacheConfig.defaultConfig("gamma"));

        var names = ServicesRegistry.getNames(ServiceType.CACHE);

        assertEquals(3, names.size());
        assertTrue(names.contains("alpha"));
        assertTrue(names.contains("beta"));
        assertTrue(names.contains("gamma"));
    }

    // ==================== Removal Tests ====================

    @Test
    void testUnregisterByName() {
        ServicesRegistry.register(CacheConfig.defaultConfig("test"));
        assertTrue(ServicesRegistry.contains("test", ServiceType.CACHE));

        boolean removed = ServicesRegistry.unregister("test", ServiceType.CACHE);

        assertTrue(removed);
        assertFalse(ServicesRegistry.contains("test", ServiceType.CACHE));
    }

    @Test
    void testUnregisterByConfig() {
        CacheConfig config = CacheConfig.defaultConfig("test");
        ServicesRegistry.register(config);

        boolean removed = ServicesRegistry.unregister(config);

        assertTrue(removed);
        assertFalse(ServicesRegistry.contains("test", ServiceType.CACHE));
    }

    @Test
    void testClearType() {
        ServicesRegistry.register(CacheConfig.defaultConfig("cache1"));
        ServicesRegistry.register(CacheConfig.defaultConfig("cache2"));
        ServicesRegistry.register(DatabaseConfig.h2InMemory("db1"));

        int removed = ServicesRegistry.clearType(ServiceType.CACHE);

        assertEquals(2, removed);
        assertEquals(1, ServicesRegistry.size());
        assertTrue(ServicesRegistry.contains("h2-db", ServiceType.DATABASE));
    }

    @Test
    void testClearAll() {
        ServicesRegistry.register(CacheConfig.defaultConfig("cache1"));
        ServicesRegistry.register(DatabaseConfig.h2InMemory("db1"));
        ServicesRegistry.register(MessageQueueConfig.local().name("mq1").build());

        ServicesRegistry.clear();

        assertTrue(ServicesRegistry.isEmpty());
    }

    // ==================== Listener Tests ====================

    @Test
    void testListenerNotification() {
        AtomicInteger callCount = new AtomicInteger(0);
        
        ServicesRegistry.onRegister(ServiceType.CACHE, config -> 
            callCount.incrementAndGet());

        ServicesRegistry.register(CacheConfig.defaultConfig("cache1"));
        ServicesRegistry.register(CacheConfig.defaultConfig("cache2"));
        ServicesRegistry.register(DatabaseConfig.h2InMemory("db1")); // Should not trigger

        assertEquals(2, callCount.get());
    }

    // ==================== ServiceConfig Interface Tests ====================

    @Test
    void testDatabaseConfigImplementsServiceConfig() {
        DatabaseConfig config = DatabaseConfig.mysql("localhost", 3306, "test", "user", "pass");

        assertEquals(ServiceType.DATABASE, config.getServiceType());
        assertNotNull(config.getName());
        assertDoesNotThrow(config::validate);
        assertNotNull(config.toMap());
        assertNotNull(config.getDescription());
    }

    @Test
    void testCacheConfigImplementsServiceConfig() {
        CacheConfig config = CacheConfig.defaultConfig("test");

        assertEquals(ServiceType.CACHE, config.getServiceType());
        assertEquals("test", config.getName());
        assertDoesNotThrow(config::validate);
        assertTrue(config.toMap().containsKey("maxSize"));
    }

    @Test
    void testMessageQueueConfigImplementsServiceConfig() {
        MessageQueueConfig config = MessageQueueConfig.local()
                .name("testqueue")
                .build();

        assertEquals(ServiceType.MESSAGE_QUEUE, config.getServiceType());
        assertEquals("testqueue", config.getName());
        assertDoesNotThrow(config::validate);
        assertTrue(config.toMap().containsKey("messageQueueType"));
    }

    // ==================== Namespace Isolation Tests ====================

    @Test
    void testSameNameDifferentTypesAreIsolated() {
        DatabaseConfig db = DatabaseConfig.builder()
                .type(DatabaseType.H2)
                .name("test")
                .database("mem:test")
                .build();
        CacheConfig cache = CacheConfig.defaultConfig("test");
        MessageQueueConfig mq = MessageQueueConfig.local().name("test").build();

        ServicesRegistry.register(db);
        ServicesRegistry.register(cache);
        ServicesRegistry.register(mq);

        assertEquals(3, ServicesRegistry.size());

        DatabaseConfig retrievedDb = ServicesRegistry.get("test", ServiceType.DATABASE);
        CacheConfig retrievedCache = ServicesRegistry.get("test", ServiceType.CACHE);
        MessageQueueConfig retrievedMq = ServicesRegistry.get("test", ServiceType.MESSAGE_QUEUE);

        assertEquals(DatabaseType.H2, retrievedDb.getType());
        assertEquals(CacheConfig.EvictionPolicy.LRU, retrievedCache.getEvictionPolicy());
        assertEquals(MessageQueueConfig.MessageQueueType.LOCAL, retrievedMq.getType());
    }

    // ==================== Summary Test ====================

    @Test
    void testSummary() {
        ServicesRegistry.register(DatabaseConfig.h2InMemory("db1"));
        ServicesRegistry.register(CacheConfig.defaultConfig("cache1"));

        String summary = ServicesRegistry.summary();

        assertNotNull(summary);
        assertTrue(summary.contains("DATABASE"));
        assertTrue(summary.contains("CACHE"));
    }
}
