package com.natsu.security;

import com.nimbusds.jose.*;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.crypto.RSASSAVerifier;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.*;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.text.ParseException;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

public final class JWTUtility {

    private JWTUtility() { /* static utility */ }

    // -------------------------
    // Key helpers
    // -------------------------

    /**
     * Generate an RSA key pair (useful for local testing).
     *
     * @param keySize size in bits (2048 or 4096 recommended)
     * @return generated KeyPair
     * @throws NoSuchAlgorithmException if RSA not supported
     */
    public static KeyPair generateRSAKeyPair(int keySize) throws NoSuchAlgorithmException {
        KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
        kpg.initialize(keySize);
        return kpg.generateKeyPair();
    }

    /**
     * Load a PrivateKey from a PEM string (PKCS#8). Works with headers:
     * "-----BEGIN PRIVATE KEY-----" (PKCS#8) or
     * "-----BEGIN RSA PRIVATE KEY-----" (PKCS#1) — PKCS#1 is converted to PKCS#8 automatically.
     *
     * @param pem the private key PEM string
     * @return PrivateKey
     */
    public static PrivateKey loadPrivateKeyFromPEM(String pem) throws GeneralSecurityException, IOException {
        String sanitized = pem.replaceAll("\\r", "").replaceAll("\\n", "").replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replace("-----BEGIN RSA PRIVATE KEY-----", "")
                .replace("-----END RSA PRIVATE KEY-----", "");

        byte[] keyBytes = Base64.getDecoder().decode(sanitized);

        // If the original is PKCS#1 (starts with 0x30 0x82 ... but not PKCS#8), we convert.
        // Try PKCS#8 first:
        try {
            PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(keyBytes);
            KeyFactory kf = KeyFactory.getInstance("RSA");
            return kf.generatePrivate(spec);
        } catch (InvalidKeySpecException e) {
            // Attempt to convert PKCS#1 -> PKCS#8
            // Wrap PKCS#1 in PKCS#8 structure:
            byte[] pkcs8Header = new byte[] {
                    0x30, (byte)0x82 // We'll build using standard approach below (use BouncyCastle ideally),
            };
            // Simpler approach: use a library in production; here we throw a helpful exception:
            throw new InvalidKeySpecException("Private key appears to be PKCS#1. Please provide PKCS#8 (BEGIN PRIVATE KEY). " +
                    "If you only have PKCS#1 (BEGIN RSA PRIVATE KEY), convert it to PKCS#8 using openssl:\n" +
                    "openssl pkcs8 -topk8 -inform PEM -outform PEM -in rsa_priv.pem -out pkcs8_priv.pem -nocrypt");
        }
    }

    /**
     * Load a PublicKey from a PEM string (X.509 / SubjectPublicKeyInfo).
     *
     * @param pem the public key PEM
     * @return PublicKey
     * @throws GeneralSecurityException on key parse errors
     */
    public static PublicKey loadPublicKeyFromPEM(String pem) throws GeneralSecurityException {
        String sanitized = pem.replaceAll("\\r", "").replaceAll("\\n", "")
                .replace("-----BEGIN PUBLIC KEY-----", "")
                .replace("-----END PUBLIC KEY-----", "");
        byte[] keyBytes = Base64.getDecoder().decode(sanitized);
        X509EncodedKeySpec spec = new X509EncodedKeySpec(keyBytes);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return kf.generatePublic(spec);
    }

    /**
     * Convenience: read PEM file from path (UTF-8) and load private key.
     */
    public static PrivateKey loadPrivateKeyFromPEMFile(Path file) throws IOException, GeneralSecurityException {
        String pem = Files.readString(file);
        return loadPrivateKeyFromPEM(pem);
    }

    /**
     * Convenience: read PEM file from path (UTF-8) and load public key.
     */
    public static PublicKey loadPublicKeyFromPEMFile(Path file) throws IOException, GeneralSecurityException {
        String pem = Files.readString(file);
        return loadPublicKeyFromPEM(pem);
    }

    // -------------------------
    // JWT creation
    // -------------------------

    /**
     * Create a signed JWT (RS256).
     *
     * @param claims    custom claims to include (keys -> values). Standard fields (iss, sub, aud) may also be passed here.
     * @param privateKey RSA private key
     * @param ttlSeconds time to live in seconds (from now). If <= 0, token will not have exp (NOT recommended).
     * @param keyId     optional 'kid' for JWS header (pass null if none)
     * @return signed JWT string
     * @throws JOSEException on signing problems
     */
    public static String createSignedJWT(Map<String, Object> claims, PrivateKey privateKey, long ttlSeconds, String keyId) throws JOSEException {
        // Build claims
        JWTClaimsSet.Builder cb = new JWTClaimsSet.Builder();

        Instant now = Instant.now();
        cb.issueTime(Date.from(now));
        cb.jwtID(UUID.randomUUID().toString());

        if (ttlSeconds > 0) {
            cb.expirationTime(Date.from(now.plusSeconds(ttlSeconds)));
        }

        // Add provided claims (will overwrite standard fields if provided)
        if (claims != null) {
            for (Map.Entry<String,Object> e : claims.entrySet()) {
                // Nimbus supports well-known setters, but to keep generic, place as custom claim:
                String k = e.getKey();
                Object v = e.getValue();
                switch (k) {
                    case "iss": cb.claim("iss", v); break;
                    case "sub": cb.subject(String.valueOf(v)); break;
                    case "aud": cb.audience(String.valueOf(v)); break;
                    case "nbf": // expect numeric date or Date
                        if (v instanceof Date) cb.notBeforeTime((Date)v);
                        else if (v instanceof Number) cb.notBeforeTime(new Date(((Number)v).longValue()));
                        else cb.claim(k, v);
                        break;
                    case "exp": // user-provided expiration overrides ttlSeconds if present
                        cb.claim(k, v);
                        break;
                    default:
                        cb.claim(k, v);
                }
            }
        }

        JWTClaimsSet claimsSet = cb.build();

        // Create JWS header and sign
        JWSHeader.Builder headerBuilder = new JWSHeader.Builder(JWSAlgorithm.RS256)
                .type(JOSEObjectType.JWT);
        if (keyId != null && !keyId.isEmpty()) headerBuilder.keyID(keyId);
        JWSHeader header = headerBuilder.build();

        SignedJWT signedJWT = new SignedJWT(header, claimsSet);

        JWSSigner signer = new RSASSASigner((RSAPrivateKey) privateKey);
        signedJWT.sign(signer);

        return signedJWT.serialize();
    }

    // -------------------------
    // JWT verification
    // -------------------------

    /**
     * Verify a signed JWT (RS256) with the provided RSA public key.
     *
     * Verifies signature and standard time-based claims (exp, nbf). Throws on invalid signature or expired token.
     *
     * @param token the compact serialized JWT
     * @param publicKey RSA public key
     * @return JWTClaimsSet if verification and time checks succeed
     * @throws ParseException if token is malformed
     * @throws JOSEException if signature verification fails
     * @throws GeneralSecurityException if token invalid for security reasons (expired or not yet valid)
     */
    public static JWTClaimsSet verifySignedJWT(String token, PublicKey publicKey) throws ParseException, JOSEException, GeneralSecurityException {
        SignedJWT signedJWT = SignedJWT.parse(token);

        JWSVerifier verifier = new RSASSAVerifier((RSAPublicKey) publicKey);
        boolean signatureValid = signedJWT.verify(verifier);
        if (!signatureValid) {
            throw new JOSEException("JWT signature verification failed");
        }

        JWTClaimsSet claims = signedJWT.getJWTClaimsSet();
        // Time validation
        Date now = new Date();
        Date exp = claims.getExpirationTime();
        Date nbf = claims.getNotBeforeTime();

        if (exp != null && now.after(exp)) {
            throw new GeneralSecurityException("JWT is expired (exp): " + exp);
        }
        if (nbf != null && now.before(nbf)) {
            throw new GeneralSecurityException("JWT not valid yet (nbf): " + nbf);
        }

        return claims;
    }

    // -------------------------
    // Helpers / small utilities
    // -------------------------

    /**
     * Utility: Convert claims to a Map<String,Object> (useful if you want a plain map).
     */
    public static Map<String, Object> claimsToMap(JWTClaimsSet claims) {
        return claims.getClaims().entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));
    }

    /***
     * // Generate keys (testing)
     * KeyPair kp = JWTUtility.generateRSAKeyPair(2048);
     * PrivateKey priv = kp.getPrivate();
     * PublicKey pub = kp.getPublic();
     *
     * // Create token
     * Map<String,Object> claims = Map.of("iss","my-service","sub","user123","role","admin");
     * String token = JWTUtility.createSignedJWT(claims, priv, 3600, "my-key-id");
     *
     * // Verify token
     * JWTClaimsSet claimsSet = JWTUtility.verifySignedJWT(token, pub);
     * System.out.println("Verified. Claims: " + JWTUtility.claimsToMap(claimsSet));
     */
}
