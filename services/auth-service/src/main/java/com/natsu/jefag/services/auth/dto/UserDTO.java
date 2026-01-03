package com.natsu.jefag.services.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.Set;
import java.util.UUID;

/**
 * Data Transfer Object for User entity.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserDTO {
    
    private UUID id;
    private String username;
    private String email;
    private String displayName;
    private boolean enabled;
    private boolean accountNonLocked;
    private Set<String> roles;
    private Instant createdAt;
    private Instant updatedAt;
    private Instant lastLoginAt;
}
