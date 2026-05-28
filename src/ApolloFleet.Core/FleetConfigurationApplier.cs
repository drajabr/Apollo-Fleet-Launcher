using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public sealed class FleetConfigurationApplier : IFleetConfigurationApplier
{
    private readonly ConfFileService _conf = new();
    private readonly AppsJsonService _apps = new();

    public Task ApplyAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        var fleetDir = settings.Paths.FleetConfigDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (string.IsNullOrWhiteSpace(fleetDir))
            throw new InvalidOperationException("Fleet config directory is not set.");

        Directory.CreateDirectory(fleetDir);
        var terminate = settings.Manager.RemoveOnDisconnect;

        foreach (var instance in settings.Instances)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var confPath = Path.Combine(fleetDir, instance.ConfFileName);
            var existingConf = File.Exists(confPath) ? File.ReadAllText(confPath) : null;
            var desired = _conf.BuildDesiredMap(instance, settings.Paths);
            var confText = _conf.MergeAndFormat(existingConf, desired, instance);
            AtomicFileWriter.WriteText(confPath, confText);

            var appsPath = Path.Combine(fleetDir, instance.AppsFileName);
            var existingApps = File.Exists(appsPath) ? File.ReadAllText(appsPath) : null;
            var appsText = _apps.EnsureDesktopAndBooleans(existingApps, terminate);
            AtomicFileWriter.WriteText(appsPath, appsText);

            // Apollo expects credentials_file / file_state to be openable on launch.
            // Seed an empty JSON object so sunshine.exe doesn't terminate with boost::system_error
            // ("File ... doesn't exist") on a fresh fleet before the WebUI has written credentials.
            var statePath = Path.Combine(fleetDir, instance.StateFileName);
            if (!File.Exists(statePath))
                AtomicFileWriter.WriteText(statePath, "{}\n");
        }

        return Task.CompletedTask;
    }
}
