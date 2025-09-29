package com.natsu.jefag.security;

import java.security.SecureRandom;

public final class TokenUtil {
    private static final SecureRandom RAND = new SecureRandom();
    private static final char[] ALPHANUM = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".toCharArray();

    public static String generateRandomToken(int length) {
        char[] token = new char[length];
        for (int i = 0; i < length; i++) {
            token[i] = ALPHANUM[RAND.nextInt(ALPHANUM.length)];
        }
        return new String(token);
    }
}
