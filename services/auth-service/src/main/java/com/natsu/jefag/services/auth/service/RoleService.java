package com.natsu.jefag.services.auth.service;

import com.natsu.jefag.services.auth.dto.*;
import com.natsu.jefag.services.auth.entity.Role;
import com.natsu.jefag.services.auth.exception.ResourceAlreadyExistsException;
import com.natsu.jefag.services.auth.exception.ResourceNotFoundException;
import com.natsu.jefag.services.auth.repository.RoleRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Service for role management operations.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoleService {
    
    private final RoleRepository roleRepository;
    
    /**
     * Get all roles with pagination.
     */
    @Transactional(readOnly = true)
    public Page<RoleDTO> getAllRoles(Pageable pageable) {
        return roleRepository.findAll(pageable).map(this::mapToRoleDTO);
    }
    
    /**
     * Get all roles (no pagination).
     */
    @Transactional(readOnly = true)
    public List<RoleDTO> getAllRoles() {
        return roleRepository.findAll().stream()
                .map(this::mapToRoleDTO)
                .collect(Collectors.toList());
    }
    
    /**
     * Get role by ID.
     */
    @Transactional(readOnly = true)
    public RoleDTO getRoleById(UUID id) {
        Role role = roleRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.role(id.toString()));
        return mapToRoleDTO(role);
    }
    
    /**
     * Get role by name.
     */
    @Transactional(readOnly = true)
    public RoleDTO getRoleByName(String name) {
        Role role = roleRepository.findByName(name)
                .orElseThrow(() -> ResourceNotFoundException.role(name));
        return mapToRoleDTO(role);
    }
    
    /**
     * Create a new role.
     */
    @Transactional
    public RoleDTO createRole(CreateRoleRequest request) {
        // Check for existing role name
        if (roleRepository.existsByName(request.getName())) {
            throw ResourceAlreadyExistsException.roleName(request.getName());
        }
        
        Role role = Role.builder()
                .name(request.getName())
                .description(request.getDescription())
                .permissions(request.getPermissions() != null ? request.getPermissions() : new HashSet<>())
                .build();
        
        Role savedRole = roleRepository.save(role);
        log.info("Role created: {}", savedRole.getName());
        
        return mapToRoleDTO(savedRole);
    }
    
    /**
     * Update an existing role.
     */
    @Transactional
    public RoleDTO updateRole(UUID id, UpdateRoleRequest request) {
        Role role = roleRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.role(id.toString()));
        
        // Update description if provided
        if (request.getDescription() != null) {
            role.setDescription(request.getDescription());
        }
        
        // Update permissions if provided
        if (request.getPermissions() != null) {
            role.setPermissions(request.getPermissions());
        }
        
        Role savedRole = roleRepository.save(role);
        log.info("Role updated: {}", savedRole.getName());
        
        return mapToRoleDTO(savedRole);
    }
    
    /**
     * Delete a role.
     */
    @Transactional
    public void deleteRole(UUID id) {
        Role role = roleRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.role(id.toString()));
        
        // Prevent deletion of system roles
        if (isSystemRole(role.getName())) {
            throw new IllegalArgumentException("Cannot delete system role: " + role.getName());
        }
        
        roleRepository.delete(role);
        log.info("Role deleted: {}", role.getName());
    }
    
    /**
     * Add permissions to a role.
     */
    @Transactional
    public RoleDTO addPermissions(UUID roleId, java.util.Set<String> permissions) {
        Role role = roleRepository.findById(roleId)
                .orElseThrow(() -> ResourceNotFoundException.role(roleId.toString()));
        
        role.getPermissions().addAll(permissions);
        
        Role savedRole = roleRepository.save(role);
        log.info("Permissions added to role {}: {}", role.getName(), permissions);
        
        return mapToRoleDTO(savedRole);
    }
    
    /**
     * Remove permissions from a role.
     */
    @Transactional
    public RoleDTO removePermissions(UUID roleId, java.util.Set<String> permissions) {
        Role role = roleRepository.findById(roleId)
                .orElseThrow(() -> ResourceNotFoundException.role(roleId.toString()));
        
        role.getPermissions().removeAll(permissions);
        
        Role savedRole = roleRepository.save(role);
        log.info("Permissions removed from role {}: {}", role.getName(), permissions);
        
        return mapToRoleDTO(savedRole);
    }
    
    private boolean isSystemRole(String roleName) {
        return "ADMIN".equals(roleName) || "USER".equals(roleName) || "MODERATOR".equals(roleName);
    }
    
    private RoleDTO mapToRoleDTO(Role role) {
        return RoleDTO.builder()
                .id(role.getId())
                .name(role.getName())
                .description(role.getDescription())
                .permissions(role.getPermissions())
                .createdAt(role.getCreatedAt())
                .updatedAt(role.getUpdatedAt())
                .build();
    }
}
