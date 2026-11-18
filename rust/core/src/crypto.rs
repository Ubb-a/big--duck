use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Nonce};
use argon2::Argon2;
use rand::rngs::OsRng;
use rand::RngCore;

use crate::error::{CoreError, Result};

const MAGIC: &[u8; 8] = b"TDRVENC1";
const SALT_LEN: usize = 16;
const NONCE_LEN: usize = 12;
const TAG_LEN: usize = 16;

/// Total per-chunk framing overhead in bytes (`MAGIC` + salt + nonce + GCM tag).
pub const ENCRYPTED_CHUNK_OVERHEAD: u64 = (MAGIC.len() + SALT_LEN + NONCE_LEN + TAG_LEN) as u64;

/// Derives a 256-bit symmetric key from `password` and a 16-byte `salt` using Argon2id.
pub fn derive_key(password: &str, salt: &[u8; SALT_LEN]) -> Result<[u8; 32]> {
    if password.is_empty() {
        return Err(CoreError::Encryption(
            "encryption password must not be empty".to_string(),
        ));
    }

    let mut key = [0u8; 32];
    Argon2::default()
        .hash_password_into(password.as_bytes(), salt, &mut key)
        .map_err(|err| CoreError::Encryption(format!("Argon2 key derivation failed: {err}")))?;
    Ok(key)
}

/// Encrypts `plaintext` with AES-256-GCM using a random 16-byte salt and 12-byte nonce.
///
/// Output layout: `MAGIC (8B) || salt (16B) || nonce (12B) || ciphertext + GCM tag`.
pub fn encrypt_bytes(plaintext: &[u8], password: &str) -> Result<Vec<u8>> {
    let mut salt = [0u8; SALT_LEN];
    let mut nonce_bytes = [0u8; NONCE_LEN];
    OsRng.fill_bytes(&mut salt);
    OsRng.fill_bytes(&mut nonce_bytes);

    let key = derive_key(password, &salt)?;
    let cipher = Aes256Gcm::new_from_slice(&key)
        .map_err(|err| CoreError::Encryption(format!("failed to initialize AES-256-GCM: {err}")))?;

    let ciphertext = cipher
        .encrypt(Nonce::from_slice(&nonce_bytes), plaintext)
        .map_err(|err| CoreError::Encryption(format!("AES-256-GCM encryption failed: {err}")))?;

    let mut out = Vec::with_capacity(MAGIC.len() + SALT_LEN + NONCE_LEN + ciphertext.len());
    out.extend_from_slice(MAGIC);
    out.extend_from_slice(&salt);
    out.extend_from_slice(&nonce_bytes);
    out.extend_from_slice(&ciphertext);
    Ok(out)
}

/// Decrypts an encrypted frame created by [`encrypt_bytes`] and verifies the GCM tag.
pub fn decrypt_bytes(frame: &[u8], password: &str) -> Result<Vec<u8>> {
    let min_len = ENCRYPTED_CHUNK_OVERHEAD as usize;
    if frame.len() < min_len {
        return Err(CoreError::Encryption(format!(
            "encrypted frame too short ({} bytes, minimum {min_len})",
            frame.len()
        )));
    }
    if &frame[..MAGIC.len()] != MAGIC {
        return Err(CoreError::Encryption(
            "invalid encrypted frame header".to_string(),
        ));
    }

    let salt_start = MAGIC.len();
    let nonce_start = salt_start + SALT_LEN;
    let cipher_start = nonce_start + NONCE_LEN;

    let mut salt = [0u8; SALT_LEN];
    salt.copy_from_slice(&frame[salt_start..nonce_start]);
    let nonce = Nonce::from_slice(&frame[nonce_start..cipher_start]);
    let ciphertext = &frame[cipher_start..];

    let key = derive_key(password, &salt)?;
    let cipher = Aes256Gcm::new_from_slice(&key)
        .map_err(|err| CoreError::Encryption(format!("failed to initialize AES-256-GCM: {err}")))?;

    cipher.decrypt(nonce, ciphertext).map_err(|_| {
        CoreError::Encryption(
            "decryption failed: invalid password or corrupted ciphertext".to_string(),
        )
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encrypt_and_decrypt_roundtrip_succeeds() {
        let plaintext = b"TeleDrive secret payload with AES-256-GCM and Argon2id!";
        let encrypted = encrypt_bytes(plaintext, "correct-horse-battery-staple").unwrap();

        assert_eq!(
            encrypted.len(),
            plaintext.len() + ENCRYPTED_CHUNK_OVERHEAD as usize
        );
        assert_ne!(&encrypted[36..], plaintext);

        let decrypted = decrypt_bytes(&encrypted, "correct-horse-battery-staple").unwrap();
        assert_eq!(decrypted, plaintext);

        // Empty payload should also roundtrip cleanly.
        let empty_enc = encrypt_bytes(b"", "pw").unwrap();
        assert_eq!(empty_enc.len(), ENCRYPTED_CHUNK_OVERHEAD as usize);
        assert!(decrypt_bytes(&empty_enc, "pw").unwrap().is_empty());
    }

    #[test]
    fn decrypt_rejects_wrong_password() {
        let encrypted = encrypt_bytes(b"classified", "right-pass").unwrap();
        let err = decrypt_bytes(&encrypted, "wrong-pass").unwrap_err();
        assert!(matches!(err, CoreError::Encryption(_)));
    }

    #[test]
    fn decrypt_rejects_tampered_ciphertext_and_invalid_header() {
        let mut encrypted = encrypt_bytes(b"integrity test", "pass123").unwrap();
        let last_idx = encrypted.len() - 1;
        encrypted[last_idx] ^= 0x01;
        assert!(matches!(
            decrypt_bytes(&encrypted, "pass123"),
            Err(CoreError::Encryption(_))
        ));

        let mut bad_header = encrypt_bytes(b"header test", "pass123").unwrap();
        bad_header[0] = b'X';
        assert!(matches!(
            decrypt_bytes(&bad_header, "pass123"),
            Err(CoreError::Encryption(_))
        ));
    }
}
