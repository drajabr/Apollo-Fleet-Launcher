using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ApolloFleet.Core;
using ApolloFleet.Core.Models;

namespace ApolloFleet.App.Services;

public sealed class ProcessSupervisor : IDisposable
{
    private readonly ISettingsStore _store;
    private readonly IProcessLauncher _launcher;
    private readonly IInstanceHealthComputer _health;
    private readonly FileLogWriter _log;
    private readonly AudioVolumeSink _audio;
    private readonly ConcurrentDictionary<string, int> _restartAttempts = new(StringComparer.Ordinal);
    private Timer? _maintain;
    private Timer? _cleanup;
    private Timer? _volume;
    private volatile AppSettings? _settings;
    private volatile bool _syncVolume;

    public ProcessSupervisor(
        ISettingsStore store,
        IProcessLauncher launcher,
        IInstanceHealthComputer health,
        FileLogWriter log,
        AudioVolumeSink audio)
    {
        _store = store;
        _launcher = launcher;
        _health = health;
        _log = log;
        _audio = audio;
    }

    public void UpdateRuntimeOptions(AppSettings settings, bool syncVolume)
    {
        _settings = settings;
        _syncVolume = syncVolume;
    }

    public void Start()
    {
        _maintain ??= new Timer(_ => _ = MaintainTickAsync(), null, TimeSpan.Zero, TimeSpan.FromSeconds(5));
        _cleanup ??= new Timer(_ => CleanupTick(), null, TimeSpan.FromSeconds(3), TimeSpan.FromSeconds(10));
        _volume ??= new Timer(_ => VolumeTick(), null, TimeSpan.Zero, TimeSpan.FromSeconds(2));
    }

    public async Task RestartFleetAsync(CancellationToken cancellationToken = default)
    {
        var settings = _settings ?? await _store.LoadSettingsAsync(cancellationToken).ConfigureAwait(false);
        var state = await _store.LoadStateAsync(cancellationToken).ConfigureAwait(false);
        await StopEnabledInstancesAsync(settings, state, cancellationToken).ConfigureAwait(false);
        foreach (var id in settings.Instances.Select(i => i.Id))
            state.InstanceProcessIds[id] = 0;
        await _store.SaveStateAsync(state, cancellationToken).ConfigureAwait(false);
        await StaggerStartAsync(settings, state, cancellationToken).ConfigureAwait(false);
    }

    private async Task StopEnabledInstancesAsync(AppSettings settings, AppState state, CancellationToken ct)
    {
        foreach (var inst in settings.Instances.Where(i => i.Enabled))
        {
            if (state.InstanceProcessIds.TryGetValue(inst.Id, out var pid) && pid > 0)
                await TryStopPidAsync(pid, ct).ConfigureAwait(false);
        }
    }

    private static async Task TryStopPidAsync(int pid, CancellationToken ct)
    {
        try
        {
            using var p = Process.GetProcessById(pid);
            try
            {
                p.CloseMainWindow();
            }
            catch
            {
                /* ignore */
            }

            await Task.Delay(400, ct).ConfigureAwait(false);
            if (!p.HasExited)
            {
                try
                {
                    p.Kill(entireProcessTree: true);
                }
                catch
                {
                    /* ignore */
                }
            }
        }
        catch
        {
            /* ignore */
        }
    }

    private async Task StaggerStartAsync(AppSettings settings, AppState state, CancellationToken ct)
    {
        var sunshine = settings.Paths.SunshineExePath;
        if (string.IsNullOrEmpty(sunshine) || !File.Exists(sunshine))
            return;

        var idx = 0;
        foreach (var inst in settings.Instances.Where(i => i.Enabled))
        {
            var delay = TimeSpan.FromMilliseconds(800 * idx++);
            if (delay > TimeSpan.Zero)
                await Task.Delay(delay, ct).ConfigureAwait(false);

            var fleetDir = settings.Paths.FleetConfigDirectory;
            var conf = Path.Combine(fleetDir, inst.ConfFileName);
            if (!File.Exists(conf))
                continue;

            var pid = await _launcher
                .StartSunshineAsync(sunshine, conf, inst.Id, settings.Paths.HelperExePath, ct)
                .ConfigureAwait(false);
            if (pid is int p && p > 0)
            {
                state.InstanceProcessIds[inst.Id] = p;
                _restartAttempts[inst.Id] = 0;
                _log.Info($"Started instance {inst.Name} pid={p}");
            }
            else
            {
                _log.Info($"Failed to start instance {inst.Name} (no pid).");
            }

            await _store.SaveStateAsync(state, ct).ConfigureAwait(false);
        }
    }

    private async Task MaintainTickAsync()
    {
        try
        {
            var settings = _settings ?? await _store.LoadSettingsAsync().ConfigureAwait(false);
            var state = await _store.LoadStateAsync().ConfigureAwait(false);
            var sunshine = settings.Paths.SunshineExePath;
            if (string.IsNullOrEmpty(sunshine) || !File.Exists(sunshine))
                return;

            foreach (var inst in settings.Instances.Where(i => i.Enabled))
            {
                state.InstanceProcessIds.TryGetValue(inst.Id, out var pid);
                var alive = _health.GetProcessState(pid <= 0 ? null : pid) == InstanceRunState.Running;
                if (alive)
                    continue;

                var n = _restartAttempts.AddOrUpdate(inst.Id, _ => 1, (_, c) => c + 1);
                if (n > 8)
                    continue;

                var conf = Path.Combine(settings.Paths.FleetConfigDirectory, inst.ConfFileName);
                if (!File.Exists(conf))
                    continue;

                var newPid = await _launcher
                    .StartSunshineAsync(sunshine, conf, inst.Id, settings.Paths.HelperExePath)
                    .ConfigureAwait(false);
                if (newPid is int p && p > 0)
                {
                    state.InstanceProcessIds[inst.Id] = p;
                    _restartAttempts[inst.Id] = 0;
                    _log.Info($"Supervisor restarted {inst.Name} pid={p} (attempt {n})");
                    await _store.SaveStateAsync(state).ConfigureAwait(false);
                }
            }
        }
        catch
        {
            /* ignore */
        }
    }

    private void CleanupTick()
    {
        try
        {
            var settings = _settings;
            if (settings is null)
                return;

            _ = Task.Run(async () =>
            {
                var state = await _store.LoadStateAsync().ConfigureAwait(false);
                var keep = new HashSet<int>();
                foreach (var inst in settings.Instances.Where(i => i.Enabled))
                {
                    if (state.InstanceProcessIds.TryGetValue(inst.Id, out var pid) && pid > 0)
                        keep.Add(pid);
                }

                foreach (var p in Process.GetProcessesByName("sunshine"))
                {
                    try
                    {
                        if (!keep.Contains(p.Id))
                            p.Kill(entireProcessTree: true);
                    }
                    catch
                    {
                        /* ignore */
                    }
                    finally
                    {
                        p.Dispose();
                    }
                }

                PruneOrphanFleetFiles(settings, state);
            });
        }
        catch
        {
            /* ignore */
        }
    }

    private static void PruneOrphanFleetFiles(AppSettings settings, AppState state)
    {
        var dir = settings.Paths.FleetConfigDirectory;
        if (string.IsNullOrWhiteSpace(dir) || !Directory.Exists(dir))
            return;

        var keep = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var inst in settings.Instances)
        {
            keep.Add(Path.Combine(dir, inst.ConfFileName));
            keep.Add(Path.Combine(dir, inst.AppsFileName));
            keep.Add(Path.Combine(dir, inst.LogFileName));
            keep.Add(Path.Combine(dir, inst.StateFileName));
        }

        foreach (var f in Directory.EnumerateFiles(dir))
        {
            if (keep.Contains(f))
                continue;
            var name = Path.GetFileName(f);
            if (!name.StartsWith("fleet-", StringComparison.OrdinalIgnoreCase)
                && !name.StartsWith("apps-", StringComparison.OrdinalIgnoreCase)
                && !name.StartsWith("state-", StringComparison.OrdinalIgnoreCase))
                continue;
            try
            {
                File.Delete(f);
            }
            catch
            {
                /* ignore */
            }
        }
    }

    private void VolumeTick()
    {
        if (!_syncVolume)
            return;
        var settings = _settings;
        if (settings is null)
            return;

        _ = Task.Run(async () =>
        {
            var state = await _store.LoadStateAsync().ConfigureAwait(false);
            var pids = new List<int>();
            foreach (var inst in settings.Instances.Where(i => i.Enabled))
            {
                if (state.InstanceProcessIds.TryGetValue(inst.Id, out var pid) && pid > 0)
                    pids.Add(pid);
            }

            _audio.SyncPlaybackToSessions(pids);
        });
    }

    public void Dispose()
    {
        _maintain?.Dispose();
        _cleanup?.Dispose();
        _volume?.Dispose();
    }
}
