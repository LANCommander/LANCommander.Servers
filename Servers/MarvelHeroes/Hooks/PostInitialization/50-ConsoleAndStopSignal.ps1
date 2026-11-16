#Requires -Modules Logging

# MHServerEmu's console input, and a clean shutdown on `docker stop`.
#
#   - The launcher (mhserveremu-server) feeds MHServerEmu's console from the FIFO
#     /run/mhserveremu/console; `mhserveremu-command '<command>'` writes to it. The directory is
#     created here for the user the server runs as. (Not /tmp: the kernel's protected_fifos setting
#     stops root opening another user's FIFO in a sticky directory.)
#   - `docker stop` sends SIGTERM to PID 1 only, the base image's PowerShell entrypoint, which
#     otherwise exits at once and takes the server down without saving. The handler registered
#     here, in that same process, cancels that and sends `!server shutdown` to the console
#     instead, which saves every player and stops the server; the entrypoint then finishes as
#     usual. A second signal, or one while the server isn't reading its console, isn't held back.
#     Give the container a stop timeout long enough to save (stop_grace_period: 30s).

$dir = '/run/mhserveremu'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
chown "$($Env:UID):$($Env:GID)" $dir
chmod 755 $dir

if (-not ('MhseStopSignal' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class MhseStopSignal
{
    [DllImport("libc.so.6", SetLastError = true)]
    private static extern int open(string path, int flags);

    [DllImport("libc.so.6", SetLastError = true)]
    private static extern IntPtr write(int fd, byte[] buffer, IntPtr count);

    [DllImport("libc.so.6")]
    private static extern int close(int fd);

    private const int O_WRONLY = 1;
    private const int O_NONBLOCK = 0x800;

    private static PosixSignalRegistration _term;
    private static PosixSignalRegistration _int;
    private static string _fifo;
    private static string _command;
    private static int _count;

    public static void Register(string fifo, string command)
    {
        _fifo = fifo;
        _command = command;
        _term = PosixSignalRegistration.Create(PosixSignal.SIGTERM, Handle);
        _int = PosixSignalRegistration.Create(PosixSignal.SIGINT, Handle);
    }

    private static void Handle(PosixSignalContext context)
    {
        if (Interlocked.Increment(ref _count) > 1)
            return;

        // Non-blocking: fails (ENXIO) when nothing reads the FIFO, i.e. the server isn't running
        int fd = open(_fifo, O_WRONLY | O_NONBLOCK);
        if (fd < 0)
            return;

        byte[] line = Encoding.UTF8.GetBytes(_command + "\n");
        write(fd, line, (IntPtr)line.Length);
        close(fd);

        context.Cancel = true;
        Console.WriteLine("[LANCommander] " + context.Signal + " received; sent '" + _command + "' to MHServerEmu");
    }
}
'@
}

[MhseStopSignal]::Register("$dir/console", '!server shutdown')
Write-Log "SIGTERM/SIGINT will stop MHServerEmu with !server shutdown"
