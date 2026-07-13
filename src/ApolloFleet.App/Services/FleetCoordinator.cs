using System;
using System.IO;
using System.Linq;
using ApolloFleet.Core;
using ApolloFleet.Core.Models;

namespace ApolloFleet.App.Services;

public sealed class FleetCoordinator
{
    private readonly ISettingsStore _store;
    private readonly IFleetConfigurationApplier _applier;
    private readonly ProcessSupervisor _supervisor;
    private readonly WinUiScheduledTaskService _tasks;
    private readonly WindowsServiceFacade _windowsSvc;
    private readonly FileLogWriter _log;

    public FleetCoordinator(
        ISettingsStore store,
        IFleetConfigurationApplier applier,
        ProcessSupervisor supervisor,
        WinUiScheduledTaskService tasks,
        WindowsServiceFacade windowsSvc,
        FileLogWriter log)
    {
        _store = store;
        _applier = applier;
        _supervisor = supervisor;
        _tasks = tasks;
        _windowsSvc = windowsSvc;
        _log = log;
    }

    public async Task ApplyAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        var pv = PortValidator.ValidateFleet(settings.Instances);
        if (pv == PortValidationKind.OutOfRange)
            throw new InvalidOperationException("PortValidation_OutOfRange");
        if (pv == PortValidationKind.Duplicate)
            throw new InvalidOperationException("PortValidation_Duplicate");
        if (pv == PortValidationKind.TooClose)
            throw new InvalidOperationException("PortValidation_TooClose");

        await _store.SaveSettingsAsync(settings, false, cancellationToken).ConfigureAwait(false);
        await _applier.ApplyAsync(settings, cancellationToken).ConfigureAwait(false);
        _supervisor.UpdateRuntimeOptions(settings, settings.Manager.SyncVolume);
        await _supervisor.RestartFleetAsync(cancellationToken).ConfigureAwait(false);
        ApplyAutostart(settings);
        _log.Info("Apply completed.");
    }

    /// <summary>
    /// Generate the per-instance fleet config (.conf/apps/state/cert paths) when it's
    /// missing, so the supervisor can start instances on a fresh install without a
    /// manual Apply. The applier merges into any existing files, so this is idempotent
    /// and preserves user edits; it only runs when a config is actually absent.
    /// </summary>
    public async Task EnsureFleetConfigAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        try
        {
            var sunshine = settings.Paths.SunshineExePath;
            if (string.IsNullOrEmpty(sunshine) || !File.Exists(sunshine))
                return;

            var dir = settings.Paths.FleetConfigDirectory;
            if (string.IsNullOrWhiteSpace(dir))
                return;

            var anyMissing = settings.Instances
                .Where(i => i.Enabled)
                .Any(i => !File.Exists(Path.Combine(dir, i.ConfFileName)));
            if (!anyMissing)
                return;

            await _applier.ApplyAsync(settings, cancellationToken).ConfigureAwait(false);
            _log.Info("Generated missing fleet configuration so instances can start.");
        }
        catch (Exception ex)
        {
            _log.Info($"Ensure fleet config failed: {ex.Message}");
        }
    }

    /// <summary>
    /// At startup, ensure the stock ApolloService is stopped/disabled when Auto Run
    /// is enabled. Apply already does this, but the service can be re-enabled out of
    /// band (e.g. an Apollo update); if it runs it keeps respawning its own sunshine
    /// that the fleet supervisor then kills, causing a restart loop.
    /// </summary>
    public void EnforceStockServiceState(AppSettings settings)
    {
        try
        {
            if (settings.Manager.AutoStart && _windowsSvc.IsApolloServiceInstalled())
            {
                if (_windowsSvc.DisableAndStopApolloService())
                    _log.Info("Auto Run enabled: ensured the stock ApolloService is disabled.");
                else
                    _log.Warn("Auto Run enabled but the stock ApolloService could not be stopped/disabled gracefully; the fleet will not force-kill its sunshine to avoid a restart loop.");
            }
        }
        catch (Exception ex)
        {
            _log.Info($"Stock service enforcement failed: {ex.Message}");
        }
    }

    private void ApplyAutostart(AppSettings settings)
    {
        var exe = Environment.ProcessPath ?? "";
        if (string.IsNullOrEmpty(exe))
            return;

        try
        {
            if (settings.Manager.AutoStart)
            {
                if (_windowsSvc.IsApolloServiceInstalled() && !_windowsSvc.DisableAndStopApolloService())
                    _log.Warn("Could not stop/disable the stock ApolloService gracefully; leaving its sunshine alone to avoid a restart loop.");
                _tasks.Sync(true, exe);
            }
            else
            {
                _tasks.Sync(false, exe);
                if (_windowsSvc.IsApolloServiceInstalled())
                    _windowsSvc.EnableAndStartApolloService();
            }
        }
        catch (Exception ex)
        {
            _log.Info($"Autostart/service sync failed: {ex.Message}");
        }
    }
}
