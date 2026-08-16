#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

// sys/ptrace.h is not in the public iOS SDK — declare manually.
#define PT_DENY_ATTACH 31
int ptrace(int request, pid_t pid, caddr_t addr, int data);

// Hard-kill: no Swift exception, no error log, no useful crash report for attacker.
static void __attribute__((noreturn)) die(void) {
    kill(getpid(), SIGKILL);
    __builtin_unreachable();
}

// Obfuscated needle comparison — avoids plain "frida" string literal in binary.
// Compares a C string against a known XOR-encoded target (key = 0x13).
static int match_xor(const char *hay, const unsigned char *encoded, size_t len) {
    size_t hlen = strlen(hay);
    if (hlen < len) return 0;
    for (size_t i = 0; i <= hlen - len; i++) {
        int ok = 1;
        for (size_t j = 0; j < len; j++) {
            if ((unsigned char)(hay[i + j]) != (encoded[j] ^ 0x13u)) { ok = 0; break; }
        }
        if (ok) return 1;
    }
    return 0;
}

// "frida"   XOR 0x13 = { 0x75, 0x61, 0x7A, 0x77, 0x72 }
// "cynject" XOR 0x13 = { 0x70, 0x6A, 0x7D, 0x79, 0x76, 0x70, 0x67 }
// "gadget"  XOR 0x13 = { 0x74, 0x72, 0x77, 0x74, 0x76, 0x67 }
static const unsigned char kFrida[]   = { 0x75, 0x61, 0x7A, 0x77, 0x72 };
static const unsigned char kCynject[] = { 0x70, 0x6A, 0x7D, 0x79, 0x76, 0x70, 0x67 };
static const unsigned char kGadget[]  = { 0x74, 0x72, 0x77, 0x74, 0x76, 0x67 };

// Runs before main() and before Swift runtime — very hard to hook.
__attribute__((constructor))
static void security_check(void) {

    // 1. Deny debugger attachment (ptrace trick).
    //    If a debugger is already attached this kills the process immediately.
    ptrace(PT_DENY_ATTACH, 0, 0, 0);

    // 2. Scan every loaded dylib for Frida / Cynject / Gadget names.
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (match_xor(name, kFrida,   sizeof(kFrida))   ||
            match_xor(name, kCynject, sizeof(kCynject)) ||
            match_xor(name, kGadget,  sizeof(kGadget))) {
            die();
        }
    }

    // 3. Check for frida_agent_main symbol injected into this process.
    if (dlsym(RTLD_DEFAULT, "frida_agent_main") != NULL) {
        die();
    }

    // 4. Probe Frida server's default port (27042) on localhost.
    //    Successful connect = frida-server is running on this device.
    {
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock >= 0) {
            struct timeval tv = { 0, 200000 }; // 200 ms max
            setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
            struct sockaddr_in addr;
            memset(&addr, 0, sizeof(addr));
            addr.sin_family = AF_INET;
            addr.sin_port = htons(27042);
            addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
            if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) == 0) {
                close(sock);
                die();
            }
            close(sock);
        }
    }

    // 5. Check frida-server binary on common jailbreak paths.
    {
        // Paths encoded as individual chars to avoid one long string literal.
        const char *paths[] = {
            "/usr/sbin/frida-server",
            "/usr/bin/frida-server",
            "/usr/local/bin/frida-server",
            "/var/jb/usr/sbin/frida-server",
        };
        for (int i = 0; i < 4; i++) {
            if (access(paths[i], F_OK) == 0) die();
        }
    }
}
