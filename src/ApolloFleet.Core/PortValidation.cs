using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public enum PortValidationKind
{
    None,
    OutOfRange,
    Duplicate,
    TooClose
}

public static class PortValidator
{
    public const int MinPort = 1;
    public const int MaxPort = 65535;

    // Apollo/Sunshine derives a spread of ports from each base port (roughly
    // base-5 .. base+21 for HTTP/HTTPS/RTSP/video/control/audio/mic). Two
    // instances whose base ports are closer than this overlap and conflict even
    // when the base ports themselves differ.
    public const int MinPortGap = 30;

    /// <summary>Validates a single instance port against the full fleet (including itself).</summary>
    public static PortValidationKind ValidateInstance(FleetInstance instance, IEnumerable<FleetInstance> fleet)
    {
        if (instance.Port < MinPort || instance.Port > MaxPort)
            return PortValidationKind.OutOfRange;

        var others = fleet.Where(i => i.Enabled && i.Id != instance.Id).ToList();
        if (others.Any(i => i.Port == instance.Port))
            return PortValidationKind.Duplicate;
        if (others.Any(i => Math.Abs(i.Port - instance.Port) < MinPortGap))
            return PortValidationKind.TooClose;

        return PortValidationKind.None;
    }

    public static PortValidationKind ValidateFleet(IEnumerable<FleetInstance> fleet)
    {
        var enabledPorts = fleet.Where(i => i.Enabled).Select(i => i.Port).ToList();
        foreach (var p in enabledPorts)
        {
            if (p < MinPort || p > MaxPort)
                return PortValidationKind.OutOfRange;
        }

        var set = new HashSet<int>();
        foreach (var p in enabledPorts)
        {
            if (!set.Add(p))
                return PortValidationKind.Duplicate;
        }

        var sorted = enabledPorts.OrderBy(p => p).ToList();
        for (var i = 1; i < sorted.Count; i++)
        {
            if (sorted[i] - sorted[i - 1] < MinPortGap)
                return PortValidationKind.TooClose;
        }

        return PortValidationKind.None;
    }
}
