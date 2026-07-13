using System.Text.Json;
using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

/// <summary>
/// One-time migration of the pre-v0.4.4 portable config (<c>&lt;exeDir&gt;\config</c>)
/// into the current machine-wide location (<c>%ProgramData%\ApolloFleet</c>).
///
/// The v0.4.4 storage move shipped with no data migration, so upgraders' real
/// configuration — including each instance's <c>Id</c> and therefore its TLS
/// cert/key and paired-client state (<c>state-{Id}.json</c>) — was stranded in the
/// install folder while the app wrote a fresh single-instance default. Losing the
/// <c>Id</c> is what forces users to re-pair every device.
///
/// This copies the legacy tree forward, preserving instance <c>Id</c>s (and thus the
/// existing per-instance pairing files), and leaves the legacy folder untouched as a
/// backup. It runs at most once (guarded by a marker) and never overwrites a config
/// the user has already built in the new location beyond taking a <c>.prelegacy</c>
/// safety copy.
/// </summary>
public static class LegacyConfigMigrator
{
    /// <summary>The pre-v0.4.4 portable root: a <c>config</c> folder next to the exe.</summary>
    public static string DefaultLegacyRoot => Path.Combine(AppStoragePaths.BaseDirectory, "config");

    /// <summary>
    /// Migrates legacy config into the current location if needed. Returns true when a
    /// migration was performed; <paramref name="message"/> always carries a human-readable
    /// outcome (including the no-op / failure reason) for logging.
    /// </summary>
    public static bool TryMigrate(out string message)
        => TryMigrate(DefaultLegacyRoot, AppStoragePaths.RootDirectory, out message);

    /// <summary>
    /// Core migration keyed off explicit roots so it can be exercised in tests without
    /// touching %ProgramData% or the install folder. Per-file names mirror
    /// <see cref="AppStoragePaths"/> exactly.
    /// </summary>
    internal static bool TryMigrate(string legacyRoot, string newRoot, out string message)
    {
        var legacySettings = Path.Combine(legacyRoot, "settings.json");
        var legacyState = Path.Combine(legacyRoot, "state.json");
        var legacyFleet = Path.Combine(legacyRoot, "fleet");
        var newSettings = Path.Combine(newRoot, "settings.json");
        var newState = Path.Combine(newRoot, "state.json");
        var newFleet = Path.Combine(newRoot, "fleet");
        var marker = Path.Combine(newRoot, ".legacy-migrated");

        try
        {
            // Already handled once — never touch the user's data again.
            if (File.Exists(marker))
            {
                message = "Legacy config migration: already done (marker present).";
                return false;
            }

            // No legacy data → this is a genuine fresh install, nothing to migrate.
            if (!File.Exists(legacySettings))
            {
                message = "Legacy config migration: no legacy config found; skipping.";
                return false;
            }

            // Portable run from the same folder the new layout resolves to: nothing to do.
            if (PathsEqual(legacyRoot, newRoot))
            {
                message = "Legacy config migration: legacy and current roots are the same; skipping.";
                return false;
            }

            // The current location may already hold real, in-use config — e.g. a user who
            // paired devices on a v0.4.4–v0.4.6 build (storage was already %ProgramData%)
            // and still has a leftover pre-0.4.4 <exeDir>\config. Never overwrite that with
            // the stale legacy copy. A fresh single-instance default (what the bug produced)
            // has no pairings and is safe to replace. Mark done so we don't rescan forever.
            if (NewLocationHasRealData(newSettings, newFleet))
            {
                Directory.CreateDirectory(newRoot);
                File.WriteAllText(marker, $"Kept existing config; legacy at \"{legacyRoot}\" left untouched on {DateTime.Now:O}\n");
                message = $"Legacy config found at \"{legacyRoot}\" but the current location already holds real config/pairings; kept the current config.";
                return false;
            }

            Directory.CreateDirectory(newRoot);

            // Keep whatever default the new version may already have written, so the
            // migration is reversible even after the user has launched the new build once.
            if (File.Exists(newSettings))
                TryCopyFile(newSettings, newSettings + ".prelegacy", overwrite: true);

            // Bring the per-instance fleet files (TLS cert/key + paired-client state).
            // Filenames are keyed by instance Id, so they never collide with a
            // freshly-generated default instance; copy without clobbering newer files.
            if (Directory.Exists(legacyFleet))
                CopyDirectory(legacyFleet, newFleet, overwrite: false);

            // Runtime state (window placement, log-pane, last PIDs) — only if absent.
            if (File.Exists(legacyState) && !File.Exists(newState))
                TryCopyFile(legacyState, newState, overwrite: false);

            MigrateSettings(legacySettings, newSettings, newFleet);

            File.WriteAllText(marker, $"Migrated from \"{legacyRoot}\" on {DateTime.Now:O}\n");
            message = $"Migrated existing configuration from \"{legacyRoot}\" to \"{newRoot}\" (instance IDs and pairings preserved).";
            return true;
        }
        catch (Exception ex)
        {
            message = $"Legacy config migration failed: {ex.Message}";
            return false;
        }
    }

    /// <summary>
    /// Copies the legacy settings forward, rewriting the fleet-config directory to the
    /// new location when it was unset or still pointed at the legacy fleet folder, so the
    /// app reads the freshly-migrated files rather than the stale install-folder path.
    /// </summary>
    private static void MigrateSettings(string legacySettings, string newSettings, string newFleet)
    {
        var json = File.ReadAllText(legacySettings);
        AppSettings? settings;
        try
        {
            settings = JsonSerializer.Deserialize<AppSettings>(json, SettingsJson.Options);
        }
        catch
        {
            settings = null;
        }

        if (settings is null)
        {
            // Unparseable — copy raw so nothing is lost; the app falls back to defaults
            // in memory but the original bytes are preserved at the new location.
            TryCopyFile(legacySettings, newSettings, overwrite: true);
            return;
        }

        // Point the fleet at the migrated copies rather than the stale install-folder path.
        settings.Paths.FleetConfigDirectory = newFleet;

        var outJson = JsonSerializer.Serialize(settings, SettingsJson.Options);
        AtomicFileWriter.WriteText(newSettings, outJson);

        // Rewrite each per-instance .conf so its cert/pkey/state/log paths point at the
        // new fleet dir (the cert/key/state files were copied there above). Without this
        // the migrated .conf still references <exeDir>\config\fleet, so pairing writes go
        // to the old location and a later Apply or uninstall would strand them. The applier
        // merges into the copied .conf and only seeds an empty state when one is missing,
        // so existing pairings are preserved. Best-effort: on failure the copied .conf's
        // original (legacy) paths still resolve to the intact legacy files.
        try
        {
            new FleetConfigurationApplier().ApplyAsync(settings).GetAwaiter().GetResult();
        }
        catch
        {
            /* leave the copied .conf as-is; it still points at the (intact) legacy files */
        }
    }

    /// <summary>
    /// True when the current storage location already holds real user config we must not
    /// clobber: more than one instance, or any per-instance state file carrying actual
    /// paired-client data (beyond the empty <c>{}</c> object the applier seeds).
    /// </summary>
    private static bool NewLocationHasRealData(string newSettings, string newFleet)
    {
        try
        {
            if (!File.Exists(newSettings))
                return false;

            var s = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(newSettings), SettingsJson.Options);
            if (s is null)
                return false;
            if (s.Instances.Count > 1)
                return true;

            if (Directory.Exists(newFleet))
            {
                foreach (var f in Directory.EnumerateFiles(newFleet, "state-*.json"))
                {
                    if (HasPairingContent(f))
                        return true;
                }
            }

            return false;
        }
        catch
        {
            // If we can't tell, assume there IS real data — refusing to migrate is the
            // safe failure (never destroys), at worst leaving the user to migrate manually.
            return true;
        }
    }

    private static bool HasPairingContent(string stateFile)
    {
        try
        {
            var content = File.ReadAllText(stateFile);
            var stripped = content.Replace(" ", "").Replace("\t", "").Replace("\r", "").Replace("\n", "");
            return stripped.Length > 0 && stripped != "{}";
        }
        catch
        {
            return false;
        }
    }

    private static void CopyDirectory(string sourceDir, string destDir, bool overwrite)
    {
        Directory.CreateDirectory(destDir);
        foreach (var file in Directory.EnumerateFiles(sourceDir))
        {
            var dest = Path.Combine(destDir, Path.GetFileName(file));
            TryCopyFile(file, dest, overwrite);
        }

        foreach (var sub in Directory.EnumerateDirectories(sourceDir))
            CopyDirectory(sub, Path.Combine(destDir, Path.GetFileName(sub)), overwrite);
    }

    private static void TryCopyFile(string source, string dest, bool overwrite)
    {
        try
        {
            if (!overwrite && File.Exists(dest))
                return;
            var dir = Path.GetDirectoryName(dest);
            if (!string.IsNullOrEmpty(dir))
                Directory.CreateDirectory(dir);
            File.Copy(source, dest, overwrite);
        }
        catch
        {
            /* best effort — a single file that can't be copied must not abort the migration */
        }
    }

    private static bool PathsEqual(string a, string b)
    {
        try
        {
            return string.Equals(
                Path.GetFullPath(a).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
                Path.GetFullPath(b).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
                StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }
}
