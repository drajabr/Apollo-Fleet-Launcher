using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace ApolloFleet.App.Services;

/// <summary>
/// Starts sunshine as a direct child of the launcher so it inherits the launcher's
/// token and session: when the launcher runs elevated (via "Run as administrator" or
/// the Highest-privilege logon task) sunshine is elevated too, with NO additional UAC
/// prompt and no helper service. A PaExec-style session helper is used ONLY when the
/// user explicitly configures one (see docs/elevation.md).
/// </summary>
public sealed class ProcessLauncher : IProcessLauncher
{
    [DllImport("kernel32.dll")]
    private static extern uint WTSGetActiveConsoleSessionId();

    public async Task<int?> StartSunshineAsync(string sunshineExePath, string configPath, string instanceId, string? helperExePath, CancellationToken cancellationToken = default)
    {
        var workDir = Path.GetDirectoryName(sunshineExePath);
        if (string.IsNullOrEmpty(workDir))
            workDir = Environment.CurrentDirectory;

        // Only an explicitly-configured helper is used. Auto-probing a bundled
        // PaExec was removed: it spun up a service and could surface extra
        // consent/AV prompts even when the launcher was already elevated. A
        // direct child start inherits elevation silently, which is what we want.
        if (!string.IsNullOrWhiteSpace(helperExePath) && File.Exists(helperExePath))
        {
            var pid = await StartViaHelperAsync(helperExePath, sunshineExePath, configPath, workDir, instanceId, cancellationToken).ConfigureAwait(false);
            if (pid is > 0)
                return pid;
            // Helper could not produce a pid — fall back to direct start.
        }

        return StartDirect(sunshineExePath, configPath, workDir);
    }

    private static int? StartDirect(string exe, string configPath, string workDir)
    {
        var psi = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = $"\"{configPath}\"",
            WorkingDirectory = workDir,
            UseShellExecute = false,
            // sunshine.exe is a console-subsystem binary; without CREATE_NO_WINDOW
            // every instance pops a visible console window.
            CreateNoWindow = true
        };
        var p = Process.Start(psi);
        return p?.Id;
    }

    private static async Task<int?> StartViaHelperAsync(string helper, string sunshineExe, string configPath, string workDir, string instanceId, CancellationToken ct)
    {
        var session = WTSGetActiveConsoleSessionId();
        var tmp = Path.Combine(Path.GetTempPath(), $"apollo-fleet-{instanceId}.txt");
        var preExisting = Process.GetProcessesByName("sunshine").Select(p => p.Id).ToHashSet();
        try
        {
            if (File.Exists(tmp))
                File.Delete(tmp);
        }
        catch
        {
            /* ignore */
        }

        var safeExe = sunshineExe.Replace("'", "''");
        var safeCfg = configPath.Replace("'", "''");
        var safeTmp = tmp.Replace("'", "''");
        // Mirror legacy AHK launch sequence exactly: Start-Process + shell redirection to pid file.
        var ps = $"$p=Start-Process -WindowStyle Hidden -FilePath '{safeExe}' -ArgumentList '{safeCfg}' -PassThru;$p.Id>'{safeTmp}'";
        var args = $"-accepteula -i {session} -w \"{workDir}\" -s \"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe\" -Command \"{ps}\"";
        var psi = new ProcessStartInfo
        {
            FileName = helper,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        using var proc = Process.Start(psi);
        if (proc is null)
            return null;
        await proc.WaitForExitAsync(ct).ConfigureAwait(false);

        for (var i = 0; i < 50; i++)
        {
            ct.ThrowIfCancellationRequested();
            if (File.Exists(tmp))
            {
                var text = await File.ReadAllTextAsync(tmp, ct).ConfigureAwait(false);
                if (int.TryParse(text.Trim(), out var pid))
                    return pid;
            }

            await Task.Delay(10, ct).ConfigureAwait(false);
        }

        // Fallback: if pid file could not be read, detect newly spawned sunshine process.
        for (var i = 0; i < 30; i++)
        {
            ct.ThrowIfCancellationRequested();
            foreach (var p in Process.GetProcessesByName("sunshine"))
            {
                try
                {
                    if (!preExisting.Contains(p.Id))
                        return p.Id;
                }
                finally
                {
                    p.Dispose();
                }
            }

            await Task.Delay(50, ct).ConfigureAwait(false);
        }

        return null;
    }
}
