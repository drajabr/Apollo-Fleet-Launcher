using System;
using System.Collections.Generic;
using System.IO;
using Microsoft.Win32;

namespace ApolloFleet.App.Services;

/// <summary>
/// Best-effort discovery of an existing Apollo install so a fresh launcher can
/// detect it automatically instead of showing the "Apollo missing" warning until
/// the user browses for it. Returns the folder that directly contains sunshine.exe.
/// </summary>
public static class ApolloLocator
{
    private const string SunshineExe = "sunshine.exe";

    public static string? TryFindApolloRoot()
    {
        foreach (var root in EnumerateCandidateRoots())
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(root) &&
                    File.Exists(Path.Combine(root, SunshineExe)))
                {
                    return root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                }
            }
            catch
            {
                /* ignore malformed candidate */
            }
        }

        return null;
    }

    private static IEnumerable<string> EnumerateCandidateRoots()
    {
        // 1. The installed ApolloService points straight at the binary:
        //    ...\Apollo\tools\sunshinesvc.exe  ->  root is two levels up.
        var svc = RootFromServiceImagePath();
        if (svc is not null)
            yield return svc;

        // 2. Uninstall registry entries whose DisplayName mentions Apollo.
        foreach (var loc in RootsFromUninstallKeys())
            yield return loc;

        // 3. Conventional install locations.
        foreach (var env in new[] { "ProgramW6432", "ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA" })
        {
            var b = Environment.GetEnvironmentVariable(env);
            if (string.IsNullOrWhiteSpace(b))
                continue;
            yield return Path.Combine(b, "Apollo");
            if (env == "LOCALAPPDATA")
                yield return Path.Combine(b, "Programs", "Apollo");
        }
    }

    private static string? RootFromServiceImagePath()
    {
        try
        {
            using var key = Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Services\ApolloService");
            if (key?.GetValue("ImagePath") is not string raw || string.IsNullOrWhiteSpace(raw))
                return null;

            var exe = raw.Trim().Trim('"');
            // ImagePath may carry arguments after the exe; keep up to ".exe".
            var idx = exe.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
            if (idx > 0)
                exe = exe[..(idx + 4)];

            // ...\Apollo\tools\sunshinesvc.exe -> ...\Apollo
            var toolsDir = Path.GetDirectoryName(exe);
            var root = Path.GetDirectoryName(toolsDir);
            return root;
        }
        catch
        {
            return null;
        }
    }

    private static IEnumerable<string> RootsFromUninstallKeys()
    {
        var hives = new (RegistryKey Hive, string Path)[]
        {
            (Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
            (Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
            (Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
        };

        foreach (var (hive, path) in hives)
        {
            RegistryKey? uninstall = null;
            try { uninstall = hive.OpenSubKey(path); }
            catch { /* ignore */ }
            if (uninstall is null)
                continue;

            using (uninstall)
            {
                string[] subs;
                try { subs = uninstall.GetSubKeyNames(); }
                catch { continue; }

                foreach (var sub in subs)
                {
                    string? loc = null;
                    try
                    {
                        using var app = uninstall.OpenSubKey(sub);
                        var name = app?.GetValue("DisplayName") as string;
                        if (name is not null && name.Contains("Apollo", StringComparison.OrdinalIgnoreCase))
                            loc = app?.GetValue("InstallLocation") as string;
                    }
                    catch { /* ignore */ }

                    if (!string.IsNullOrWhiteSpace(loc))
                        yield return loc!;
                }
            }
        }
    }
}
