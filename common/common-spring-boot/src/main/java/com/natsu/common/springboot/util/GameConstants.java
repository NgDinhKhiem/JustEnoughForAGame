package com.natsu.common.springboot.util;

/**
 * Common constants used across all game services
 */
public final class GameConstants {
    
    private GameConstants() {
        // Utility class
    }
    
    // HTTP Headers
    public static final String HEADER_USER_ID = "X-User-Id";
    public static final String HEADER_SESSION_ID = "X-Session-Id";
    public static final String HEADER_GAME_ID = "X-Game-Id";
    public static final String HEADER_REQUEST_ID = "X-Request-Id";
    
    // Cache Keys
    public static final String CACHE_USER_PROFILE = "user:profile:";
    public static final String CACHE_GAME_SESSION = "game:session:";
    public static final String CACHE_LOBBY = "lobby:";
    public static final String CACHE_LEADERBOARD = "leaderboard:";
    
    // Kafka Topics
    public static final String TOPIC_USER_EVENTS = "user.events";
    public static final String TOPIC_GAME_EVENTS = "game.events";
    public static final String TOPIC_LOBBY_EVENTS = "lobby.events";
    public static final String TOPIC_ANALYTICS_EVENTS = "analytics.events";
    
    // Default Values
    public static final int DEFAULT_PAGE_SIZE = 20;
    public static final int MAX_PAGE_SIZE = 100;
    public static final int DEFAULT_TIMEOUT_SECONDS = 30;
    
    // Game Rules
    public static final int MIN_PLAYERS_PER_GAME = 2;
    public static final int MAX_PLAYERS_PER_GAME = 4;
    public static final int MAX_GAME_DURATION_MINUTES = 30;
}

