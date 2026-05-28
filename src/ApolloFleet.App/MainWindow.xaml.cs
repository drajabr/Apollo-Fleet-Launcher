using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Navigation;
using System.Windows.Threading;
using ApolloFleet.App.Services;
using ApolloFleet.App.ViewModels;
using ApolloFleet.Core;
using Microsoft.Extensions.DependencyInjection;
using NAudio.CoreAudioApi;
using Wpf.Ui.Controls;

namespace ApolloFleet.App;

public partial class MainWindow : FluentWindow
{
    private readonly MainViewModel _vm;
    private readonly TrayController _tray;
    private readonly DispatcherTimer _refreshTimer;
    private System.Collections.Generic.List<AudioDeviceItem>? _cachedAudioItems;
    private bool _audioInit;
    private bool _logUiRefreshPending;
    private bool _shuttingDown;

    public MainWindow()
    {
        InitializeComponent();

        _vm = App.Services.GetRequiredService<MainViewModel>();
        _vm.AttachWindow(this);
        DataContext = _vm;

        _tray = new TrayController(this, _vm);

        Loaded += OnLoaded;
        Closing += OnClosing;
        StateChanged += OnStateChanged;

        _vm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(MainViewModel.SelectedInstance))
                OnSelectionChanged();
            if (e.PropertyName == nameof(MainViewModel.LogPaneOpen))
                AdjustLogHeight();
        };

        _vm.Log.LogChanged += (_, _) =>
        {
            if (!_vm.LogPaneOpen || _logUiRefreshPending)
                return;

            _logUiRefreshPending = true;
            Dispatcher.BeginInvoke(new Action(() =>
            {
                _logUiRefreshPending = false;
                if (!_vm.LogPaneOpen)
                    return;

                var tail = _vm.GetLogTail();
                if (string.Equals(LogBox.Text, tail, StringComparison.Ordinal))
                    return;

                LogBox.Text = tail;
                LogBox.CaretIndex = LogBox.Text.Length;
                LogBox.ScrollToEnd();
            }), DispatcherPriority.Background);
        };

        _refreshTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _refreshTimer.Tick += async (_, _) => await _vm.RefreshStateAsync();
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        await _vm.InitializeAsync();
        OnSelectionChanged();
        AdjustLogHeight();
        _refreshTimer.Start();
    }

    private void OnClosing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (_shuttingDown) return;
        // Hide to tray instead of exiting
        e.Cancel = true;
        Hide();
    }

    private void OnStateChanged(object? sender, EventArgs e)
    {
        if (WindowState == WindowState.Minimized)
            Hide();
    }

    public void ShutdownReal()
    {
        _shuttingDown = true;
        _refreshTimer.Stop();
        _tray.Dispose();
        Application.Current.Shutdown();
    }

    public void RestoreFromTray()
    {
        Show();
        WindowState = WindowState.Normal;
        Activate();
        Topmost = true;
        Topmost = false;
        Focus();
    }

    private void OnSelectionChanged()
    {
        SyncAudioSelection();
    }

    private void EnsureAudioDevicesLoaded()
    {
        if (_cachedAudioItems is not null)
            return;

        var items = new System.Collections.Generic.List<AudioDeviceItem>
        {
            new(null, Strings.Get("Audio_Unset"))
        };
        try
        {
            using var en = new MMDeviceEnumerator();
            foreach (var d in en.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active))
            {
                items.Add(new AudioDeviceItem(d.ID, ToPrimaryAudioLabel(d.FriendlyName)));
                d.Dispose();
            }
        }
        catch
        {
            /* ignore */
        }

        _cachedAudioItems = items;
        _audioInit = false;
        AudioCombo.ItemsSource = _cachedAudioItems;
        AudioCombo.SelectionChanged -= AudioCombo_SelectionChanged;
        AudioCombo.SelectionChanged += AudioCombo_SelectionChanged;
    }

    private static string ToPrimaryAudioLabel(string friendlyName)
    {
        if (string.IsNullOrWhiteSpace(friendlyName))
            return friendlyName;

        var i = friendlyName.IndexOf(" (", StringComparison.Ordinal);
        return i > 0 ? friendlyName[..i].Trim() : friendlyName.Trim();
    }

    private void SyncAudioSelection()
    {
        EnsureAudioDevicesLoaded();
        if (_cachedAudioItems is null || _cachedAudioItems.Count == 0)
            return;

        var match = _vm.SelectedInstance?.AudioDeviceId;
        var target = _cachedAudioItems.FirstOrDefault(i => i.Id == match) ?? _cachedAudioItems[0];
        if (ReferenceEquals(AudioCombo.SelectedItem, target))
            return;

        _audioInit = false;
        AudioCombo.SelectedItem = target;
        _audioInit = true;
    }

    private void AudioCombo_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        if (!_audioInit || _vm.SelectedInstance is null) return;
        if (AudioCombo.SelectedItem is AudioDeviceItem item)
            _vm.SelectedInstance.AudioDeviceId = item.Id;
    }

    private void AudioCombo_DropDownOpened(object sender, EventArgs e)
    {
        if (sender is not System.Windows.Controls.ComboBox combo)
            return;

        if (combo.Template.FindName("PART_Popup", combo) is System.Windows.Controls.Primitives.Popup popup)
        {
            popup.Width = combo.ActualWidth;
            if (popup.Child is FrameworkElement child)
            {
                child.Width = combo.ActualWidth;
                child.MinWidth = combo.ActualWidth;
                child.MaxWidth = combo.ActualWidth;
            }
        }

        // Keep each dropdown row constrained to combo width so long names are ellipsized.
        for (var i = 0; i < combo.Items.Count; i++)
        {
            if (combo.ItemContainerGenerator.ContainerFromIndex(i) is System.Windows.Controls.ComboBoxItem item)
                item.MaxWidth = Math.Max(24, combo.ActualWidth - 8);
        }
    }

    private void AdjustLogHeight()
    {
        var h = _vm.LogPaneOpen ? 670d : 390d;
        MinHeight = h;
        MaxHeight = h;
        Height = h;
        if (_vm.LogPaneOpen)
        {
            LogBox.Text = _vm.GetLogTail();
            LogBox.CaretIndex = LogBox.Text.Length;
            LogBox.ScrollToEnd();
        }
    }

    private async void LogsButton_Click(object sender, RoutedEventArgs e)
    {
        await _vm.ToggleLogPaneAsync();
    }

    private void MinButton_Click(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }

    private void LanguageButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not System.Windows.Controls.Button button || button.ContextMenu is null)
            return;

        button.ContextMenu.PlacementTarget = button;
        button.ContextMenu.Placement = System.Windows.Controls.Primitives.PlacementMode.Bottom;
        button.ContextMenu.IsOpen = true;
    }

    private void Hyperlink_RequestNavigate(object sender, RequestNavigateEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo { FileName = e.Uri.ToString(), UseShellExecute = true });
        }
        catch
        {
            /* ignore */
        }
        e.Handled = true;
    }

    internal sealed record AudioDeviceItem(string? Id, string Display)
    {
        public override string ToString() => Display;
    }
}
