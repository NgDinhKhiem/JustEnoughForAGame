package com.natsu.security;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class HashUtil {
    private static final int BUFFER_SIZE = 8192;

    private HashUtil() {
        // prevent instantiation
    }

    // -------------------------
    // Core
    // -------------------------

    private static String hash(byte[] input, String algorithm) throws NoSuchAlgorithmException {
        MessageDigest digest = MessageDigest.getInstance(algorithm);
        byte[] hashed = digest.digest(input);
        return HexFormat.of().formatHex(hashed);
    }

    private static String hashFile(File file, String algorithm) throws IOException, NoSuchAlgorithmException {
        MessageDigest digest = MessageDigest.getInstance(algorithm);

        try (FileInputStream fis = new FileInputStream(file)) {
            byte[] buffer = new byte[BUFFER_SIZE];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                digest.update(buffer, 0, bytesRead);
            }
        }

        return HexFormat.of().formatHex(digest.digest());
    }

    // -------------------------
    // Public API
    // -------------------------

    public static String sha256(String input) throws NoSuchAlgorithmException {
        return hash(input.getBytes(), "SHA-256");
    }

    public static String sha512(String input) throws NoSuchAlgorithmException {
        return hash(input.getBytes(), "SHA-512");
    }

    public static String md5(String input) throws NoSuchAlgorithmException {
        return hash(input.getBytes(), "MD5");
    }

    public static String sha256(byte[] input) throws NoSuchAlgorithmException {
        return hash(input, "SHA-256");
    }

    public static String sha512(byte[] input) throws NoSuchAlgorithmException {
        return hash(input, "SHA-512");
    }

    public static String md5(byte[] input) throws NoSuchAlgorithmException {
        return hash(input, "MD5");
    }

    public static String sha256(File file) throws IOException, NoSuchAlgorithmException {
        return hashFile(file, "SHA-256");
    }

    public static String sha512(File file) throws IOException, NoSuchAlgorithmException {
        return hashFile(file, "SHA-512");
    }

    public static String md5(File file) throws IOException, NoSuchAlgorithmException {
        return hashFile(file, "MD5");
    }

    /**
     * String text = "hello world";
     *
     * // Hash strings
     * System.out.println(HashUtil.sha256(text));
     * System.out.println(HashUtil.sha512(text));
     *
     * // Hash byte[]
     * byte[] data = text.getBytes();
     * System.out.println(HashUtil.md5(data));
     *
     * // Hash file
     * File file = new File("example.txt");
     * System.out.println(HashUtil.sha256(file));
     */
}
