using System.Collections.ObjectModel;
using System.Text.Json;
using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public sealed class SettingsStore : ISettingsStore
{
    public async Task<AppSettings> LoadSettingsAsync(CancellationToken cancellationToken = default)
    {
        var path = AppStoragePaths.SettingsPath;
        if (!File.Exists(path))
            return AppSettings.CreateDefault();

        await using var fs = File.OpenRead(path);
        var s = await JsonSerializer.DeserializeAsync<AppSettings>(fs, SettingsJson.Options, cancellationToken).ConfigureAwait(false);
        if (s is null)
            return AppSettings.CreateDefault();

        s.Manager ??= new ManagerOptions();
        s.Paths ??= new PathOptions();
        s.Instances ??= new ObservableCollection<FleetInstance>();

        if (s.Instances.Count == 0)
            s.Instances.Add(new FleetInstance { Name = "Instance 1", Port = 47990, Enabled = true });

        return s;
    }

    public async Task SaveSettingsAsync(AppSettings settings, bool allowEmptyFleetOverwrite = false, CancellationToken cancellationToken = default)
    {
        if (settings.Instances.Count == 0)
        {
            var hadFleet = false;
            if (File.Exists(AppStoragePaths.SettingsPath))
            {
                try
                {
                    var prev = await LoadSettingsAsync(cancellationToken).ConfigureAwait(false);
                    hadFleet = prev.Instances.Count > 0;
                }
                catch
                {
                    hadFleet = true;
                }
            }

            if (hadFleet && !allowEmptyFleetOverwrite)
                throw new SettingsValidationException("Refusing to save an empty fleet while a non-empty fleet existed.");
        }

        var json = JsonSerializer.Serialize(settings, SettingsJson.Options);
        await AtomicFileWriter.WriteTextAsync(AppStoragePaths.SettingsPath, json, cancellationToken).ConfigureAwait(false);
    }

    // Serializes all runtime-state file access (reads, writes, and read-modify-write)
    // so the supervisor's timers and the UI can't corrupt or clobber state.json.
    private readonly SemaphoreSlim _stateGate = new(1, 1);

    public async Task<AppState> LoadStateAsync(CancellationToken cancellationToken = default)
    {
        await _stateGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            return await LoadStateNoLockAsync(cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _stateGate.Release();
        }
    }

    public async Task SaveStateAsync(AppState state, CancellationToken cancellationToken = default)
    {
        await _stateGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await SaveStateNoLockAsync(state, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _stateGate.Release();
        }
    }

    public async Task UpdateStateAsync(Action<AppState> mutate, CancellationToken cancellationToken = default)
    {
        await _stateGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var state = await LoadStateNoLockAsync(cancellationToken).ConfigureAwait(false);
            mutate(state);
            await SaveStateNoLockAsync(state, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _stateGate.Release();
        }
    }

    private static async Task<AppState> LoadStateNoLockAsync(CancellationToken cancellationToken)
    {
        var path = AppStoragePaths.StatePath;
        if (!File.Exists(path))
            return new AppState();

        try
        {
            await using var fs = File.OpenRead(path);
            var st = await JsonSerializer.DeserializeAsync<AppState>(fs, SettingsJson.Options, cancellationToken).ConfigureAwait(false);
            return st ?? new AppState();
        }
        catch (IOException)
        {
            // A concurrent replace can briefly lock the file; treat as empty rather than throw.
            return new AppState();
        }
    }

    private static async Task SaveStateNoLockAsync(AppState state, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(state, SettingsJson.Options);
        await AtomicFileWriter.WriteTextAsync(AppStoragePaths.StatePath, json, cancellationToken).ConfigureAwait(false);
    }
}
