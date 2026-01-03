package com.natsu.jefag.services.auth.repository;

import com.natsu.jefag.services.auth.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * Repository for Role entity.
 */
@Repository
public interface RoleRepository extends JpaRepository<Role, UUID> {
    
    Optional<Role> findByName(String name);
    
    Set<Role> findByNameIn(Set<String> names);
    
    boolean existsByName(String name);
}
