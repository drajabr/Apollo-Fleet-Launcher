using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace ApolloFleet.Core.Models;

public sealed class PathOptions : INotifyPropertyChanged
{
    private string _apolloRoot = "";
    private string _fleetConfigDirectory = "";
    private string? _helperExePath;

    public event PropertyChangedEventHandler? PropertyChanged;

    public string ApolloRoot
    {
        get => _apolloRoot;
        set => SetField(ref _apolloRoot, value);
    }

    public string FleetConfigDirectory
    {
        get => _fleetConfigDirectory;
        set => SetField(ref _fleetConfigDirectory, value);
    }

    public string? HelperExePath
    {
        get => _helperExePath;
        set => SetField(ref _helperExePath, value);
    }

    public string SunshineExePath =>
        string.IsNullOrWhiteSpace(ApolloRoot)
            ? ""
            : Path.Combine(ApolloRoot.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar), "sunshine.exe");

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
