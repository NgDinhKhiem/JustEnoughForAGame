package com.natsu.common.springboot.annotation;

import org.springframework.core.annotation.AliasFor;
import org.springframework.stereotype.Service;

import java.lang.annotation.*;

/**
 * Custom annotation for game services.
 * Combines @Service with additional metadata for game-specific services.
 */
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Service
public @interface GameService {
    
    /**
     * The value may indicate a suggestion for a logical component name,
     * to be turned into a Spring bean in case of an autodetected component.
     */
    @AliasFor(annotation = Service.class)
    String value() default "";
    
    /**
     * Service category for monitoring and metrics
     */
    String category() default "game";
    
    /**
     * Whether this service requires authentication
     */
    boolean requiresAuth() default true;
}

