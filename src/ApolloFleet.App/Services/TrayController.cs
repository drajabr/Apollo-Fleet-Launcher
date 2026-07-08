using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using ApolloFleet.App.ViewModels;
using Hardcodet.Wpf.TaskbarNotification;

namespace ApolloFleet.App.Services;

public sealed class TrayController : IDisposable
{
    private readonly MainWindow _window;
    private readonly MainViewModel _vm;
    private readonly TaskbarIcon _icon;

    public TrayController(MainWindow window, MainViewModel vm)
    {
        _window = window;
        _vm = vm;

        _icon = new TaskbarIcon
        {
            ToolTipText = Strings.Get("Tray_Tooltip")
        };

        try
        {
            _icon.IconSource = new BitmapImage(new Uri("pack://application:,,,/app.ico"));
        }
        catch
        {
            /* tray runs without icon */
        }

        _icon.TrayLeftMouseUp += (_, _) => Restore();

        var menu = new ContextMenu();
        var open = new MenuItem { Header = Strings.Get("Tray_Open") };
        open.Click += (_, _) => Restore();
        var reload = new MenuItem { Header = Strings.Get("UI_Reload") };
        reload.Click += (_, _) => MainViewModel.ReloadApp();
        var exit = new MenuItem { Header = Strings.Get("Tray_Exit") };
        exit.Click += (_, _) => _window.ShutdownReal();
        menu.Items.Add(open);
        menu.Items.Add(reload);
        menu.Items.Add(new Separator());
        menu.Items.Add(exit);
        _icon.ContextMenu = menu;

        _vm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(MainViewModel.RuntimeState) or nameof(MainViewModel.Draft))
                UpdateTooltip();
        };
        UpdateTooltip();
    }

    private void Restore() => _window.RestoreFromTray();

    private void UpdateTooltip()
    {
        var running = 0;
        var total = 0;
        foreach (var i in _vm.Draft.Instances.Where(x => x.Enabled))
        {
            total++;
            if (_vm.RuntimeState.InstanceProcessIds.TryGetValue(i.Id, out var pid) && pid > 0)
                running++;
        }
        _icon.ToolTipText = string.Format(Strings.Get("Tray_TooltipFmt"), Strings.Get("Tray_Tooltip"), running, total);
    }

    public void Dispose() => _icon.Dispose();
}
