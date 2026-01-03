package com.natsu.jefag.services.auth.controller;

import com.natsu.jefag.services.auth.dto.*;
import com.natsu.jefag.services.auth.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Set;
import java.util.UUID;

/**
 * REST controller for user management endpoints.
 * 
 * Endpoints:
 * - GET /api/users - Get all users (paginated)
 * - GET /api/users/search - Search users
 * - GET /api/users/{id} - Get user by ID
 * - GET /api/users/username/{username} - Get user by username
 * - POST /api/users - Create a new user
 * - PUT /api/users/{id} - Update a user
 * - DELETE /api/users/{id} - Delete a user
 * - POST /api/users/{id}/roles - Assign roles to user
 * - DELETE /api/users/{id}/roles - Remove roles from user
 */
@Slf4j
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {
    
    private final UserService userService;
    
    /**
     * Get all users with pagination.
     */
    @GetMapping
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_READ')")
    public ResponseEntity<ApiResponse<Page<UserDTO>>> getAllUsers(
            @PageableDefault(size = 20, sort = "username") Pageable pageable) {
        
        Page<UserDTO> users = userService.getAllUsers(pageable);
        return ResponseEntity.ok(ApiResponse.success(users));
    }
    
    /**
     * Search users by username, email, or display name.
     */
    @GetMapping("/search")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_READ')")
    public ResponseEntity<ApiResponse<Page<UserDTO>>> searchUsers(
            @RequestParam String q,
            @PageableDefault(size = 20) Pageable pageable) {
        
        Page<UserDTO> users = userService.searchUsers(q, pageable);
        return ResponseEntity.ok(ApiResponse.success(users));
    }
    
    /**
     * Get user by ID.
     */
    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_READ') or #id == authentication.principal.id")
    public ResponseEntity<ApiResponse<UserDTO>> getUserById(@PathVariable UUID id) {
        UserDTO user = userService.getUserById(id);
        return ResponseEntity.ok(ApiResponse.success(user));
    }
    
    /**
     * Get user by username.
     */
    @GetMapping("/username/{username}")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_READ') or #username == authentication.principal.username")
    public ResponseEntity<ApiResponse<UserDTO>> getUserByUsername(@PathVariable String username) {
        UserDTO user = userService.getUserByUsername(username);
        return ResponseEntity.ok(ApiResponse.success(user));
    }
    
    /**
     * Create a new user (admin operation).
     */
    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_CREATE')")
    public ResponseEntity<ApiResponse<UserDTO>> createUser(
            @Valid @RequestBody CreateUserRequest request) {
        
        log.info("Creating user: {}", request.getUsername());
        UserDTO user = userService.createUser(request);
        
        return ResponseEntity.ok(ApiResponse.success("User created successfully", user));
    }
    
    /**
     * Update a user.
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_UPDATE') or #id == authentication.principal.id")
    public ResponseEntity<ApiResponse<UserDTO>> updateUser(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateUserRequest request) {
        
        log.info("Updating user: {}", id);
        UserDTO user = userService.updateUser(id, request);
        
        return ResponseEntity.ok(ApiResponse.success("User updated successfully", user));
    }
    
    /**
     * Delete a user.
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_DELETE')")
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable UUID id) {
        log.info("Deleting user: {}", id);
        userService.deleteUser(id);
        
        return ResponseEntity.ok(ApiResponse.success("User deleted successfully", null));
    }
    
    /**
     * Assign roles to a user.
     */
    @PostMapping("/{id}/roles")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_MANAGE_ROLES')")
    public ResponseEntity<ApiResponse<UserDTO>> assignRoles(
            @PathVariable UUID id,
            @RequestBody Set<String> roles) {
        
        log.info("Assigning roles to user {}: {}", id, roles);
        UserDTO user = userService.assignRoles(id, roles);
        
        return ResponseEntity.ok(ApiResponse.success("Roles assigned successfully", user));
    }
    
    /**
     * Remove roles from a user.
     */
    @DeleteMapping("/{id}/roles")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('USER_MANAGE_ROLES')")
    public ResponseEntity<ApiResponse<UserDTO>> removeRoles(
            @PathVariable UUID id,
            @RequestBody Set<String> roles) {
        
        log.info("Removing roles from user {}: {}", id, roles);
        UserDTO user = userService.removeRoles(id, roles);
        
        return ResponseEntity.ok(ApiResponse.success("Roles removed successfully", user));
    }
}
