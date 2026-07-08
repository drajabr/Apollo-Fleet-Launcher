namespace ApolloFleet.Core.Models;

public sealed class AppState
{
    public int SchemaVersion { get; set; } = 1;

    public Dictionary<string, int> InstanceProcessIds { get; set; } = new(StringComparer.Ordinal);

    public bool LogPaneOpen { get; set; }

    public double? WindowX { get; set; }

    public double? WindowY { get; set; }

    public double? WindowWidth { get; set; }

    public double? WindowHeight { get; set; }
}
