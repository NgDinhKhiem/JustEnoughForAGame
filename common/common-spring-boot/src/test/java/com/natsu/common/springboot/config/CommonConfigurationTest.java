package com.natsu.common.springboot.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

/**
 * Test to verify that common Spring Boot configuration loads correctly.
 */
@SpringBootTest(classes = {
    CommonWebConfig.class,
    CommonSecurityConfig.class,
    CommonBeanConfig.class
})
@TestPropertySource(properties = {
    "spring.application.name=test-service",
    "logging.level.org.springframework.security=DEBUG"
})
public class CommonConfigurationTest {
    
    @Test
    public void contextLoads() {
        // This test will fail if there are any bean definition conflicts
        // or circular dependencies in the configuration
    }
}

