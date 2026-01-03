package com.natsu.jefag.services.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.Set;
import java.util.UUID;

/**
 * Data Transfer Object for Role entity.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RoleDTO {
    
    private UUID id;
    private String name;
    private String description;
    private Set<String> permissions;
    private Instant createdAt;
    private Instant updatedAt;
}
