package com.natsu.common.springboot;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * Base Spring Boot Application class that provides common configuration
 * for all microservices in the gaming platform.
 * 
 * This class includes:
 * - Standard Spring Boot auto-configuration
 * - Async processing support
 * - Configuration properties scanning
 * - Component scanning for common packages
 */
@SpringBootApplication(scanBasePackages = {
    "com.natsu.common",
    "com.natsu.services"
})
@ConfigurationPropertiesScan(basePackages = {
    "com.natsu.common",
    "com.natsu.services"
})
@EnableAsync
public abstract class BaseSpringBootApplication {
    
    /**
     * Helper method to run a Spring Boot application with common configuration.
     * Services should call this from their main method.
     * 
     * @param applicationClass The service's main application class
     * @param args Command line arguments
     */
    public static void runService(Class<?> applicationClass, String[] args) {
        SpringApplication.run(applicationClass, args);
    }
}

