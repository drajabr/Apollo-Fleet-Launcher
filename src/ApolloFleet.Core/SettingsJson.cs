using System.Text.Json;
using System.Text.Json.Serialization;

namespace ApolloFleet.Core;

public static class SettingsJson
{
    public static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public static readonly JsonSerializerOptions SnapshotOptions = new(Options)
    {
        WriteIndented = false
    };
}
