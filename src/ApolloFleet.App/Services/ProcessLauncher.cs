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

    private readonly FileLogWriter _log;

    public ProcessLauncher(FileLogWriter log) => _log = log;

    public async Task<int?> StartSunshineAsync(string sunshineExePath, string configPath, string instanceId, string? helperExePath, CancellationToken cancellationToken = default)
    {
        var workDir = Path.GetDirectoryName(sunshineExePath);
        if (string.IsNullOrEmpty(workDir))
            workDir = Environment.CurrentDirectory;

        var helper = ResolveHelper(helperExePath);
        if (!string.IsNullOrWhiteSpace(helper))
        {
            // Never let a helper failure bubble up — the supervisor's tick swallows
            // exceptions, which would silently prevent the direct-start fallback.
            try
            {
                var pid = await StartViaHelperAsync(helper, sunshineExePath, configPath, workDir, instanceId, cancellationToken).ConfigureAwait(false);
                if (pid is > 0)
                    return pid;
                _log.Warn("SYSTEM launch via PaExec produced no PID; falling back to a direct elevated start (UAC secure-desktop capture unavailable).");
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                _log.Warn($"SYSTEM launch via PaExec failed ({ex.Message}); falling back to a direct elevated start. If this persists it's usually AV blocking paexec.exe — add an exclusion.");
            }
        }
        else
        {
            _log.Warn("paexec.exe not found next to the app; starting sunshine as elevated admin (cannot capture the UAC secure desktop).");
        }

        try
        {
            return StartDirect(sunshineExePath, configPath, workDir);
        }
        catch (Exception ex)
        {
            _log.Error($"Direct start of sunshine failed: {ex.Message}");
            return null;
        }
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

    /// <summary>
    /// Writes the VBScript that actually spawns sunshine, and returns its path.
    /// Kept as a script rather than a direct paexec launch because we need the new
    /// PID back: <c>Win32_Process.Create</c> hands it to us, whereas paexec cannot
    /// report the PID of a detached child. Per-instance filename so simultaneous
    /// fleet starts never share or truncate one another's script.
    /// </summary>
    private static string WriteLaunchScript(string instanceId)
    {
        var path = Path.Combine(Path.GetTempPath(), $"apollo-fleet-launch-{instanceId}.vbs");
        // Quotes are built with Chr(34) rather than VBScript's doubled-quote escaping
        // so the source here contains no runs of quotes to fight with.
        const string vbs = """
            Set a = WScript.Arguments
            q = Chr(34)
            Set svc = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
            Set si = svc.Get("Win32_ProcessStartup").SpawnInstance_
            si.ShowWindow = 0
            Set pc = svc.Get("Win32_Process")
            cmd = q & a(0) & q & " " & q & a(1) & q
            rc = pc.Create(cmd, a(3), si, pid)
            If rc = 0 Then
              Set fso = CreateObject("Scripting.FileSystemObject")
              Set f = fso.CreateTextFile(a(2), True)
              f.Write pid
              f.Close
            End If
            """;
        File.WriteAllText(path, vbs);
        return path;
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

        // The intermediate process paexec runs in session 1 is wscript.exe, NOT
        // powershell.exe: wscript is a GUI-subsystem binary, so Windows never
        // allocates a console for it. powershell is console-subsystem and gets its
        // console the instant it starts — `-WindowStyle Hidden` only applies after
        // that, which is why every instance start used to flash a black window on
        // the interactive desktop. The script then creates sunshine through WMI with
        // ShowWindow=SW_HIDE so the console-subsystem sunshine.exe stays hidden too.
        var script = WriteLaunchScript(instanceId);
        var args = $"-accepteula -i {session} -w \"{workDir}\" -s " +
                   $"\"C:\\Windows\\System32\\wscript.exe\" //B //Nologo " +
                   $"\"{script}\" \"{sunshineExe}\" \"{configPath}\" \"{tmp}\" \"{workDir}\"";
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

        // Fallback: if the pid file could not be read, detect the newly spawned
        // sunshine process. Only claim when EXACTLY ONE new sunshine exists — during
        // a simultaneous fleet start several launches run at once, and guessing among
        // multiple new processes would attribute the wrong PID to this instance.
        for (var i = 0; i < 30; i++)
        {
            ct.ThrowIfCancellationRequested();
            var all = Process.GetProcessesByName("sunshine");
            try
            {
                var fresh = all.Select(p => p.Id).Where(id => !preExisting.Contains(id)).ToList();
                if (fresh.Count == 1)
                    return fresh[0];
            }
            finally
            {
                foreach (var p in all)
                    p.Dispose();
            }

            await Task.Delay(50, ct).ConfigureAwait(false);
        }

        return null;
    }
}
