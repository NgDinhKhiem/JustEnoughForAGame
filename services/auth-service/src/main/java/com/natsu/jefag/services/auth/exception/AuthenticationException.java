package com.natsu.jefag.services.auth.exception;

import com.natsu.common.springboot.exception.GameException;
import org.springframework.http.HttpStatus;

/**
 * Exception thrown when authentication fails.
 */
public class AuthenticationException extends GameException {
    
    public AuthenticationException(String message) {
        super("AUTH_FAILED", message, HttpStatus.UNAUTHORIZED);
    }
    
    public AuthenticationException(String errorCode, String message) {
        super(errorCode, message, HttpStatus.UNAUTHORIZED);
    }
    
    public static AuthenticationException invalidCredentials() {
        return new AuthenticationException("INVALID_CREDENTIALS", "Invalid username or password");
    }
    
    public static AuthenticationException accountLocked() {
        return new AuthenticationException("ACCOUNT_LOCKED", "Account is locked due to too many failed login attempts");
    }
    
    public static AuthenticationException accountDisabled() {
        return new AuthenticationException("ACCOUNT_DISABLED", "Account is disabled");
    }
    
    public static AuthenticationException invalidToken() {
        return new AuthenticationException("INVALID_TOKEN", "Invalid or expired token");
    }
    
    public static AuthenticationException tokenExpired() {
        return new AuthenticationException("TOKEN_EXPIRED", "Token has expired");
    }
    
    public static AuthenticationException tokenRevoked() {
        return new AuthenticationException("TOKEN_REVOKED", "Token has been revoked");
    }
}
