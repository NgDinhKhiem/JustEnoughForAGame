package com.natsu.common.springboot.config;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
import org.springframework.web.cors.CorsConfigurationSource;

/**
 * Common security configuration for all services.
 * Provides basic security setup with JWT support and CORS.
 */
@Configuration
@EnableWebSecurity
public class CommonSecurityConfig {
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http, @Qualifier("corsConfigurationSource") CorsConfigurationSource corsConfigurationSource) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(authz -> authz
                .requestMatchers(AntPathRequestMatcher.antMatcher("/actuator/**")).permitAll()
                .requestMatchers(AntPathRequestMatcher.antMatcher("/health/**")).permitAll()
                .requestMatchers(AntPathRequestMatcher.antMatcher("/public/**")).permitAll()
                .anyRequest().authenticated()
            );
        
        return http.build();
    }
}
