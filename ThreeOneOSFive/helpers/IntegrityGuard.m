#import <Foundation/Foundation.h>
#include <signal.h>
#include <unistd.h>
#include <CommonCrypto/CommonDigest.h>

// ── Integrity Guard ──────────────────────────────────────────────────────────
// Recomputes SHA-256 of every XOR-encoded constant that lives in the binary
// (token, HMAC key, Frida needle strings). If even 1 byte was patched by a
// hex editor or binary patcher, the hash won't match → hard kill.
//
// The expected hash is itself XOR-encoded (key 0x4B) so a hex editor can't
// just locate and overwrite it without also knowing the algorithm.
// ─────────────────────────────────────────────────────────────────────────────

static void __attribute__((noreturn)) igDie(void) {
    kill(getpid(), SIGKILL);
    __builtin_unreachable();
}

// ── Mirrored copies of every XOR constant (key 0x4B) ────────────────────────
// Must stay byte-for-byte identical to the arrays in PatchHubService.swift
// and FridaDetect.m. Any divergence is caught at build-time by the Python
// script that regenerates _kExpected.

static const uint8_t _ig_t[] = {
    0x28, 0x22, 0x24, 0x38, 0x3D, 0x22, 0x3B, 0x14, 0x72, 0x19, 0x33, 0x7F, 0x20, 0x11,
    0x79, 0x26, 0x1A, 0x7C, 0x3C, 0x05, 0x78, 0x3B, 0x07, 0x73, 0x14, 0x0F, 0x01, 0x1F,
    0x06, 0x0E, 0x06, 0x0A, 0x12, 0x1F, 0x03, 0x0A, 0x05, 0x0C, 0x07, 0x04, 0x05, 0x08,
    0x19, 0x0A, 0x08, 0x00, 0x0D, 0x0A, 0x05, 0x0C, 0x05, 0x03, 0x0E, 0x0A, 0x05, 0x08,
    0x1E, 0x08, 0x0A, 0x08, 0x1F, 0x0A, 0x04, 0x05, 0x0E
};
static const uint8_t _ig_sk[] = {
    0x0F, 0x7E, 0x1C, 0x14, 0x23, 0x26, 0x2A, 0x28, 0x14, 0x38, 0x22, 0x2C, 0x14, 0x3D,
    0x79, 0x14, 0x72, 0x26, 0x1A, 0x33, 0x7C, 0x25, 0x19, 0x7F, 0x3B, 0x07, 0x20, 0x73
};
static const uint8_t _ig_frida[]   = { 0x75, 0x61, 0x7A, 0x77, 0x72 };
static const uint8_t _ig_cynject[] = { 0x70, 0x6A, 0x7D, 0x79, 0x76, 0x70, 0x67 };
static const uint8_t _ig_gadget[]  = { 0x74, 0x72, 0x77, 0x74, 0x76, 0x67 };

// SHA-256 of concatenation of all arrays above, XOR'd with 0x4B.
// Regenerate with: python3 C:\Temp\gen_integrity.py
static const uint8_t _kExpected[32] = {
    0x33, 0x77, 0x22, 0xC5, 0x43, 0x59, 0xB1, 0x9B,
    0xC7, 0x31, 0x73, 0x39, 0x26, 0x07, 0x11, 0xDA,
    0xCD, 0xF1, 0x11, 0x61, 0xE7, 0xC4, 0x59, 0xD3,
    0xD1, 0x26, 0x7A, 0xAC, 0x5B, 0xB3, 0xF1, 0xDA
};

// Exposed so FridaDetect and LicenseKeyService can call it from multiple sites,
// making it harder to NOP out with a single patch.
void runIntegrityCheck(void) {
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    CC_SHA256_Update(&ctx, _ig_t,       sizeof(_ig_t));
    CC_SHA256_Update(&ctx, _ig_sk,      sizeof(_ig_sk));
    CC_SHA256_Update(&ctx, _ig_frida,   sizeof(_ig_frida));
    CC_SHA256_Update(&ctx, _ig_cynject, sizeof(_ig_cynject));
    CC_SHA256_Update(&ctx, _ig_gadget,  sizeof(_ig_gadget));

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &ctx);

    // Decode expected and compare in constant time
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        if (digest[i] != (_kExpected[i] ^ 0x4Bu)) igDie();
    }
}

// Called as a constructor so it runs before main() — same timing as FridaDetect.
__attribute__((constructor))
static void integrity_guard_init(void) {
    runIntegrityCheck();
}
