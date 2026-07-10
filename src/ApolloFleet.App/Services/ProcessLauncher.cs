using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace ApolloFleet.App.Services;

/// <summary>
/// Starts sunshine as SYSTEM in the active console session via a bundled PaExec
/// (<c>-s -i &lt;session&gt;</c>). This is REQUIRED for Apollo to capture the UAC secure
/// desktop: an elevated-admin process cannot grab the secure desktop — only SYSTEM
/// in the interactive session can (the stock ApolloService does the same via its
/// SYSTEM service wrapper). If no helper is available it falls back to a direct
/// elevated-admin start, which works for normal capture but not the UAC prompt.
/// A user can override the helper path in settings. See docs/elevation.md.
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

        var helper = ResolveHelper(helperExePath);
        if (!string.IsNullOrWhiteSpace(helper))
        {
            var pid = await StartViaHelperAsync(helper, sunshineExePath, configPath, workDir, instanceId, cancellationToken).ConfigureAwait(false);
            if (pid is > 0)
                return pid;
            // Helper could not produce a pid — fall back to a direct elevated start.
        }

        return StartDirect(sunshineExePath, configPath, workDir);
    }

    /// <summary>Explicit helper wins; otherwise probe for the bundled paexec.exe.</summary>
    private static string? ResolveHelper(string? configured)
    {
        if (!string.IsNullOrWhiteSpace(configured) && File.Exists(configured))
            return configured;

        var appDir = AppContext.BaseDirectory;
        var candidates = new[]
        {
            Path.Combine(appDir, "paexec.exe"),
            Path.Combine(appDir, "PAExec", "paexec.exe"),
            Path.Combine(appDir, "bin", "PAExec", "paexec.exe"),
        };
        foreach (var c in candidates)
        {
            try
            {
                if (File.Exists(c))
                    return c;
            }
            catch { /* ignore */ }
        }
        return null;
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
