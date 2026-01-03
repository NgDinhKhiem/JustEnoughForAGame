package com.natsu.jefag.services.auth.controller;

import com.natsu.jefag.services.auth.dto.*;
import com.natsu.jefag.services.auth.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * REST controller for authentication endpoints.
 * 
 * Endpoints:
 * - POST /api/auth/login - User login
 * - POST /api/auth/register - User registration
 * - POST /api/auth/refresh - Token renewal
 * - POST /api/auth/logout - User logout
 * - GET /api/auth/public-key - Get JWT public key
 */
@Slf4j
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {
    
    private final AuthService authService;
    
    /**
     * Authenticate user and return access/refresh tokens.
     */
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<TokenResponse>> login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest) {
        
        String userAgent = httpRequest.getHeader("User-Agent");
        String ipAddress = getClientIpAddress(httpRequest);
        
        log.info("Login attempt for user: {}", request.getUsername());
        TokenResponse tokenResponse = authService.login(request, userAgent, ipAddress);
        
        return ResponseEntity.ok(ApiResponse.success("Login successful", tokenResponse));
    }
    
    /**
     * Register a new user.
     */
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<UserDTO>> register(
            @Valid @RequestBody RegisterRequest request) {
        
        log.info("Registration attempt for username: {}", request.getUsername());
        UserDTO user = authService.register(request);
        
        return ResponseEntity.ok(ApiResponse.success("Registration successful", user));
    }
    
    /**
     * Renew access token using refresh token.
     */
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<TokenResponse>> refreshToken(
            @Valid @RequestBody TokenRenewRequest request,
            HttpServletRequest httpRequest) {
        
        String userAgent = httpRequest.getHeader("User-Agent");
        String ipAddress = getClientIpAddress(httpRequest);
        
        log.info("Token refresh attempt");
        TokenResponse tokenResponse = authService.renewToken(request, userAgent, ipAddress);
        
        return ResponseEntity.ok(ApiResponse.success("Token refreshed", tokenResponse));
    }
    
    /**
     * Logout user (revoke refresh token).
     */
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(
            @RequestBody TokenRenewRequest request) {
        
        log.info("Logout attempt");
        authService.logout(request.getRefreshToken());
        
        return ResponseEntity.ok(ApiResponse.success("Logout successful", null));
    }
    
    /**
     * Get public key for JWT verification.
     * This endpoint is public and can be used by other services.
     */
    @GetMapping("/public-key")
    public ResponseEntity<ApiResponse<String>> getPublicKey() {
        String publicKey = authService.getPublicKey();
        return ResponseEntity.ok(ApiResponse.success(publicKey));
    }
    
    private String getClientIpAddress(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty()) {
            return xRealIp;
        }
        return request.getRemoteAddr();
    }
}
