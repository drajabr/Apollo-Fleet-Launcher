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

    private async void OnStartup(object sender, StartupEventArgs e)
    {
        AppDomain.CurrentDomain.UnhandledException += (_, args) => LogFatal(args.ExceptionObject as Exception);
        DispatcherUnhandledException += (_, args) => { LogFatal(args.Exception); args.Handled = true; };
        TaskScheduler.UnobservedTaskException += (_, args) => { LogFatal(args.Exception); args.SetObserved(); };

        try
        {
            Services = ServiceBootstrapper.Create();

            var store = Services.GetRequiredService<ISettingsStore>();
            var settings = await store.LoadSettingsAsync().ConfigureAwait(true);

            ApplyCulture(settings.Locale);
            var theme = settings.Manager.Theme switch
            {
                "Light" => ApplicationTheme.Light,
                "Dark" => ApplicationTheme.Dark,
                _ => IsSystemDark() ? ApplicationTheme.Dark : ApplicationTheme.Light
            };
            ApplicationThemeManager.Apply(theme, WindowBackdropType.Mica);

            var window = new MainWindow();
            MainWindow = window;
            // Tray-first start: showing minimized triggers the existing
            // StateChanged handler which hides the window to the tray.
            if (settings.Manager.StartMinimized)
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
