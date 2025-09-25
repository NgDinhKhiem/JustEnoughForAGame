package com.natsu.services.game;

import com.natsu.common.springboot.BaseSpringBootApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Game Service Application
 * 
 * Handles active game sessions and game logic including:
 * - Game session management
 * - Real-time game state updates via WebSocket
 * - Game logic execution
 * - Player actions validation
 * - Game results and scoring
 */
@SpringBootApplication
public class GameServiceApplication extends BaseSpringBootApplication {
    
    public static void main(String[] args) {
        runService(GameServiceApplication.class, args);
    }
}

