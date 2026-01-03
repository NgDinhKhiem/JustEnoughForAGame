package com.natsu.jefag.services.auth.exception;

import com.natsu.common.springboot.exception.GameException;
import org.springframework.http.HttpStatus;

/**
 * Exception thrown when a resource already exists.
 */
public class ResourceAlreadyExistsException extends GameException {
    
    public ResourceAlreadyExistsException(String resourceType, String field, String value) {
        super("ALREADY_EXISTS", 
              String.format("%s with %s '%s' already exists", resourceType, field, value), 
              HttpStatus.CONFLICT);
    }
    
    public static ResourceAlreadyExistsException username(String username) {
        return new ResourceAlreadyExistsException("User", "username", username);
    }
    
    public static ResourceAlreadyExistsException email(String email) {
        return new ResourceAlreadyExistsException("User", "email", email);
    }
    
    public static ResourceAlreadyExistsException roleName(String name) {
        return new ResourceAlreadyExistsException("Role", "name", name);
    }
}
