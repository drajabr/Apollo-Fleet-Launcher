namespace ApolloFleet.Core;

/// <summary>
/// States of the single self-update button. The UI derives its label, tooltip and
/// enabled-ness entirely from this phase, so there is one source of truth for
/// "what is the updater doing right now".
/// </summary>
public enum UpdatePhase
{
    /// <summary>No check has run yet this session.</summary>
    Idle,

    /// <summary>Querying the GitHub releases API.</summary>
    Checking,

    /// <summary>The running build is the latest release.</summary>
    UpToDate,

    /// <summary>A newer release exists and is ready to download.</summary>
    UpdateAvailable,

    /// <summary>The installer is being downloaded (see DownloadPercent).</summary>
    Downloading,

    /// <summary>The installer is on disk and verified; ready to run.</summary>
    ReadyToInstall,

    /// <summary>Setup has been launched; the app is exiting. Terminal.</summary>
    Installing,

    /// <summary>The last operation failed (see ErrorMessage). Clicking retries.</summary>
    Error
}
