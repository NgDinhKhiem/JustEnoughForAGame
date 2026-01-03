package com.natsu.jefag.services.auth.exception;

import com.natsu.common.springboot.exception.GameException;
import org.springframework.http.HttpStatus;

/**
 * Exception thrown when a resource is not found.
 */
public class ResourceNotFoundException extends GameException {
    
    public ResourceNotFoundException(String resourceType, String identifier) {
        super("NOT_FOUND", String.format("%s not found: %s", resourceType, identifier), HttpStatus.NOT_FOUND);
    }
    
    public static ResourceNotFoundException user(String identifier) {
        return new ResourceNotFoundException("User", identifier);
    }
    
    public static ResourceNotFoundException role(String identifier) {
        return new ResourceNotFoundException("Role", identifier);
    }
}
