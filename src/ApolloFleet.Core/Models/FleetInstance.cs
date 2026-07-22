using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace ApolloFleet.Core.Models;

public sealed class FleetInstance : INotifyPropertyChanged
{
    private string _id = Guid.NewGuid().ToString("N");
    private string _name = "";
    private int _port = 47990;
    private bool _enabled = true;
    private string? _audioDeviceId;
    private bool _headless;
    private string _uuid = "";

    public event PropertyChangedEventHandler? PropertyChanged;

    public string Id
    {
        get => _id;
        set => SetField(ref _id, value);
    }

    /// <summary>
    /// The persistent Apollo/Sunshine host id (state <c>root.uniqueid</c>) that Moonlight
    /// uses to identify this host. Stored here so it survives regeneration of the fleet
    /// state file — otherwise each regeneration mints a new id and Moonlight shows a
    /// duplicate host. Empty until adopted from an existing state file or generated.
    /// </summary>
    public string Uuid
    {
        get => _uuid;
        set => SetField(ref _uuid, value);
    }

    public string Name
    {
        get => _name;
        set => SetField(ref _name, value);
    }

    public int Port
    {
        get => _port;
        set => SetField(ref _port, value);
    }

    public bool Enabled
    {
        get => _enabled;
        set => SetField(ref _enabled, value);
    }

    /// <summary>Device id string, or null/empty for Unset (omit virtual_sink/audio_sink).</summary>
    public string? AudioDeviceId
    {
        get => _audioDeviceId;
        set => SetField(ref _audioDeviceId, value);
    }

    public bool Headless
    {
        get => _headless;
        set => SetField(ref _headless, value);
    }

    public string ConfFileName => $"fleet-{Id}.conf";

    public string AppsFileName => $"apps-{Id}.json";

    public string LogFileName => $"fleet-{Id}.log";

    public string StateFileName => $"state-{Id}.json";

    public string CertFileName => $"fleet-{Id}-cacert.pem";

    public string KeyFileName => $"fleet-{Id}-cakey.pem";

    public string GetAutoCaptureSinkValue() =>
        string.IsNullOrWhiteSpace(AudioDeviceId) ? "enabled" : "disabled";

    public string GetHeadlessModeValue() => Headless ? "enabled" : "disabled";

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
