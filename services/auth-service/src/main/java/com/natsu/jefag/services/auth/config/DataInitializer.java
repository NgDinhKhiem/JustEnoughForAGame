package com.natsu.jefag.services.auth.config;

import com.natsu.jefag.services.auth.entity.Role;
import com.natsu.jefag.services.auth.entity.User;
import com.natsu.jefag.services.auth.repository.RoleRepository;
import com.natsu.jefag.services.auth.repository.UserRepository;
import com.natsu.jefag.security.PasswordUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

import java.util.Base64;
import java.util.Set;

/**
 * Data initializer for setting up default roles and admin user.
 */
@Slf4j
@Configuration
@RequiredArgsConstructor
public class DataInitializer {
    
    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    
    @Bean
    @Profile("!test")
    public CommandLineRunner initializeData() {
        return args -> {
            initializeRoles();
            initializeAdminUser();
        };
    }
    
    private void initializeRoles() {
        // Create USER role
        if (!roleRepository.existsByName("USER")) {
            Role userRole = Role.builder()
                    .name("USER")
                    .description("Default user role")
                    .permissions(Set.of(
                            "PROFILE_READ",
                            "PROFILE_UPDATE"
                    ))
                    .build();
            roleRepository.save(userRole);
            log.info("Created USER role");
        }
        
        // Create MODERATOR role
        if (!roleRepository.existsByName("MODERATOR")) {
            Role moderatorRole = Role.builder()
                    .name("MODERATOR")
                    .description("Moderator role with user management capabilities")
                    .permissions(Set.of(
                            "PROFILE_READ",
                            "PROFILE_UPDATE",
                            "USER_READ",
                            "USER_UPDATE"
                    ))
                    .build();
            roleRepository.save(moderatorRole);
            log.info("Created MODERATOR role");
        }
        
        // Create ADMIN role
        if (!roleRepository.existsByName("ADMIN")) {
            Role adminRole = Role.builder()
                    .name("ADMIN")
                    .description("Administrator role with full access")
                    .permissions(Set.of(
                            "PROFILE_READ",
                            "PROFILE_UPDATE",
                            "USER_READ",
                            "USER_CREATE",
                            "USER_UPDATE",
                            "USER_DELETE",
                            "USER_MANAGE_ROLES",
                            "ROLE_READ",
                            "ROLE_CREATE",
                            "ROLE_UPDATE",
                            "ROLE_DELETE",
                            "ROLE_MANAGE_PERMISSIONS"
                    ))
                    .build();
            roleRepository.save(adminRole);
            log.info("Created ADMIN role");
        }
    }
    
    private void initializeAdminUser() {
        if (!userRepository.existsByUsername("admin")) {
            try {
                byte[] salt = PasswordUtil.generateSalt();
                String passwordHash = PasswordUtil.hashPassword("admin123".toCharArray(), salt);
                
                Role adminRole = roleRepository.findByName("ADMIN")
                        .orElseThrow(() -> new RuntimeException("ADMIN role not found"));
                
                User admin = User.builder()
                        .username("admin")
                        .email("admin@example.com")
                        .displayName("Administrator")
                        .passwordHash(passwordHash)
                        .passwordSalt(Base64.getEncoder().encodeToString(salt))
                        .enabled(true)
                        .accountNonLocked(true)
                        .roles(Set.of(adminRole))
                        .build();
                
                userRepository.save(admin);
                log.info("Created admin user (username: admin, password: admin123)");
                log.warn("IMPORTANT: Change the admin password in production!");
            } catch (Exception e) {
                log.error("Failed to create admin user", e);
            }
        }
    }
}
