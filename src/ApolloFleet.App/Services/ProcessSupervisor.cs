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
    private readonly ConcurrentDictionary<string, DateTime> _lastStartUtc = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, byte> _warnedNoConf = new(StringComparer.Ordinal);
    // Serializes maintain / cleanup / fleet-restart so they never race each other:
    // cleanup must not kill a pid that maintain started but has not persisted yet,
    // and overlapping maintain ticks must not double-start the same instance.
    private readonly SemaphoreSlim _mutex = new(1, 1);
    private Timer? _maintain;
    private Timer? _cleanup;
    private Timer? _volume;
    private volatile AppSettings? _settings;
    private volatile bool _syncVolume;
    private volatile bool _stopping;

    private const int MaxRestartAttempts = 8;
    private static readonly TimeSpan StableUptime = TimeSpan.FromSeconds(60);

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
        _cleanup ??= new Timer(_ => _ = CleanupTickAsync(), null, TimeSpan.FromSeconds(3), TimeSpan.FromSeconds(10));
        _volume ??= new Timer(_ => VolumeTick(), null, TimeSpan.Zero, TimeSpan.FromSeconds(2));
    }

    public async Task RestartFleetAsync(CancellationToken cancellationToken = default)
    {
        await _mutex.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var settings = _settings ?? await _store.LoadSettingsAsync(cancellationToken).ConfigureAwait(false);
            var state = await _store.LoadStateAsync(cancellationToken).ConfigureAwait(false);
            await StopEnabledInstancesAsync(settings, state, cancellationToken).ConfigureAwait(false);
            await _store.UpdateStateAsync(st =>
            {
                foreach (var id in settings.Instances.Select(i => i.Id))
                    st.InstanceProcessIds[id] = 0;
            }, cancellationToken).ConfigureAwait(false);
            await StaggerStartAsync(settings, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _mutex.Release();
        }
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

    private async Task StaggerStartAsync(AppSettings settings, CancellationToken ct)
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
                _restartAttempts[inst.Id] = 0;
                _lastStartUtc[inst.Id] = DateTime.UtcNow;
                await _store.UpdateStateAsync(st => st.InstanceProcessIds[inst.Id] = p, ct).ConfigureAwait(false);
                _log.Info($"Started instance {inst.Name} pid={p}");
            }
            else
            {
                _log.Info($"Failed to start instance {inst.Name} (no pid).");
            }
        }
    }

    private async Task MaintainTickAsync()
    {
        if (_stopping)
            return;
        if (!await _mutex.WaitAsync(0).ConfigureAwait(false))
            return; // a maintain/cleanup/restart pass is already running

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
                {
                    // Only sustained uptime clears the backoff counter; resetting on
                    // start would let a crash-looping instance restart forever.
                    if (_restartAttempts.TryGetValue(inst.Id, out var a) && a > 0
                        && _lastStartUtc.TryGetValue(inst.Id, out var startedAt)
                        && DateTime.UtcNow - startedAt >= StableUptime)
                    {
                        _restartAttempts[inst.Id] = 0;
                    }
                    continue;
                }

                // Missing config means the fleet was never applied (or was applied
                // under the old storage location). Warn once — don't count it as a
                // crash, or the retry cap trips without a single launch attempt.
                var conf = Path.Combine(settings.Paths.FleetConfigDirectory, inst.ConfFileName);
                if (!File.Exists(conf))
                {
                    if (_warnedNoConf.TryAdd(inst.Id, 1))
                        _log.Warn($"Instance {inst.Name}: no fleet config found at {conf}. Unlock and click Apply to generate it and start the instance.");
                    continue;
                }
                _warnedNoConf.TryRemove(inst.Id, out _);

                var n = _restartAttempts.AddOrUpdate(inst.Id, _ => 1, (_, c) => c + 1);
                if (n > MaxRestartAttempts)
                {
                    if (n == MaxRestartAttempts + 1)
                        _log.Warn($"Instance {inst.Name} keeps exiting; giving up after {MaxRestartAttempts} restart attempts (re-apply settings to retry).");
                    continue;
                }

                var newPid = await _launcher
                    .StartSunshineAsync(sunshine, conf, inst.Id, settings.Paths.HelperExePath)
                    .ConfigureAwait(false);
                if (newPid is null)
                    _log.Warn($"Instance {inst.Name}: launcher returned no PID (attempt {n}).");
                if (newPid is int p && p > 0)
                {
                    state.InstanceProcessIds[inst.Id] = p;
                    _lastStartUtc[inst.Id] = DateTime.UtcNow;
                    _log.Info($"Supervisor restarted {inst.Name} pid={p} (attempt {n})");
                    await _store.UpdateStateAsync(st => st.InstanceProcessIds[inst.Id] = p).ConfigureAwait(false);
                }
            }
        }
        catch
        {
            /* ignore */
        }
        finally
        {
            _mutex.Release();
        }
    }

    private async Task CleanupTickAsync()
    {
        if (_stopping)
            return;
        var settings = _settings;
        if (settings is null)
            return;

        if (!await _mutex.WaitAsync(0).ConfigureAwait(false))
            return; // never sweep while instances are being (re)started

        try
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
        }
        catch
        {
            /* ignore */
        }
        finally
        {
            _mutex.Release();
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
            keep.Add(Path.Combine(dir, inst.CertFileName));
            keep.Add(Path.Combine(dir, inst.KeyFileName));
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

    /// <summary>
    /// Stops the timers and all enabled fleet instances. Called on a real app exit
    /// (tray Exit) — NOT on a reload, where instances are intentionally left running
    /// for the incoming process to adopt.
    /// </summary>
    public async Task StopAllInstancesAsync(CancellationToken cancellationToken = default)
    {
        _stopping = true;
        _maintain?.Dispose(); _maintain = null;
        _cleanup?.Dispose(); _cleanup = null;
        _volume?.Dispose(); _volume = null;

        await _mutex.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var settings = _settings ?? await _store.LoadSettingsAsync(cancellationToken).ConfigureAwait(false);
            var state = await _store.LoadStateAsync(cancellationToken).ConfigureAwait(false);
            await StopEnabledInstancesAsync(settings, state, cancellationToken).ConfigureAwait(false);
            await _store.UpdateStateAsync(st =>
            {
                foreach (var id in settings.Instances.Select(i => i.Id))
                    st.InstanceProcessIds[id] = 0;
            }, cancellationToken).ConfigureAwait(false);
            _log.Info("Fleet stopped on exit.");
        }
        finally
        {
            _mutex.Release();
        }
    }

    public void Dispose()
    {
        _maintain?.Dispose();
        _cleanup?.Dispose();
        _volume?.Dispose();
        _mutex.Dispose();
    }
}
