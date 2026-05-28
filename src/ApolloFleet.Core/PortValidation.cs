using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public enum PortValidationKind
{
    None,
    OutOfRange,
    Duplicate
}

public static class PortValidator
{
    public const int MinPort = 1;
    public const int MaxPort = 65535;

    /// <summary>Validates a single instance port against the full fleet (including itself).</summary>
    public static PortValidationKind ValidateInstance(FleetInstance instance, IEnumerable<FleetInstance> fleet)
    {
        if (instance.Port < MinPort || instance.Port > MaxPort)
            return PortValidationKind.OutOfRange;

        var dup = fleet.Count(i => i.Enabled && i.Port == instance.Port && i.Id != instance.Id);
        if (dup > 0)
            return PortValidationKind.Duplicate;

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

        return PortValidationKind.None;
    }
}
