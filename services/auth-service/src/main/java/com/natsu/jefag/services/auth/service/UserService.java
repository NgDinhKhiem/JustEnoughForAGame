package com.natsu.jefag.services.auth.service;

import com.natsu.jefag.security.PasswordUtil;
import com.natsu.jefag.services.auth.dto.*;
import com.natsu.jefag.services.auth.entity.Role;
import com.natsu.jefag.services.auth.entity.User;
import com.natsu.jefag.services.auth.exception.ResourceAlreadyExistsException;
import com.natsu.jefag.services.auth.exception.ResourceNotFoundException;
import com.natsu.jefag.services.auth.repository.RoleRepository;
import com.natsu.jefag.services.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.NoSuchAlgorithmException;
import java.security.spec.InvalidKeySpecException;
import java.util.Base64;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Service for user management operations.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {
    
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    
    /**
     * Get all users with pagination.
     */
    @Transactional(readOnly = true)
    public Page<UserDTO> getAllUsers(Pageable pageable) {
        return userRepository.findAll(pageable).map(this::mapToUserDTO);
    }
    
    /**
     * Search users by username, email, or display name.
     */
    @Transactional(readOnly = true)
    public Page<UserDTO> searchUsers(String search, Pageable pageable) {
        return userRepository.searchUsers(search, pageable).map(this::mapToUserDTO);
    }
    
    /**
     * Get user by ID.
     */
    @Transactional(readOnly = true)
    public UserDTO getUserById(UUID id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.user(id.toString()));
        return mapToUserDTO(user);
    }
    
    /**
     * Get user by username.
     */
    @Transactional(readOnly = true)
    public UserDTO getUserByUsername(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> ResourceNotFoundException.user(username));
        return mapToUserDTO(user);
    }
    
    /**
     * Create a new user (admin operation).
     */
    @Transactional
    public UserDTO createUser(CreateUserRequest request) {
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
                .enabled(request.isEnabled())
                .accountNonLocked(true)
                .build();
        
        // Assign roles
        if (request.getRoles() != null && !request.getRoles().isEmpty()) {
            Set<Role> roles = roleRepository.findByNameIn(request.getRoles());
            user.setRoles(roles);
        } else {
            // Assign default role
            roleRepository.findByName("USER").ifPresent(user::addRole);
        }
        
        User savedUser = userRepository.save(user);
        log.info("User created by admin: {}", savedUser.getUsername());
        
        return mapToUserDTO(savedUser);
    }
    
    /**
     * Update an existing user.
     */
    @Transactional
    public UserDTO updateUser(UUID id, UpdateUserRequest request) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.user(id.toString()));
        
        // Update email if provided
        if (request.getEmail() != null && !request.getEmail().equals(user.getEmail())) {
            if (userRepository.existsByEmail(request.getEmail())) {
                throw ResourceAlreadyExistsException.email(request.getEmail());
            }
            user.setEmail(request.getEmail());
        }
        
        // Update password if provided
        if (request.getPassword() != null) {
            byte[] salt = PasswordUtil.generateSalt();
            String passwordHash = hashPassword(request.getPassword(), salt);
            user.setPasswordHash(passwordHash);
            user.setPasswordSalt(Base64.getEncoder().encodeToString(salt));
        }
        
        // Update display name if provided
        if (request.getDisplayName() != null) {
            user.setDisplayName(request.getDisplayName());
        }
        
        // Update enabled status if provided
        if (request.getEnabled() != null) {
            user.setEnabled(request.getEnabled());
        }
        
        // Update account lock status if provided
        if (request.getAccountNonLocked() != null) {
            user.setAccountNonLocked(request.getAccountNonLocked());
            if (request.getAccountNonLocked()) {
                user.setFailedLoginAttempts(0);
                user.setLockoutEndTime(null);
            }
        }
        
        // Update roles if provided
        if (request.getRoles() != null) {
            Set<Role> roles = roleRepository.findByNameIn(request.getRoles());
            user.setRoles(roles);
        }
        
        User savedUser = userRepository.save(user);
        log.info("User updated: {}", savedUser.getUsername());
        
        return mapToUserDTO(savedUser);
    }
    
    /**
     * Delete a user.
     */
    @Transactional
    public void deleteUser(UUID id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.user(id.toString()));
        userRepository.delete(user);
        log.info("User deleted: {}", user.getUsername());
    }
    
    /**
     * Assign roles to a user.
     */
    @Transactional
    public UserDTO assignRoles(UUID userId, Set<String> roleNames) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ResourceNotFoundException.user(userId.toString()));
        
        Set<Role> roles = roleRepository.findByNameIn(roleNames);
        user.getRoles().addAll(roles);
        
        User savedUser = userRepository.save(user);
        log.info("Roles assigned to user {}: {}", user.getUsername(), roleNames);
        
        return mapToUserDTO(savedUser);
    }
    
    /**
     * Remove roles from a user.
     */
    @Transactional
    public UserDTO removeRoles(UUID userId, Set<String> roleNames) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> ResourceNotFoundException.user(userId.toString()));
        
        user.getRoles().removeIf(role -> roleNames.contains(role.getName()));
        
        User savedUser = userRepository.save(user);
        log.info("Roles removed from user {}: {}", user.getUsername(), roleNames);
        
        return mapToUserDTO(savedUser);
    }
    
    private String hashPassword(String password, byte[] salt) {
        try {
            return PasswordUtil.hashPassword(password.toCharArray(), salt);
        } catch (NoSuchAlgorithmException | InvalidKeySpecException e) {
            log.error("Failed to hash password", e);
            throw new RuntimeException("Failed to hash password", e);
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
