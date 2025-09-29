package com.natsu.jefag.services.lobby;

import com.natsu.common.springboot.BaseSpringBootApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Lobby Service Application
 * 
 * Manages game lobbies and matchmaking including:
 * - Creating and managing game rooms
 * - Player matchmaking based on skill level
 * - Real-time lobby communication via WebSocket
 * - Queue management for waiting players
 */
@SpringBootApplication
public class LobbyServiceApplication extends BaseSpringBootApplication {
    
    public static void main(String[] args) {
        runService(LobbyServiceApplication.class, args);
    }
}

