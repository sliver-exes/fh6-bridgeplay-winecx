/*
 * Forza Horizon 6 Xbox UDP compatibility proxy (Wine / Bridgeplay FEX route).
 *
 * Wine does not implement SIO_UDP_NETRESET, and macOS rejects IPv4-level socket
 * options (IP_DONTFRAGMENT, IP_TTL, ...) applied to a dual-stack IPv6 socket.
 * The game creates an AF_INET6 UDP socket (IPV6_V6ONLY=0) bound to [::]:3074 and
 * closes it and retries when any of these calls fails. This proxy forwards
 * ws2_32 to a renamed copy, ws2_o.dll, and changes only those results to match
 * Windows.
 *
 * CREDITS (all upstreams, GPL-3.0):
 *   - xvferxedd/fh5-d3dmetal-fix, commit ebd20dbe: original FH5 ws2_32 proxy.
 *   - Andytizer/fh5-crossover-steam-fix v1.0.1: recovered the proxy and the
 *     pe.pl export-rename helper.
 *   - MathiasKowoll/MacGameFix fixes/fh5-netfix.c (+ build-fh5-netfix.sh,
 *     pe.py, pe.pl): source-built version this file is copied from.
 *
 * CHANGES FOR FORZA HORIZON 6 (this file, 2026-11-14):
 *   - IPPROTO_IP options that fail (any option, not only the known four) on a
 *     tracked UDP socket created as AF_INET6/AF_UNSPEC now get the IPv6
 *     equivalent applied where one exists (IP_TTL -> IPV6_UNICAST_HOPS,
 *     IP_DONTFRAGMENT -> IPV6_DONTFRAG, IP_MULTICAST_TTL/LOOP, IP_TOS) and are
 *     then reported as success. Sockets of other families are forwarded
 *     unchanged, so a genuine IPv4 failure is never hidden.
 *   - Sockets remember their address family for the check above.
 *   - Log file is fh6-netfix.log (enabled by MGF_FH5_NETLOG=1; the fix itself
 *     can be switched off with MGF_FH5_NETFIX=0). Env names kept from upstream.
 *   - Built as an x64 PE to sit in front of the ARM64X builtin ws2_32 of the
 *     crossover-FH-fex runner (loaded by the FEX-emulated x64 game only).
 */

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stddef.h>

#define SIO_UDP_NETRESET_ 0x9800000FUL
#ifndef IP_DONTFRAGMENT
#define IP_DONTFRAGMENT 14
#endif
#ifndef IPV6_DONTFRAG
#define IPV6_DONTFRAG 14
#endif
#define MAX_SOCKETS 512
#define MAX_LOG_LINES 2000

typedef struct { char *start, *pos, *end; } log_buffer;

static HMODULE original;
static int fix_enabled = -1;
static int log_enabled = -1;
static volatile LONG log_lines;
static HANDLE log_file = INVALID_HANDLE_VALUE;
static SRWLOCK log_lock = SRWLOCK_INIT;
static SRWLOCK socket_lock = SRWLOCK_INIT;
static struct { SOCKET socket; int family; } sockets[MAX_SOCKETS];

static void *original_proc(const char *name)
{
    if (!original)
    {
        original = GetModuleHandleA("ws2_o.dll");
        if (!original) original = LoadLibraryA("ws2_o.dll");
    }
    return original ? GetProcAddress(original, name) : NULL;
}

#define ORIGINAL(var, name) static void *var##_proc; if (!var##_proc) var##_proc = original_proc(name)
#define CALLER __builtin_return_address(0)

static int enabled(void)
{
    if (fix_enabled < 0)
    {
        char value[4];
        DWORD error = GetLastError();
        DWORD count = GetEnvironmentVariableA("MGF_FH5_NETFIX", value, sizeof(value));
        fix_enabled = count == 1 && value[0] == '0' ? 0 : 1;
        count = GetEnvironmentVariableA("MGF_FH5_NETLOG", value, sizeof(value));
        log_enabled = count == 1 && value[0] == '1' ? 1 : 0;
        SetLastError(error);
    }
    return fix_enabled;
}

static void put_char(log_buffer *buffer, char value)
{
    if (buffer->pos < buffer->end) *buffer->pos++ = value;
}

static void put_string(log_buffer *buffer, const char *value)
{
    while (value && *value) put_char(buffer, *value++);
}

static void put_unsigned(log_buffer *buffer, unsigned long long value)
{
    char digits[24];
    int count = 0;
    do { digits[count++] = '0' + (int)(value % 10); value /= 10; } while (value);
    while (count) put_char(buffer, digits[--count]);
}

static void put_integer(log_buffer *buffer, long long value)
{
    if (value < 0) { put_char(buffer, '-'); value = -value; }
    put_unsigned(buffer, (unsigned long long)value);
}

static void put_hex(log_buffer *buffer, unsigned long long value)
{
    char digits[20];
    int count = 0;
    do { digits[count++] = "0123456789abcdef"[value & 15]; value >>= 4; } while (value);
    put_char(buffer, '0'); put_char(buffer, 'x');
    while (count) put_char(buffer, digits[--count]);
}

static void put_caller(log_buffer *buffer, void *return_address)
{
    HMODULE module = NULL;
    if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                           GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           (LPCSTR)return_address, &module) && module)
    {
        char name[MAX_PATH];
        DWORD count = GetModuleFileNameA(module, name, sizeof(name));
        DWORD i, start = 0;
        for (i = 0; i < count; i++) if (name[i] == '\\' || name[i] == '/') start = i + 1;
        if (count < sizeof(name)) name[count] = 0;
        put_string(buffer, name + start); put_char(buffer, '+');
        put_hex(buffer, (ULONG_PTR)return_address - (ULONG_PTR)module);
    }
    else
    {
        put_string(buffer, "?+"); put_hex(buffer, (ULONG_PTR)return_address);
    }
}

static void begin_line(log_buffer *buffer, void *return_address)
{
    put_unsigned(buffer, GetTickCount64()); put_char(buffer, ' ');
    put_char(buffer, 't'); put_unsigned(buffer, GetCurrentThreadId()); put_char(buffer, ' ');
    put_caller(buffer, return_address); put_char(buffer, ' ');
}

static void emit(log_buffer *buffer)
{
    DWORD written;
    if (log_enabled != 1 || log_lines >= MAX_LOG_LINES) return;
    put_char(buffer, '\n');
    AcquireSRWLockExclusive(&log_lock);
    if (log_lines < MAX_LOG_LINES)
    {
        if (log_file == INVALID_HANDLE_VALUE)
            log_file = CreateFileA("fh6-netfix.log", FILE_APPEND_DATA,
                                   FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                   NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        if (log_file != INVALID_HANDLE_VALUE)
        {
            log_lines++;
            WriteFile(log_file, buffer->start, (DWORD)(buffer->pos - buffer->start), &written, NULL);
        }
    }
    ReleaseSRWLockExclusive(&log_lock);
}

#define LOG_BUFFER(name) char name##_bytes[1024]; log_buffer name = { name##_bytes, name##_bytes, name##_bytes + 1000 }

static void remember_socket(SOCKET socket, int family)
{
    int i, free_slot = -1;
    AcquireSRWLockExclusive(&socket_lock);
    for (i = 0; i < MAX_SOCKETS; i++)
    {
        if (sockets[i].socket == socket) { free_slot = i; break; }
        if (!sockets[i].socket && free_slot < 0) free_slot = i;
    }
    if (free_slot >= 0)
    {
        sockets[free_slot].socket = socket;
        sockets[free_slot].family = family;
    }
    ReleaseSRWLockExclusive(&socket_lock);
}

static int known_socket(SOCKET socket)
{
    int i, found = 0;
    if (!socket || socket == INVALID_SOCKET) return 0;
    AcquireSRWLockShared(&socket_lock);
    for (i = 0; i < MAX_SOCKETS; i++) if (sockets[i].socket == socket) { found = 1; break; }
    ReleaseSRWLockShared(&socket_lock);
    return found;
}

static int socket_family(SOCKET socket)
{
    int i, family = -1;
    if (!socket || socket == INVALID_SOCKET) return -1;
    AcquireSRWLockShared(&socket_lock);
    for (i = 0; i < MAX_SOCKETS; i++) if (sockets[i].socket == socket) { family = sockets[i].family; break; }
    ReleaseSRWLockShared(&socket_lock);
    return family;
}

static void forget_socket(SOCKET socket)
{
    int i;
    AcquireSRWLockExclusive(&socket_lock);
    for (i = 0; i < MAX_SOCKETS; i++) if (sockets[i].socket == socket) sockets[i].socket = 0;
    ReleaseSRWLockExclusive(&socket_lock);
}

static void log_result(log_buffer *buffer, long long result, DWORD error)
{
    put_string(buffer, " = "); put_integer(buffer, result);
    put_string(buffer, " err="); put_unsigned(buffer, error);
}

static void created(SOCKET socket, int family, int type, int protocol,
                    const char *function, void *return_address, DWORD error)
{
    LOG_BUFFER(buffer);
    if (!(type == SOCK_DGRAM || (type == 0 && protocol == IPPROTO_UDP))) return;
    if (socket != INVALID_SOCKET) remember_socket(socket, family);
    begin_line(&buffer, return_address); put_string(&buffer, function);
    put_string(&buffer, " af="); put_integer(&buffer, family);
    put_string(&buffer, " type="); put_integer(&buffer, type);
    put_string(&buffer, " proto="); put_integer(&buffer, protocol);
    put_string(&buffer, " -> h="); put_unsigned(&buffer, socket);
    put_string(&buffer, " err="); put_unsigned(&buffer, error);
    emit(&buffer);
}

SOCKET WSAAPI wrap_socket(int family, int type, int protocol)
{
    ORIGINAL(function, "socket");
    SOCKET socket = ((SOCKET (WSAAPI *)(int,int,int))function_proc)(family, type, protocol);
    if (enabled()) { DWORD error = GetLastError(); created(socket, family, type, protocol, "socket", CALLER, error); SetLastError(error); }
    return socket;
}

SOCKET WSAAPI wrap_WSASocketW(int family, int type, int protocol,
                              LPWSAPROTOCOL_INFOW info, GROUP group, DWORD flags)
{
    ORIGINAL(function, "WSASocketW");
    SOCKET socket = ((SOCKET (WSAAPI *)(int,int,int,LPWSAPROTOCOL_INFOW,GROUP,DWORD))function_proc)(family, type, protocol, info, group, flags);
    if (enabled()) { DWORD error = GetLastError(); created(socket, family, type, protocol, "WSASocketW", CALLER, error); SetLastError(error); }
    return socket;
}

SOCKET WSAAPI wrap_WSASocketA(int family, int type, int protocol,
                              LPWSAPROTOCOL_INFOA info, GROUP group, DWORD flags)
{
    ORIGINAL(function, "WSASocketA");
    SOCKET socket = ((SOCKET (WSAAPI *)(int,int,int,LPWSAPROTOCOL_INFOA,GROUP,DWORD))function_proc)(family, type, protocol, info, group, flags);
    if (enabled()) { DWORD error = GetLastError(); created(socket, family, type, protocol, "WSASocketA", CALLER, error); SetLastError(error); }
    return socket;
}

int WSAAPI wrap_WSAIoctl(SOCKET socket, DWORD code, LPVOID input, DWORD input_length,
                         LPVOID output, DWORD output_length, LPDWORD returned,
                         LPWSAOVERLAPPED overlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE completion)
{
    ORIGINAL(function, "WSAIoctl");
    int result = ((int (WSAAPI *)(SOCKET,DWORD,LPVOID,DWORD,LPVOID,DWORD,LPDWORD,LPWSAOVERLAPPED,LPWSAOVERLAPPED_COMPLETION_ROUTINE))function_proc)
        (socket, code, input, input_length, output, output_length, returned, overlapped, completion);
    if (enabled() && known_socket(socket))
    {
        DWORD error = GetLastError();
        int original_result = result, fixed = 0;
        LOG_BUFFER(buffer);
        if (code == SIO_UDP_NETRESET_ && result != 0)
        {
            result = 0; error = 0; fixed = 1;
            if (returned) *returned = 0;
        }
        begin_line(&buffer, CALLER); put_string(&buffer, "WSAIoctl h="); put_unsigned(&buffer, socket);
        put_string(&buffer, " code="); put_hex(&buffer, code);
        if (fixed)
        {
            put_string(&buffer, " original="); put_integer(&buffer, original_result);
            put_string(&buffer, " forced-success");
        }
        log_result(&buffer, result, error); emit(&buffer); SetLastError(error);
    }
    return result;
}

int WSAAPI wrap_setsockopt(SOCKET socket, int level, int option, const char *value, int length)
{
    ORIGINAL(function, "setsockopt");
    int result = ((int (WSAAPI *)(SOCKET,int,int,const char*,int))function_proc)(socket, level, option, value, length);
    int original_result = result, alternate = -2;
    int family;
    if (result != 0 && level == IPPROTO_IP && enabled() &&
        ((family = socket_family(socket)) == AF_INET6 || family == AF_UNSPEC))
    {
        DWORD original_error = GetLastError();
        if (original_error == WSAEINVAL || original_error == WSAENOPROTOOPT || original_error == WSAEOPNOTSUPP)
        {
            int ipv6_option = option == IP_TTL ? IPV6_UNICAST_HOPS :
                              option == IP_MULTICAST_TTL ? IPV6_MULTICAST_HOPS :
                              option == IP_MULTICAST_LOOP ? IPV6_MULTICAST_LOOP :
                              option == IP_TOS ? IPV6_TCLASS :
                              option == IP_DONTFRAGMENT ? IPV6_DONTFRAG : -1;
            if (ipv6_option >= 0)
                alternate = ((int (WSAAPI *)(SOCKET,int,int,const char*,int))function_proc)
                    (socket, IPPROTO_IPV6, ipv6_option, value, length);
            result = 0; SetLastError(0);
        }
        else SetLastError(original_error);
    }
    if (enabled() && known_socket(socket))
    {
        DWORD error = GetLastError();
        LOG_BUFFER(buffer);
        begin_line(&buffer, CALLER); put_string(&buffer, "setsockopt h="); put_unsigned(&buffer, socket);
        put_string(&buffer, " level="); put_integer(&buffer, level);
        put_string(&buffer, " option="); put_integer(&buffer, option);
        if (original_result != result)
        {
            put_string(&buffer, " original="); put_integer(&buffer, original_result);
            put_string(&buffer, " ipv6-alternate="); put_integer(&buffer, alternate);
            put_string(&buffer, " forced-success");
        }
        log_result(&buffer, result, error); emit(&buffer); SetLastError(error);
    }
    return result;
}

int WSAAPI wrap_closesocket(SOCKET socket)
{
    ORIGINAL(function, "closesocket");
    int tracked = enabled() && known_socket(socket);
    int result = ((int (WSAAPI *)(SOCKET))function_proc)(socket);
    if (tracked)
    {
        DWORD error = GetLastError();
        LOG_BUFFER(buffer);
        forget_socket(socket);
        begin_line(&buffer, CALLER); put_string(&buffer, "closesocket h="); put_unsigned(&buffer, socket);
        log_result(&buffer, result, error); emit(&buffer); SetLastError(error);
    }
    return result;
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved)
{
    (void)instance; (void)reason; (void)reserved;
    return TRUE;
}
