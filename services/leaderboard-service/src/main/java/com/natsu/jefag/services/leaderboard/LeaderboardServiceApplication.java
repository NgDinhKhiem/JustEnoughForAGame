package com.natsu.jefag.services.leaderboard;

import com.natsu.common.springboot.BaseSpringBootApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Leaderboard Service Application
 * 
 * Manages game leaderboards and rankings including:
 * - Global and seasonal leaderboards
 * - Player ranking calculations
 * - Statistics aggregation
 * - Historical score tracking
 */
@SpringBootApplication
public class LeaderboardServiceApplication extends BaseSpringBootApplication {
    
    public static void main(String[] args) {
        runService(LeaderboardServiceApplication.class, args);
    }
}

