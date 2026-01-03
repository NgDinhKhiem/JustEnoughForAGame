package com.natsu.jefag.services.auth.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.annotation.Transactional;

import com.natsu.jefag.services.auth.repository.RefreshTokenRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.time.Instant;

/**
 * Scheduled tasks for the Auth Service.
 */
@Slf4j
@Configuration
@EnableScheduling
@RequiredArgsConstructor
public class ScheduledTasks {
    
    private final RefreshTokenRepository refreshTokenRepository;
    
    /**
     * Clean up expired and revoked refresh tokens every hour.
     */
    @Scheduled(fixedRate = 3600000) // Run every hour
    @Transactional
    public void cleanupExpiredTokens() {
        log.info("Starting cleanup of expired and revoked refresh tokens");
        refreshTokenRepository.deleteExpiredAndRevoked(Instant.now());
        log.info("Finished cleanup of expired and revoked refresh tokens");
    }
}
