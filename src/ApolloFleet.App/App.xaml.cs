using System;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Markup;
using ApolloFleet.App.Services;
using ApolloFleet.App.ViewModels;
using ApolloFleet.Core;
using Microsoft.Extensions.DependencyInjection;
using Wpf.Ui.Appearance;
using Wpf.Ui.Controls;

namespace ApolloFleet.App;

public partial class App : Application
{
    public static IServiceProvider Services { get; private set; } = null!;

    // Held for the process lifetime to enforce a single running instance.
    private static Mutex? _singleInstance;

    private async void OnStartup(object sender, StartupEventArgs e)
    {
        AppDomain.CurrentDomain.UnhandledException += (_, args) => LogFatal(args.ExceptionObject as Exception);
        DispatcherUnhandledException += (_, args) => { LogFatal(args.Exception); args.Handled = true; };
        TaskScheduler.UnobservedTaskException += (_, args) => { LogFatal(args.Exception); args.SetObserved(); };

        // Only one instance may drive the fleet: the logon task and a manual
        // launch (or a reload handing off to a fresh process) must not run two
        // supervisors fighting over state.json / spawning duplicate sunshines.
        // A short wait lets a reload's outgoing instance exit and release first.
        if (!TryAcquireSingleInstance())
        {
            Shutdown(0);
            return;
        }

        try
        {
            Services = ServiceBootstrapper.Create();

            // Bring pre-v0.4.4 config (<exeDir>\config) forward to %ProgramData%\ApolloFleet
            // BEFORE the first load, so upgraders keep their instances and device pairings
            // instead of getting a fresh single-instance default. Runs at most once.
            if (LegacyConfigMigrator.TryMigrate(out var migrationMessage))
            {
                try { Services.GetRequiredService<FileLogWriter>().Info(migrationMessage); }
                catch { /* logging must never block startup */ }
            }

            var store = Services.GetRequiredService<ISettingsStore>();
            var firstRun = !System.IO.File.Exists(ApolloFleet.Core.AppStoragePaths.SettingsPath);
            var settings = await store.LoadSettingsAsync().ConfigureAwait(true);

            ApplyCulture(settings.Locale);
            ApplyTheme(settings.Manager.Theme);

            var window = new MainWindow();
            MainWindow = window;
            // Tray-first start: showing minimized triggers the existing
            // StateChanged handler which hides the window to the tray.
            // Never start hidden on first run — the user needs to see it to
            // configure it (no settings file exists yet).
            if (settings.Manager.StartMinimized && !firstRun)
                window.WindowState = WindowState.Minimized;
            window.Show();
        }
        catch (Exception ex)
        {
            LogFatal(ex);
            System.Windows.MessageBox.Show("Startup failed:\n\n" + ex, "Apollo Fleet Launcher");
            Shutdown(1);
        }
    }

    /// <summary>
    /// Acquires a machine-wide single-instance mutex. Returns false only if another
    /// instance is still running after a short grace period (so a reload handoff,
    /// where the outgoing process exits within ~1s, succeeds).
    /// </summary>
    private static bool TryAcquireSingleInstance()
    {
        try
        {
            _singleInstance = new Mutex(initiallyOwned: false, @"Global\ApolloFleetLauncher_SingleInstance");
        }
        catch
        {
            return true; // if the mutex can't be created, don't block startup
        }

        try
        {
            return _singleInstance.WaitOne(TimeSpan.FromSeconds(5));
        }
        catch (AbandonedMutexException)
        {
            // Previous owner exited without releasing; ownership passes to us.
            return true;
        }
        catch
        {
            return true;
        }
    }

    private static void LogFatal(Exception? ex)
    {
        if (ex is null) return;
        try
        {
            var dir = ApolloFleet.Core.AppStoragePaths.LogsDirectory;
            System.IO.Directory.CreateDirectory(dir);
            System.IO.File.AppendAllText(
                System.IO.Path.Combine(dir, "startup.log"),
                $"[{DateTime.Now:O}]\n{ex}\n\n");
        }
        catch { /* nothing else we can do */ }
    }

    public static void ApplyCulture(string? locale)
    {
        try
        {
            var ci = string.IsNullOrWhiteSpace(locale)
                ? CultureInfo.CurrentUICulture
                : CultureInfo.GetCultureInfo(locale);
            CultureInfo.DefaultThreadCurrentCulture = ci;
            CultureInfo.DefaultThreadCurrentUICulture = ci;
            Thread.CurrentThread.CurrentCulture = ci;
            Thread.CurrentThread.CurrentUICulture = ci;
            FrameworkElement.LanguageProperty.OverrideMetadata(
                typeof(FrameworkElement),
                new FrameworkPropertyMetadata(XmlLanguage.GetLanguage(ci.IetfLanguageTag)));
        }
        catch
        {
            /* fall back to default */
        }
    }

    /// <summary>
    /// Applies a stored theme preference ("Light" / "Dark" / anything else = follow the
    /// system). Safe to call at any time — WPF-UI swaps the merged dictionaries live, so
    /// the theme toggle needs no restart (unlike a language change).
    /// </summary>
    public static void ApplyTheme(string? preference)
    {
        var theme = preference switch
        {
            "Light" => ApplicationTheme.Light,
            "Dark" => ApplicationTheme.Dark,
            _ => IsSystemDark() ? ApplicationTheme.Dark : ApplicationTheme.Light
        };
        ApplicationThemeManager.Apply(theme, WindowBackdropType.Mica);
    }

    private static bool IsSystemDark()
    {
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int v && v == 0;
        }
        catch
        {
            return false;
        }
    }
}
