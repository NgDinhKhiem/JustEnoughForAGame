package com.natsu.common.springboot.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

/**
 * Base exception class for all game-related exceptions
 */
@Getter
public class GameException extends RuntimeException {
    
    private final String errorCode;
    private final HttpStatus httpStatus;
    private final Object[] args;
    
    public GameException(String errorCode, String message) {
        this(errorCode, message, HttpStatus.BAD_REQUEST);
    }
    
    public GameException(String errorCode, String message, HttpStatus httpStatus) {
        this(errorCode, message, httpStatus, (Object[]) null);
    }
    
    public GameException(String errorCode, String message, HttpStatus httpStatus, Object... args) {
        super(message);
        this.errorCode = errorCode;
        this.httpStatus = httpStatus;
        this.args = args;
    }
    
    public GameException(String errorCode, String message, Throwable cause) {
        this(errorCode, message, HttpStatus.INTERNAL_SERVER_ERROR, cause);
    }
    
    public GameException(String errorCode, String message, HttpStatus httpStatus, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
        this.httpStatus = httpStatus;
        this.args = null;
    }
}

