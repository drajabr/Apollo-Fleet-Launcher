namespace ApolloFleet.Core;

/// <summary>
/// Portable storage layout: everything lives in a <c>config</c> folder next to the running executable
/// (<c>&lt;exeDir&gt;\config</c>) so the launcher can be moved/copied without losing its data.
/// </summary>
public static class AppStoragePaths
{
    public const string ConfigFolderName = "config";

    /// <summary>Directory containing the executable.</summary>
    public static string BaseDirectory =>
        AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

    /// <summary>Portable root: <c>&lt;exeDir&gt;\config</c>.</summary>
    public static string RootDirectory =>
        Path.Combine(BaseDirectory, ConfigFolderName);

    public static string SettingsPath => Path.Combine(RootDirectory, "settings.json");

    public static string StatePath => Path.Combine(RootDirectory, "state.json");

    public static string LogsDirectory => Path.Combine(RootDirectory, "logs");

    public static string SupervisorLogPath => Path.Combine(LogsDirectory, "supervisor.log");

    /// <summary>Default fleet config directory (sunshine .conf / apps / state files).</summary>
    public static string FleetDirectory => Path.Combine(RootDirectory, "fleet");
}
