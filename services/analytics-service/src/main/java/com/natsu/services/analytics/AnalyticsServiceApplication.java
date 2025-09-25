package com.natsu.services.analytics;

import com.natsu.common.springboot.BaseSpringBootApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Analytics Service Application
 * 
 * Processes game analytics and generates insights including:
 * - Game event processing from Kafka streams
 * - Player behavior analysis
 * - Game performance metrics
 * - Business intelligence reports
 * - Data export to ClickHouse for OLAP queries
 */
@SpringBootApplication
public class AnalyticsServiceApplication extends BaseSpringBootApplication {
    
    public static void main(String[] args) {
        runService(AnalyticsServiceApplication.class, args);
    }
}

