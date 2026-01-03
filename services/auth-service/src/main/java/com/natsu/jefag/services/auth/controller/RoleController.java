package com.natsu.jefag.services.auth.controller;

import com.natsu.jefag.services.auth.dto.*;
import com.natsu.jefag.services.auth.service.RoleService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * REST controller for role management endpoints.
 * 
 * Endpoints:
 * - GET /api/roles - Get all roles (paginated)
 * - GET /api/roles/all - Get all roles (no pagination)
 * - GET /api/roles/{id} - Get role by ID
 * - GET /api/roles/name/{name} - Get role by name
 * - POST /api/roles - Create a new role
 * - PUT /api/roles/{id} - Update a role
 * - DELETE /api/roles/{id} - Delete a role
 * - POST /api/roles/{id}/permissions - Add permissions to role
 * - DELETE /api/roles/{id}/permissions - Remove permissions from role
 */
@Slf4j
@RestController
@RequestMapping("/api/roles")
@RequiredArgsConstructor
public class RoleController {
    
    private final RoleService roleService;
    
    /**
     * Get all roles with pagination.
     */
    @GetMapping
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_READ')")
    public ResponseEntity<ApiResponse<Page<RoleDTO>>> getAllRoles(
            @PageableDefault(size = 20, sort = "name") Pageable pageable) {
        
        Page<RoleDTO> roles = roleService.getAllRoles(pageable);
        return ResponseEntity.ok(ApiResponse.success(roles));
    }
    
    /**
     * Get all roles without pagination.
     */
    @GetMapping("/all")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_READ')")
    public ResponseEntity<ApiResponse<List<RoleDTO>>> getAllRolesNoPagination() {
        List<RoleDTO> roles = roleService.getAllRoles();
        return ResponseEntity.ok(ApiResponse.success(roles));
    }
    
    /**
     * Get role by ID.
     */
    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_READ')")
    public ResponseEntity<ApiResponse<RoleDTO>> getRoleById(@PathVariable UUID id) {
        RoleDTO role = roleService.getRoleById(id);
        return ResponseEntity.ok(ApiResponse.success(role));
    }
    
    /**
     * Get role by name.
     */
    @GetMapping("/name/{name}")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_READ')")
    public ResponseEntity<ApiResponse<RoleDTO>> getRoleByName(@PathVariable String name) {
        RoleDTO role = roleService.getRoleByName(name);
        return ResponseEntity.ok(ApiResponse.success(role));
    }
    
    /**
     * Create a new role.
     */
    @PostMapping
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_CREATE')")
    public ResponseEntity<ApiResponse<RoleDTO>> createRole(
            @Valid @RequestBody CreateRoleRequest request) {
        
        log.info("Creating role: {}", request.getName());
        RoleDTO role = roleService.createRole(request);
        
        return ResponseEntity.ok(ApiResponse.success("Role created successfully", role));
    }
    
    /**
     * Update a role.
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_UPDATE')")
    public ResponseEntity<ApiResponse<RoleDTO>> updateRole(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateRoleRequest request) {
        
        log.info("Updating role: {}", id);
        RoleDTO role = roleService.updateRole(id, request);
        
        return ResponseEntity.ok(ApiResponse.success("Role updated successfully", role));
    }
    
    /**
     * Delete a role.
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_DELETE')")
    public ResponseEntity<ApiResponse<Void>> deleteRole(@PathVariable UUID id) {
        log.info("Deleting role: {}", id);
        roleService.deleteRole(id);
        
        return ResponseEntity.ok(ApiResponse.success("Role deleted successfully", null));
    }
    
    /**
     * Add permissions to a role.
     */
    @PostMapping("/{id}/permissions")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_MANAGE_PERMISSIONS')")
    public ResponseEntity<ApiResponse<RoleDTO>> addPermissions(
            @PathVariable UUID id,
            @RequestBody Set<String> permissions) {
        
        log.info("Adding permissions to role {}: {}", id, permissions);
        RoleDTO role = roleService.addPermissions(id, permissions);
        
        return ResponseEntity.ok(ApiResponse.success("Permissions added successfully", role));
    }
    
    /**
     * Remove permissions from a role.
     */
    @DeleteMapping("/{id}/permissions")
    @PreAuthorize("hasRole('ADMIN') or hasAuthority('ROLE_MANAGE_PERMISSIONS')")
    public ResponseEntity<ApiResponse<RoleDTO>> removePermissions(
            @PathVariable UUID id,
            @RequestBody Set<String> permissions) {
        
        log.info("Removing permissions from role {}: {}", id, permissions);
        RoleDTO role = roleService.removePermissions(id, permissions);
        
        return ResponseEntity.ok(ApiResponse.success("Permissions removed successfully", role));
    }
}
