/**
 * AES-GCM encryption/decryption for Deriv tokens.
 * Format: base64(iv 12 bytes || ciphertext)
 * Key: TOKEN_ENCRYPTION_KEY env var (base64-encoded 32-byte key)
 */

const KEY_B64 = Deno.env.get("TOKEN_ENCRYPTION_KEY")!;

const b64ToBytes = (s: string): Uint8Array =>
  Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

const bytesToB64 = (b: Uint8Array): string =>
  btoa(String.fromCharCode(...b));

async function getKey(): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    b64ToBytes(KEY_B64),
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
}

export async function encrypt(plain: string): Promise<string> {
  const key = await getKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: "AES-GCM", iv },
      key,
      new TextEncoder().encode(plain),
    ),
  );
  const out = new Uint8Array(iv.length + ct.length);
  out.set(iv, 0);
  out.set(ct, iv.length);
  return bytesToB64(out);
}

export async function decrypt(encoded: string): Promise<string> {
  const key = await getKey();
  const data = b64ToBytes(encoded);
  const iv = data.slice(0, 12);
  const ct = data.slice(12);
  const plain = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    ct,
  );
  return new TextDecoder().decode(plain);
}
