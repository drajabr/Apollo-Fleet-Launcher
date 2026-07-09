using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace ApolloFleet.Core.Models;

public sealed class ManagerOptions : INotifyPropertyChanged
{
    // Features default ON: a fresh install runs the fleet at logon, syncs
    // volume, removes the virtual display on disconnect, and starts to tray.
    private bool _autoStart = true;
    private bool _syncVolume = true;
    private bool _removeOnDisconnect = true;
    private string _theme = "Default";
    private bool _showErrors = true;
    private bool _startMinimized = true;

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool AutoStart
    {
        get => _autoStart;
        set => SetField(ref _autoStart, value);
    }

    public bool SyncVolume
    {
        get => _syncVolume;
        set => SetField(ref _syncVolume, value);
    }

    public bool RemoveOnDisconnect
    {
        get => _removeOnDisconnect;
        set => SetField(ref _removeOnDisconnect, value);
    }

    public string Theme
    {
        get => _theme;
        set => SetField(ref _theme, value);
    }

    public bool ShowErrors
    {
        get => _showErrors;
        set => SetField(ref _showErrors, value);
    }

    public bool StartMinimized
    {
        get => _startMinimized;
        set => SetField(ref _startMinimized, value);
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
