import * as Crypto from 'expo-crypto';

/**
 * Encodes a UTF-8 string to Base64.
 * Uses `btoa` after percent-encoding to handle non-ASCII characters safely.
 */
export function base64Encode(data: string): string {
  // encodeURIComponent percent-encodes, then unescape to get raw bytes for btoa
  return btoa(encodeURIComponent(data).replace(/%([0-9A-F]{2})/g, (_, p1: string) =>
    String.fromCharCode(parseInt(p1, 16)),
  ));
}

/**
 * Decodes a Base64 string back to UTF-8.
 */
export function base64Decode(encoded: string): string {
  return decodeURIComponent(
    atob(encoded)
      .split('')
      .map((c) => `%${c.charCodeAt(0).toString(16).padStart(2, '0')}`)
      .join(''),
  );
}

/**
 * Returns the SHA-256 hex digest of a string using expo-crypto.
 * Safe to call in Expo Go — no native module ejection required.
 */
export async function sha256Digest(data: string): Promise<string> {
  return Crypto.digestStringAsync(
    Crypto.CryptoDigestAlgorithm.SHA256,
    data,
    { encoding: Crypto.CryptoEncoding.HEX },
  );
}
