package com.natsu.jefag.security;

import com.nimbusds.jwt.JWTClaimsSet;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.security.KeyPair;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

public class JWTUtilityTest {
    private static PrivateKey privateKey;
    private static PublicKey publicKey;

    @BeforeAll
    static void setupKeys() throws Exception {
        KeyPair kp = JWTUtility.generateRSAKeyPair(2048);
        privateKey = kp.getPrivate();
        publicKey = kp.getPublic();
    }

    @Test
    void testCreateAndVerifyJWT() throws Exception {
        Map<String, Object> claims = Map.of("iss", "test-service", "sub", "user123", "role", "admin");

        String token = JWTUtility.createSignedJWT(claims, privateKey, 60, "kid123");
        assertNotNull(token);

        JWTClaimsSet parsed = JWTUtility.verifySignedJWT(token, publicKey);
        assertEquals("test-service", parsed.getIssuer());
        assertEquals("user123", parsed.getSubject());
        assertEquals("admin", parsed.getStringClaim("role"));
    }

    @Test
    void testExpiredToken() throws Exception {
        String token = JWTUtility.createSignedJWT(Map.of("sub", "expiredUser"), privateKey, 1, null);
        Thread.sleep(1500); // wait until expired

        assertThrows(Exception.class, () -> JWTUtility.verifySignedJWT(token, publicKey));
    }

    @Test
    void testInvalidSignature() throws Exception {
        // Generate different key pair
        KeyPair otherPair = JWTUtility.generateRSAKeyPair(2048);
        String token = JWTUtility.createSignedJWT(Map.of("sub", "userX"), otherPair.getPrivate(), 60, null);

        assertThrows(Exception.class, () -> JWTUtility.verifySignedJWT(token, publicKey));
    }

    @Test
    void testClaimsToMap() throws Exception {
        String token = JWTUtility.createSignedJWT(Map.of("sub", "mapUser", "custom", "xyz"), privateKey, 60, null);
        JWTClaimsSet claimsSet = JWTUtility.verifySignedJWT(token, publicKey);
        Map<String, Object> claimsMap = JWTUtility.claimsToMap(claimsSet);

        assertTrue(claimsMap.containsKey("sub"));
        assertEquals("xyz", claimsMap.get("custom"));
    }

    @Test
    void testJwtWithoutExpiration() throws Exception {
        String token = JWTUtility.createSignedJWT(Map.of("sub", "noexp"), privateKey, 0, null);
        JWTClaimsSet claimsSet = JWTUtility.verifySignedJWT(token, publicKey);
        assertEquals("noexp", claimsSet.getSubject());
    }
}
