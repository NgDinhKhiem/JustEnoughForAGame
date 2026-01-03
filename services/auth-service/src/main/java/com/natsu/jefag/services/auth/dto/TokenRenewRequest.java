package com.natsu.jefag.services.auth.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for token renewal.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TokenRenewRequest {
    
    @NotBlank(message = "Refresh token is required")
    private String refreshToken;
}
