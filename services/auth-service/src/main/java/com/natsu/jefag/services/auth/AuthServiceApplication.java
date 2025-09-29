package com.natsu.jefag.services.auth;

import com.natsu.common.springboot.BaseSpringBootApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Authentication Service Application
 * 
 * Provides user authentication and authorization services including:
 * - User login/logout
 * - User registration
 * - JWT token generation and validation
 * - Session management with Redis
 * - OAuth2 integration
 */
@SpringBootApplication
public class AuthServiceApplication extends BaseSpringBootApplication {
    
    public static void main(String[] args) {
        runService(AuthServiceApplication.class, args);
    }
}

