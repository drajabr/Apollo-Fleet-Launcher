using System.Collections.ObjectModel;

namespace ApolloFleet.Core.Models;

public sealed class AppSettings
{
    public int SchemaVersion { get; set; } = 1;

    public string Locale { get; set; } = "";

    public ManagerOptions Manager { get; set; } = new();

    public PathOptions Paths { get; set; } = new();

    public ObservableCollection<FleetInstance> Instances { get; set; } = new();

    public static AppSettings CreateDefault()
    {
        var s = new AppSettings();
        s.Instances.Add(new FleetInstance { Name = "Instance 1", Port = 47990, Enabled = true });
        return s;
    }
}
