namespace ApolloFleet.Core;

/// <summary>
/// Machine-wide storage layout: everything lives under <c>%ProgramData%\ApolloFleet</c>.
/// The launcher is an all-users, always-elevated app that manages machine-wide Apollo
/// instances, so its settings/state/logs belong in the standard shared data location —
/// not under Program Files (where an installed app should not write) and not per-user.
/// </summary>
public static class AppStoragePaths
{
    public const string AppFolderName = "ApolloFleet";

    /// <summary>Directory containing the executable (used for bundled assets like i18n).</summary>
    public static string BaseDirectory =>
        AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

    /// <summary>Machine-wide root: <c>%ProgramData%\ApolloFleet</c>.</summary>
    public static string RootDirectory =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            AppFolderName);

    public static string SettingsPath => Path.Combine(RootDirectory, "settings.json");

    public static string StatePath => Path.Combine(RootDirectory, "state.json");

    public static string LogsDirectory => Path.Combine(RootDirectory, "logs");

    public static string SupervisorLogPath => Path.Combine(LogsDirectory, "supervisor.log");

    /// <summary>Default fleet config directory (sunshine .conf / apps / state files).</summary>
    public static string FleetDirectory => Path.Combine(RootDirectory, "fleet");
}
