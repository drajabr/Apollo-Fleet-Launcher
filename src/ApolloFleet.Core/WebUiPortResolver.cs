namespace ApolloFleet.Core;

/// <summary>
/// Resolves the HTTPS port used by Apollo’s Web UI for a given streaming/config port.
/// Matches legacy Apollo Fleet Launcher behavior (streaming port + 1 for https://localhost).
/// </summary>
public static class WebUiPortResolver
{
    public static int GetHttpsPort(int streamingOrConfigPort) => streamingOrConfigPort + 1;

    public static string GetWebUiUrl(int streamingOrConfigPort) =>
        $"https://localhost:{GetHttpsPort(streamingOrConfigPort)}";
}
