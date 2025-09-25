package com.natsu.services.user;

import com.natsu.common.springboot.BaseSpringBootApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * User Service Application
 * 
 * Manages user profiles and user-related data including:
 * - User profile management
 * - User preferences
 * - User statistics
 * - User avatar and customization
 */
@SpringBootApplication
public class UserServiceApplication extends BaseSpringBootApplication {
    
    public static void main(String[] args) {
        runService(UserServiceApplication.class, args);
    }
}

