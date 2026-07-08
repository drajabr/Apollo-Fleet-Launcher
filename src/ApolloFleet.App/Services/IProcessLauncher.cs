namespace ApolloFleet.App.Services;

public interface IProcessLauncher
{
    Task<int?> StartSunshineAsync(string sunshineExePath, string configPath, string instanceId, string? helperExePath, CancellationToken cancellationToken = default);
}
