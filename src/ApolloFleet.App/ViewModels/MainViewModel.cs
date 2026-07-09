using System.Collections.Specialized;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using ApolloFleet.App.Services;
using ApolloFleet.Core;
using ApolloFleet.Core.Models;

namespace ApolloFleet.App.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly ISettingsStore _store;
    private readonly FleetCoordinator _coordinator;
    private readonly ProcessSupervisor _supervisor;
    private readonly IInstanceHealthComputer _health;
    private readonly FileLogWriter _log;
    private IReadOnlyList<LanguageOption> _availableLanguages = Array.Empty<LanguageOption>();

    private string _snapshotJson = "";
    private Window? _window;
    private AppSettings _draft = AppSettings.CreateDefault();

    public MainViewModel(
        ISettingsStore store,
        FleetCoordinator coordinator,
        ProcessSupervisor supervisor,
        IInstanceHealthComputer health,
        FileLogWriter log)
    {
        _store = store;
        _coordinator = coordinator;
        _supervisor = supervisor;
        _health = health;
        _log = log;
        WireDraft(_draft);
    }

    public FileLogWriter Log => _log;

    public void AttachWindow(Window window) => _window = window;

    public AppSettings Draft
    {
        get => _draft;
        set
        {
            if (ReferenceEquals(_draft, value))
                return;
            UnwireDraft(_draft);
            _draft = value;
            WireDraft(_draft);
            OnPropertyChanged();
            RecomputeHasUnsavedChanges();
            RefreshCommands();
        }
    }

    [ObservableProperty] private AppState _runtimeState = new();

    [ObservableProperty] private FleetInstance? _selectedInstance;

    [ObservableProperty] private bool _isSettingsLocked = true;

    [ObservableProperty] private string _statusMessage = "";

    [ObservableProperty] private bool _apolloFound;

    [ObservableProperty] private bool _logPaneOpen;

    public string ToggleLogLabel => "📜";

    public string ToggleLogTooltip =>
        LogPaneOpen ? Strings.Get("UI_HideLogs") : Strings.Get("UI_ShowLogs");

    partial void OnLogPaneOpenChanged(bool value)
    {
        OnPropertyChanged(nameof(ToggleLogLabel));
        OnPropertyChanged(nameof(ToggleLogTooltip));
    }

    [ObservableProperty] private string _primaryActionLabel = "";

    [ObservableProperty] private string _secondaryActionLabel = "";

    [ObservableProperty] private string _portStatusMessage = "";

    [ObservableProperty] private bool _hasUnsavedChanges;

    public string? SelectedWebUiUrl =>
        SelectedInstance is null ? null : WebUiPortResolver.GetWebUiUrl(SelectedInstance.Port);

    public string CurrentLanguageSymbol => GetLanguageSymbol(Draft.Locale);

    public IReadOnlyList<LanguageOption> AvailableLanguages => _availableLanguages;

    public bool CanRemoveInstance => SelectedInstance is not null && Draft.Instances.Count > 1;

    partial void OnSelectedInstanceChanged(FleetInstance? value)
    {
        OnPropertyChanged(nameof(SelectedWebUiUrl));
        ValidatePortForSelection();
    }

    partial void OnIsSettingsLockedChanged(bool value)
    {
        OnPropertyChanged(nameof(IsEditorEnabled));
        RefreshCommands();
    }

    public bool IsEditorEnabled => !IsSettingsLocked;

    public bool ShowApolloDownload => !ApolloFound;

    partial void OnApolloFoundChanged(bool value) => OnPropertyChanged(nameof(ShowApolloDownload));

    public async Task InitializeAsync()
    {
        var s = await _store.LoadSettingsAsync().ConfigureAwait(true);
        var st = await _store.LoadStateAsync().ConfigureAwait(true);
        Draft = Clone(s);
        // Default fleet config directory if not set, so a fresh install can Apply without browsing first.
        if (string.IsNullOrWhiteSpace(Draft.Paths.FleetConfigDirectory))
        {
            Draft.Paths.FleetConfigDirectory = AppStoragePaths.FleetDirectory;
            try { Directory.CreateDirectory(Draft.Paths.FleetConfigDirectory); } catch { /* ignore */ }
        }
        // Auto-detect an existing Apollo install when the path is unset or stale,
        // so a fresh launcher clears the "Apollo missing" warning without browsing.
        if (string.IsNullOrWhiteSpace(Draft.Paths.ApolloRoot) || !File.Exists(Draft.Paths.SunshineExePath))
        {
            var detected = ApolloLocator.TryFindApolloRoot();
            if (!string.IsNullOrEmpty(detected))
                Draft.Paths.ApolloRoot = detected;
        }
        RuntimeState = st;
        LogPaneOpen = st.LogPaneOpen;
        CaptureSnapshot();
        RefreshApolloFound();
        RefreshLabels();
        _supervisor.UpdateRuntimeOptions(Draft, Draft.Manager.SyncVolume);
        _supervisor.Start();
        // Enforce the stock-service policy off the UI thread (stopping a service
        // can block for seconds); snapshot the current draft to avoid races.
        var startupSettings = Draft;
        _ = Task.Run(() => _coordinator.EnforceStockServiceState(startupSettings));
        StatusMessage = "";
        SelectedInstance = Draft.Instances.FirstOrDefault();
        _log.Info($"Application started. Loaded {Draft.Instances.Count} instance(s). Apollo path: {(string.IsNullOrEmpty(Draft.Paths.ApolloRoot) ? "<unset>" : Draft.Paths.ApolloRoot)}");
        GetAvailableLanguages();
        OnPropertyChanged(nameof(CurrentLanguageSymbol));
    }

    private void UnwireDraft(AppSettings s)
    {
        s.Manager.PropertyChanged -= OnDraftPartChanged;
        s.Paths.PropertyChanged -= OnDraftPartChanged;
        s.Instances.CollectionChanged -= InstancesOnCollectionChanged;
        foreach (var i in s.Instances)
            i.PropertyChanged -= OnFleetPropertyChanged;
    }

    private void WireDraft(AppSettings s)
    {
        s.Manager.PropertyChanged += OnDraftPartChanged;
        s.Paths.PropertyChanged += OnDraftPartChanged;
        s.Instances.CollectionChanged += InstancesOnCollectionChanged;
        foreach (var i in s.Instances)
            HookInstance(i);
    }

    private void OnDraftPartChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        RecomputeHasUnsavedChanges();
        RefreshCommands();
        RefreshApolloFound();
        if (e.PropertyName == nameof(AppSettings.Locale))
            OnPropertyChanged(nameof(CurrentLanguageSymbol));
    }

    private void InstancesOnCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (e.NewItems is not null)
            foreach (FleetInstance i in e.NewItems)
                HookInstance(i);
        if (e.OldItems is not null)
            foreach (FleetInstance i in e.OldItems)
                i.PropertyChanged -= OnFleetPropertyChanged;
        RecomputeHasUnsavedChanges();
        OnPropertyChanged(nameof(CanRemoveInstance));
        RefreshCommands();
    }

    private void HookInstance(FleetInstance i)
    {
        i.PropertyChanged -= OnFleetPropertyChanged;
        i.PropertyChanged += OnFleetPropertyChanged;
    }

    private void OnFleetPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(FleetInstance.Port) or nameof(FleetInstance.Enabled))
            ValidatePortForSelection();
        RecomputeHasUnsavedChanges();
        RefreshCommands();
        RefreshApolloFound();
    }

    private void CaptureSnapshot()
    {
        _snapshotJson = JsonSerializer.Serialize(Draft, SettingsJson.SnapshotOptions);
        HasUnsavedChanges = false;
    }

    private void RecomputeHasUnsavedChanges()
    {
        HasUnsavedChanges = _snapshotJson != JsonSerializer.Serialize(Draft, SettingsJson.SnapshotOptions);
    }

    private static AppSettings Clone(AppSettings s)
    {
        var json = JsonSerializer.Serialize(s, SettingsJson.SnapshotOptions);
        var c = JsonSerializer.Deserialize<AppSettings>(json, SettingsJson.Options);
        return c ?? AppSettings.CreateDefault();
    }

    private void RefreshApolloFound()
    {
        var path = Draft.Paths.SunshineExePath;
        ApolloFound = !string.IsNullOrEmpty(path) && File.Exists(path);
        OnPropertyChanged(nameof(ApolloStatusText));
        OnPropertyChanged(nameof(ApolloIndicatorGlyph));
        OnPropertyChanged(nameof(ApolloIndicatorBrush));
        RecomputeStatus();
    }

    public string ApolloIndicatorGlyph => ApolloFound ? "✅" : "⚠";
    public Brush ApolloIndicatorBrush => ApolloFound
        ? new SolidColorBrush(Color.FromRgb(0x4C, 0xAF, 0x50))
        : new SolidColorBrush(Color.FromRgb(0xFF, 0x98, 0x00));

    public string ApolloStatusText =>
        ApolloFound ? Strings.Get("Status_ApolloFound") : Strings.Get("Status_ApolloMissing");

    private void RefreshLabels()
    {
        // Icon-only button labels; tooltips carry the descriptive text.
        if (IsSettingsLocked)
        {
            PrimaryActionLabel = "🔒";
            SecondaryActionLabel = "♻️";
        }
        else if (HasUnsavedChanges)
        {
            PrimaryActionLabel = Strings.Get("UI_Apply");
            SecondaryActionLabel = "❌";
        }
        else
        {
            PrimaryActionLabel = "🔓";
            SecondaryActionLabel = "❌";
        }
        OnPropertyChanged(nameof(PrimaryActionTooltip));
        OnPropertyChanged(nameof(SecondaryActionTooltip));
    }

    public string PrimaryActionTooltip
    {
        get
        {
            if (IsSettingsLocked) return Strings.Get("UI_Unlock");
            return HasUnsavedChanges ? Strings.Get("UI_Apply") : Strings.Get("UI_Unlock");
        }
    }

    public string SecondaryActionTooltip =>
        IsSettingsLocked ? Strings.Get("UI_Reload") : Strings.Get("UI_Cancel");

    private void RefreshCommands()
    {
        UnlockOrApplyCommand.NotifyCanExecuteChanged();
        CancelOrReloadCommand.NotifyCanExecuteChanged();
        RefreshLabels();
        RecomputeStatus();
    }

    private bool CanUnlockOrApply() => true;

    [RelayCommand(CanExecute = nameof(CanUnlockOrApply))]
    private async Task UnlockOrApplyAsync()
    {
        if (IsSettingsLocked)
        {
            IsSettingsLocked = false;
            _log.Info("Settings unlocked for editing.");
            RefreshLabels();
            RefreshCommands();
            return;
        }
        if (!HasUnsavedChanges)
        {
            IsSettingsLocked = true;
            _log.Info("Settings re-locked.");
            RefreshLabels();
            RefreshCommands();
            return;
        }
        _log.Info("Applying settings changes...");
        await ApplyCoreAsync().ConfigureAwait(true);
    }

    [RelayCommand]
    private async Task CancelOrReloadAsync()
    {
        if (IsSettingsLocked)
        {
            _log.Info("Reloading application...");
            ReloadApp();
            return;
        }

        if (!HasUnsavedChanges)
        {
            _log.Info("Settings re-locked (no changes to discard).");
            IsSettingsLocked = true;
            RefreshCommands();
            return;
        }

        _log.Warn("Discarding unsaved settings changes.");
        Draft = Clone(JsonSerializer.Deserialize<AppSettings>(_snapshotJson, SettingsJson.Options) ?? AppSettings.CreateDefault());
        SelectedInstance = Draft.Instances.FirstOrDefault();
        RefreshCommands();
        await Task.CompletedTask;
    }

    private async Task ApplyCoreAsync()
    {
        ValidatePortForSelection();
        if (!string.IsNullOrEmpty(PortStatusMessage))
        {
            ShowError(PortStatusMessage);
            return;
        }

        try
        {
            await _coordinator.ApplyAsync(Draft).ConfigureAwait(true);
            CaptureSnapshot();
            IsSettingsLocked = true;
            await RefreshStateAsync().ConfigureAwait(true);
            _log.Info(Strings.Get("Status_Applied"));
            _log.Info($"Settings applied successfully. {Draft.Instances.Count(i => i.Enabled)} enabled instance(s).");
            RefreshCommands();
        }
        catch (InvalidOperationException ex) when (ex.Message.StartsWith("PortValidation_", StringComparison.Ordinal))
        {
            _log.Error($"Apply failed: {ex.Message}");
            ShowError(Strings.Get(ex.Message));
        }
        catch (SettingsValidationException ex)
        {
            _log.Error($"Validation error: {ex.Message}");
            ShowError(ex.Message);
        }
        catch (Exception ex)
        {
            _log.Error($"Apply failed: {ex.Message}");
            if (Draft.Manager.ShowErrors)
                ShowError(ex.Message);
        }
    }

    private void ShowError(string message)
    {
        if (_window is null || !Draft.Manager.ShowErrors)
            return;
        var mb = new Wpf.Ui.Controls.MessageBox
        {
            Title = Strings.Get("Error_Title"),
            Content = message,
            PrimaryButtonText = Strings.Get("Error_Close"),
            IsPrimaryButtonEnabled = true,
            Owner = _window
        };
        _ = mb.ShowDialogAsync();
    }

    [RelayCommand]
    private void BrowseApollo()
    {
        var f = PickFolder();
        if (f is null) return;
        Draft.Paths.ApolloRoot = f;
        RefreshApolloFound();
        OnPropertyChanged(nameof(HasUnsavedChanges));
    }

    [RelayCommand]
    private void BrowseFleet()
    {
        var f = PickFolder();
        if (f is null) return;
        Draft.Paths.FleetConfigDirectory = f;
        OnPropertyChanged(nameof(HasUnsavedChanges));
    }

    [RelayCommand]
    private void BrowseHelper()
    {
        var f = PickFile("Executable (*.exe)|*.exe|All files (*.*)|*.*");
        if (f is null) return;
        Draft.Paths.HelperExePath = f;
        OnPropertyChanged(nameof(HasUnsavedChanges));
    }

    private string? PickFolder()
    {
        if (_window is null) return null;
        var dlg = new OpenFolderDialog { Multiselect = false };
        return dlg.ShowDialog(_window) == true ? dlg.FolderName : null;
    }

    private string? PickFile(string filter)
    {
        if (_window is null) return null;
        var dlg = new OpenFileDialog { Filter = filter, CheckFileExists = true };
        return dlg.ShowDialog(_window) == true ? dlg.FileName : null;
    }

    [RelayCommand]
    private void AddInstance()
    {
        var nextPort = Draft.Instances.Count == 0
            ? 47990
            : Draft.Instances.Max(i => i.Port) + 100;
        var inst = new FleetInstance { Name = $"Instance {Draft.Instances.Count + 1}", Port = nextPort, Enabled = true };
        HookInstance(inst);
        Draft.Instances.Add(inst);
        SelectedInstance = inst;
        _log.Info($"Added instance '{inst.Name}' on port {inst.Port}.");
        OnPropertyChanged(nameof(HasUnsavedChanges));
        OnPropertyChanged(nameof(CanRemoveInstance));
    }

    [RelayCommand]
    private async Task RemoveInstanceAsync()
    {
        if (SelectedInstance is null || Draft.Instances.Count <= 1)
            return;
        var confirm = new Wpf.Ui.Controls.MessageBox
        {
            Title = Strings.Get("Confirm_RemoveInstance_Title"),
            Content = Strings.Get("Confirm_RemoveInstance_Body"),
            PrimaryButtonText = Strings.Get("UI_Remove"),
            CloseButtonText = Strings.Get("UI_Cancel"),
            Owner = _window
        };
        var r = await confirm.ShowDialogAsync().ConfigureAwait(true);
        if (r != Wpf.Ui.Controls.MessageBoxResult.Primary) return;
        var idx = SelectedInstance;
        Draft.Instances.Remove(idx);
        _log.Warn($"Removed instance '{idx.Name}' (port {idx.Port}).");
        SelectedInstance = Draft.Instances.FirstOrDefault();
        OnPropertyChanged(nameof(HasUnsavedChanges));
        OnPropertyChanged(nameof(CanRemoveInstance));
    }

    public async Task ToggleLogPaneAsync()
    {
        LogPaneOpen = !LogPaneOpen;
        _log.Info(LogPaneOpen ? "Log pane shown." : "Log pane hidden.");
        // Read-modify-write under the store lock so we don't clobber the
        // supervisor's InstanceProcessIds with a stale snapshot.
        var open = LogPaneOpen;
        await _store.UpdateStateAsync(st => st.LogPaneOpen = open).ConfigureAwait(true);
    }

    public Task StopFleetAsync() => _supervisor.StopAllInstancesAsync();

    public async Task SaveWindowPlacementAsync(double x, double y, double w, double h)
    {
        await _store.UpdateStateAsync(st =>
        {
            st.WindowX = x;
            st.WindowY = y;
            st.WindowWidth = w;
            st.WindowHeight = h;
        }).ConfigureAwait(true);
    }

    public async Task RefreshStateAsync()
    {
        RuntimeState = await _store.LoadStateAsync().ConfigureAwait(true);
        OnPropertyChanged(nameof(SelectedWebUiUrl));
        RecomputeStatus();
    }

    private void RecomputeStatus()
    {
        // StatusMessage is reserved for the running/enabled count only.
        // Informational / validation / error messages are routed to the log pane.
        if (string.IsNullOrWhiteSpace(Draft.Paths.ApolloRoot) || !ApolloFound)
        {
            StatusMessage = Strings.Get("Status_Placeholder");
            return;
        }
        var enabled = Draft.Instances.Count(i => i.Enabled);
        var running = 0;
        foreach (var inst in Draft.Instances.Where(i => i.Enabled))
        {
            RuntimeState.InstanceProcessIds.TryGetValue(inst.Id, out var pid);
            if (pid > 0 && _health.GetProcessState(pid) == InstanceRunState.Running)
                running++;
        }
        StatusMessage = enabled == 0
            ? Strings.Get("Status_NoEnabledInstances")
            : string.Format(Strings.Get("Status_RunningFmt"), running, enabled);
    }

    public InstanceRunState GetSelectedHealth()
    {
        if (SelectedInstance is null)
            return InstanceRunState.Unknown;
        RuntimeState.InstanceProcessIds.TryGetValue(SelectedInstance.Id, out var pid);
        return _health.GetProcessState(pid <= 0 ? null : pid);
    }

    public bool GetSelectedPortListening() =>
        SelectedInstance is not null && _health.IsPortListening(WebUiPortResolver.GetHttpsPort(SelectedInstance.Port));

    private void ValidatePortForSelection()
    {
        if (SelectedInstance is null)
        {
            PortStatusMessage = "";
            return;
        }

        var v = PortValidator.ValidateInstance(SelectedInstance, Draft.Instances);
        PortStatusMessage = v switch
        {
            PortValidationKind.OutOfRange => Strings.Get("PortValidation_OutOfRange"),
            PortValidationKind.Duplicate => Strings.Get("PortValidation_Duplicate"),
            PortValidationKind.TooClose => Strings.Get("PortValidation_TooClose"),
            _ => ""
        };
        if (!string.IsNullOrEmpty(PortStatusMessage))
            _log.Warn(PortStatusMessage);
    }

    public static void ReloadApp()
    {
        var path = Environment.ProcessPath;
        if (!string.IsNullOrEmpty(path))
            Process.Start(new ProcessStartInfo { FileName = path, UseShellExecute = true });
        // Reload hands off to a fresh process; leave the fleet running so the
        // incoming instance adopts it (don't stop instances here).
        if (Application.Current.MainWindow is MainWindow mw)
            mw.ShutdownReal(stopFleet: false);
        else
            Application.Current.Shutdown();
    }

    public string GetLogTail() => _log.Snapshot();

    public async Task PersistLocaleAsync(string locale)
    {
        Draft.Locale = locale;
        App.ApplyCulture(locale);
        await _store.SaveSettingsAsync(Draft).ConfigureAwait(true);
        CaptureSnapshot();
        OnPropertyChanged(nameof(CurrentLanguageSymbol));
    }

    [RelayCommand]
    private async Task ChangeLanguageAsync(string? locale)
    {
        var normalized = NormalizeLocale(locale);
        var current = NormalizeLocale(Draft.Locale);
        if (string.Equals(current, normalized, StringComparison.OrdinalIgnoreCase))
            return;

        await PersistLocaleAsync(normalized).ConfigureAwait(true);
        ReloadApp();
    }

    public async Task SaveDraftToDiskAsync()
    {
        await _store.SaveSettingsAsync(Draft).ConfigureAwait(true);
        CaptureSnapshot();
    }

    public IReadOnlyList<LanguageOption> GetAvailableLanguages()
    {
        _availableLanguages = DiscoverAvailableLanguages();
        OnPropertyChanged(nameof(AvailableLanguages));
        return _availableLanguages;
    }

    private static string NormalizeLocale(string? locale)
    {
        var v = (locale ?? string.Empty).Trim();
        if (string.IsNullOrEmpty(v))
            return "en";

        v = v.Replace('_', '-');
        try
        {
            return CultureInfo.GetCultureInfo(v).Name;
        }
        catch
        {
            return v;
        }
    }

    private static string GetLanguageSymbol(string? locale)
    {
        var normalized = NormalizeLocale(locale);
        var primary = normalized.Split('-', StringSplitOptions.RemoveEmptyEntries)[0];
        if (string.IsNullOrWhiteSpace(primary))
            return "EN";

        return primary.Length >= 2
            ? primary[..2].ToUpperInvariant()
            : primary.ToUpperInvariant();
    }

    private static IReadOnlyList<LanguageOption> DiscoverAvailableLanguages()
    {
        var locales = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "en" };
        var i18nDir = Path.Combine(AppContext.BaseDirectory, "i18n");
        if (Directory.Exists(i18nDir))
        {
            foreach (var file in Directory.EnumerateFiles(i18nDir, "Resources.*.resx", SearchOption.TopDirectoryOnly))
            {
                var name = Path.GetFileNameWithoutExtension(file);
                if (!name.StartsWith("Resources.", StringComparison.OrdinalIgnoreCase))
                    continue;

                var locale = name["Resources.".Length..];
                if (!string.IsNullOrWhiteSpace(locale))
                    locales.Add(NormalizeLocale(locale));
            }

            foreach (var dir in Directory.EnumerateDirectories(i18nDir, "*", SearchOption.TopDirectoryOnly))
            {
                var token = Path.GetFileName(dir);
                if (!string.IsNullOrWhiteSpace(token) && LooksLikeLocaleToken(token))
                    locales.Add(NormalizeLocale(token));
            }
        }

        var ordered = locales
            .OrderBy(l => l.Equals("en", StringComparison.OrdinalIgnoreCase) ? 0 : 1)
            .ThenBy(l => l, StringComparer.OrdinalIgnoreCase)
            .Select(locale => new LanguageOption(
                locale,
                GetLanguageSymbol(locale),
                GetLanguageDisplayName(locale)))
            .ToList();

        return ordered;
    }

    private static bool LooksLikeLocaleToken(string token)
    {
        var parts = token.Split('-', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0)
            return false;

        return parts.All(p => p.Length is >= 2 and <= 8 && p.All(char.IsLetter));
    }

    private static string GetLanguageDisplayName(string locale)
    {
        try
        {
            var culture = CultureInfo.GetCultureInfo(locale);
            var name = culture.NativeName;
            if (!string.IsNullOrWhiteSpace(name))
                return char.ToUpper(name[0], culture) + name[1..];
        }
        catch
        {
            // Fallback to locale code when culture is not recognized.
        }

        return locale.ToUpperInvariant();
    }

    public sealed record LanguageOption(string Locale, string Symbol, string DisplayName);
}
