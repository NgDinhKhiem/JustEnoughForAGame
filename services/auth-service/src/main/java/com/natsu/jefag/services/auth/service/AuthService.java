package com.natsu.jefag.services.auth.service;

import com.natsu.jefag.services.auth.dto.*;
import com.natsu.jefag.services.auth.entity.RefreshToken;
import com.natsu.jefag.services.auth.entity.Role;
import com.natsu.jefag.services.auth.entity.User;
import com.natsu.jefag.services.auth.exception.AuthenticationException;
import com.natsu.jefag.services.auth.exception.ResourceAlreadyExistsException;
import com.natsu.jefag.services.auth.exception.ResourceNotFoundException;
import com.natsu.jefag.services.auth.repository.RefreshTokenRepository;
import com.natsu.jefag.services.auth.repository.RoleRepository;
import com.natsu.jefag.services.auth.repository.UserRepository;
import com.natsu.jefag.security.JWTUtility;
import com.natsu.jefag.security.PasswordUtil;
import com.nimbusds.jose.JOSEException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.GeneralSecurityException;
import java.security.KeyPair;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.spec.InvalidKeySpecException;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Service for authentication operations.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {
    
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    
    @Value("${auth.jwt.access-token-ttl:3600}")
    private long accessTokenTtl;
    
    @Value("${auth.jwt.refresh-token-ttl:604800}")
    private long refreshTokenTtl;
    
    @Value("${auth.jwt.key-id:auth-key}")
    private String keyId;
    
    @Value("${auth.lockout.max-attempts:5}")
    private int maxLoginAttempts;
    
    @Value("${auth.lockout.duration-minutes:30}")
    private long lockoutDurationMinutes;
    
    // In production, load from secure key storage
    private KeyPair keyPair;
    
    @jakarta.annotation.PostConstruct
    public void init() throws NoSuchAlgorithmException {
        // Generate RSA key pair for JWT signing (in production, load from secure storage)
        this.keyPair = JWTUtility.generateRSAKeyPair(2048);
        log.info("JWT key pair initialized");
    }
    
    /**
     * Authenticate user and generate tokens.
     */
    @Transactional
    public TokenResponse login(LoginRequest request, String userAgent, String ipAddress) {
        User user = userRepository.findByUsernameOrEmail(request.getUsername(), request.getUsername())
                .orElseThrow(AuthenticationException::invalidCredentials);
        
        // Check if account is locked
        if (!user.isAccountNonLocked()) {
            if (user.isLockoutExpired()) {
                // Unlock the account
                user.setAccountNonLocked(true);
                user.setFailedLoginAttempts(0);
                user.setLockoutEndTime(null);
            } else {
                throw AuthenticationException.accountLocked();
            }
        }
        
        // Check if account is enabled
        if (!user.isEnabled()) {
            throw AuthenticationException.accountDisabled();
        }
        
        // Verify password
        if (!verifyPassword(request.getPassword(), user.getPasswordHash(), user.getPasswordSalt())) {
            user.recordFailedLogin(maxLoginAttempts, lockoutDurationMinutes);
            userRepository.save(user);
            throw AuthenticationException.invalidCredentials();
        }
        
        // Successful login
        user.recordSuccessfulLogin();
        userRepository.save(user);
        
        return generateTokens(user, userAgent, ipAddress);
    }
    
    /**
     * Register a new user.
     */
    @Transactional
    public UserDTO register(RegisterRequest request) {
        // Check for existing username
        if (userRepository.existsByUsername(request.getUsername())) {
            throw ResourceAlreadyExistsException.username(request.getUsername());
        }
        
        // Check for existing email
        if (userRepository.existsByEmail(request.getEmail())) {
            throw ResourceAlreadyExistsException.email(request.getEmail());
        }
        
        // Hash password
        byte[] salt = PasswordUtil.generateSalt();
        String passwordHash = hashPassword(request.getPassword(), salt);
        
        // Create user
        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .displayName(request.getDisplayName() != null ? request.getDisplayName() : request.getUsername())
                .passwordHash(passwordHash)
                .passwordSalt(Base64.getEncoder().encodeToString(salt))
                .enabled(true)
                .accountNonLocked(true)
                .build();
        
        // Assign default role
        roleRepository.findByName("USER")
                .ifPresent(user::addRole);
        
        User savedUser = userRepository.save(user);
        log.info("New user registered: {}", savedUser.getUsername());
        
        return mapToUserDTO(savedUser);
    }
    
    /**
     * Renew access token using refresh token.
     */
    @Transactional
    public TokenResponse renewToken(TokenRenewRequest request, String userAgent, String ipAddress) {
        RefreshToken refreshToken = refreshTokenRepository.findByToken(request.getRefreshToken())
                .orElseThrow(AuthenticationException::invalidToken);
        
        if (refreshToken.isRevoked()) {
            throw AuthenticationException.tokenRevoked();
        }
        
        if (refreshToken.isExpired()) {
            throw AuthenticationException.tokenExpired();
        }
        
        User user = refreshToken.getUser();
        
        // Check if account is still valid
        if (!user.isEnabled()) {
            throw AuthenticationException.accountDisabled();
        }
        
        if (!user.isAccountNonLocked()) {
            throw AuthenticationException.accountLocked();
        }
        
        // Revoke old refresh token
        refreshToken.revoke();
        refreshTokenRepository.save(refreshToken);
        
        // Generate new tokens
        return generateTokens(user, userAgent, ipAddress);
    }
    
    /**
     * Logout user by revoking all refresh tokens.
     */
    @Transactional
    public void logout(String refreshToken) {
        refreshTokenRepository.findByToken(refreshToken)
                .ifPresent(token -> {
                    token.revoke();
                    refreshTokenRepository.save(token);
                });
    }
    
    /**
     * Logout from all devices.
     */
    @Transactional
    public void logoutAll(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ResourceNotFoundException.user(userId.toString()));
        refreshTokenRepository.revokeAllByUser(user);
    }
    
    /**
     * Get public key for token verification.
     */
    public String getPublicKey() {
        byte[] encoded = keyPair.getPublic().getEncoded();
        return Base64.getEncoder().encodeToString(encoded);
    }
    
    private TokenResponse generateTokens(User user, String userAgent, String ipAddress) {
        try {
            // Generate access token
            Map<String, Object> claims = buildClaims(user);
            String accessToken = JWTUtility.createSignedJWT(
                    claims, keyPair.getPrivate(), accessTokenTtl, keyId);
            
            // Generate refresh token
            String refreshTokenValue = UUID.randomUUID().toString();
            RefreshToken refreshToken = RefreshToken.builder()
                    .token(refreshTokenValue)
                    .user(user)
                    .expiresAt(Instant.now().plusSeconds(refreshTokenTtl))
                    .userAgent(userAgent)
                    .ipAddress(ipAddress)
                    .build();
            refreshTokenRepository.save(refreshToken);
            
            return TokenResponse.of(accessToken, refreshTokenValue, accessTokenTtl);
        } catch (JOSEException e) {
            log.error("Failed to generate JWT", e);
            throw new RuntimeException("Failed to generate token", e);
        }
    }
    
    private Map<String, Object> buildClaims(User user) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("sub", user.getId().toString());
        claims.put("username", user.getUsername());
        claims.put("email", user.getEmail());
        claims.put("roles", user.getRoles().stream()
                .map(Role::getName)
                .collect(Collectors.toList()));
        claims.put("permissions", user.getRoles().stream()
                .flatMap(r -> r.getPermissions().stream())
                .distinct()
                .collect(Collectors.toList()));
        return claims;
    }
    
    private String hashPassword(String password, byte[] salt) {
        try {
            return PasswordUtil.hashPassword(password.toCharArray(), salt);
        } catch (NoSuchAlgorithmException | InvalidKeySpecException e) {
            log.error("Failed to hash password", e);
            throw new RuntimeException("Failed to hash password", e);
        }
    }
    
    private boolean verifyPassword(String password, String storedHash, String storedSalt) {
        try {
            byte[] salt = Base64.getDecoder().decode(storedSalt);
            String hash = PasswordUtil.hashPassword(password.toCharArray(), salt);
            return hash.equals(storedHash);
        } catch (Exception e) {
            log.error("Failed to verify password", e);
            return false;
        }
    }
    
    private UserDTO mapToUserDTO(User user) {
        return UserDTO.builder()
                .id(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .displayName(user.getDisplayName())
                .enabled(user.isEnabled())
                .accountNonLocked(user.isAccountNonLocked())
                .roles(user.getRoles().stream()
                        .map(Role::getName)
                        .collect(Collectors.toSet()))
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .lastLoginAt(user.getLastLoginAt())
                .build();
    }
}
