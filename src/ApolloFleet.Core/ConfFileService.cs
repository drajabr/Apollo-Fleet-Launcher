using System.Text;
using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public sealed class ConfFileService
{
    private static readonly Dictionary<string, string> StaticKeys = new()
    {
        ["keep_sink_default"] = "disabled"
    };

    public IReadOnlyDictionary<string, string> BuildDesiredMap(FleetInstance instance, PathOptions paths)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var kv in StaticKeys)
            map[kv.Key] = kv.Value;

        var fleetDir = paths.FleetConfigDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var logPath = Path.Combine(fleetDir, instance.LogFileName);
        var statePath = Path.Combine(fleetDir, instance.StateFileName);
        var appsPath = Path.Combine(fleetDir, instance.AppsFileName);

        map["sunshine_name"] = instance.Name;
        map["port"] = instance.Port.ToString();
        map["log_path"] = logPath;
        map["file_state"] = statePath;
        map["credentials_file"] = statePath;
        map["file_apps"] = appsPath;
        map["auto_capture_sink"] = instance.GetAutoCaptureSinkValue();
        map["headless_mode"] = instance.GetHeadlessModeValue();

        if (!string.IsNullOrWhiteSpace(instance.AudioDeviceId))
        {
            map["virtual_sink"] = instance.AudioDeviceId!;
            map["audio_sink"] = instance.AudioDeviceId!;
        }

        return map;
    }

    /// <summary>Merge desired keys into existing file content; Unset audio removes virtual_sink/audio_sink.</summary>
    public string MergeAndFormat(string? existingContent, IReadOnlyDictionary<string, string> desired, FleetInstance instance)
    {
        var current = Parse(existingContent);
        if (string.IsNullOrWhiteSpace(instance.AudioDeviceId))
        {
            current.Remove("virtual_sink");
            current.Remove("audio_sink");
        }

        foreach (var kv in desired)
            current[kv.Key] = kv.Value;

        var orderedKeys = current.Keys.OrderBy(k => k, StringComparer.OrdinalIgnoreCase).ToList();
        var sb = new StringBuilder();
        foreach (var k in orderedKeys)
            sb.AppendLine($"{k} = {current[k]}");
        return sb.ToString();
    }

    public static Dictionary<string, string> Parse(string? content)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(content))
            return map;

        foreach (var raw in content.Split('\n'))
        {
            var line = raw.TrimEnd('\r');
            line = line.Trim();
            if (line.Length == 0 || line[0] == ';' || line[0] == '#')
                continue;
            var eq = line.IndexOf('=');
            if (eq <= 0)
                continue;
            var key = line[..eq].Trim();
            var val = line[(eq + 1)..].Trim();
            if (val.Length >= 2 && val[0] == '[' && val[^1] == ']')
                val = val[1..^1].Trim();
            map[key] = val;
        }

        return map;
    }
}
