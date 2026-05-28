using System.Text.Json;
using System.Text.Json.Nodes;

namespace ApolloFleet.Core;

/// <summary>Ensures apps.json has a Desktop app and boolean fields stay JSON true/false.</summary>
public sealed class AppsJsonService
{
    private static readonly HashSet<string> BooleanAppKeys =
    [
        "terminate-on-pause",
        "exclude-global-state-cmd"
    ];

    public string EnsureDesktopAndBooleans(string? existingJson, bool terminateOnPause)
    {
        JsonNode? root;
        try
        {
            root = string.IsNullOrWhiteSpace(existingJson)
                ? null
                : JsonNode.Parse(existingJson);
        }
        catch (JsonException)
        {
            root = null;
        }

        if (root is not JsonObject obj)
            obj = CreateEmptyRoot();

        if (!obj.TryGetPropertyValue("apps", out var appsNode) || appsNode is not JsonArray apps)
        {
            apps = [];
            obj["apps"] = apps;
        }

        var desktop = apps.OfType<JsonObject>().FirstOrDefault(a =>
            a.TryGetPropertyValue("name", out var n) && n is JsonValue v && v.TryGetValue(out string? s) && s == "Desktop");

        if (desktop is null)
        {
            desktop = CreateDesktopApp(terminateOnPause);
            apps.Add(desktop);
        }
        else
        {
            desktop["terminate-on-pause"] = JsonValue.Create(terminateOnPause);
            EnsureDesktopShape(desktop);
        }

        if (!obj.ContainsKey("env"))
            obj["env"] = new JsonObject();
        if (!obj.ContainsKey("version"))
            obj["version"] = 2;

        NormalizeAllAppBooleans(apps);

        return obj.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
    }

    private static void EnsureDesktopShape(JsonObject desktop)
    {
        if (!desktop.ContainsKey("image-path"))
            desktop["image-path"] = "desktop.png";
        if (!desktop.ContainsKey("name"))
            desktop["name"] = "Desktop";
        if (!desktop.TryGetPropertyValue("state-cmd", out var sc) || sc is not JsonArray)
            desktop["state-cmd"] = new JsonArray();
    }

    private static JsonObject CreateDesktopApp(bool terminateOnPause)
    {
        var o = new JsonObject
        {
            ["image-path"] = "desktop.png",
            ["name"] = "Desktop",
            ["state-cmd"] = new JsonArray(),
            ["terminate-on-pause"] = JsonValue.Create(terminateOnPause)
        };
        return o;
    }

    private static JsonObject CreateEmptyRoot() =>
        new()
        {
            ["apps"] = new JsonArray(),
            ["env"] = new JsonObject(),
            ["version"] = 2
        };

    private static void NormalizeAllAppBooleans(JsonArray apps)
    {
        foreach (var node in apps)
        {
            if (node is not JsonObject app)
                continue;
            foreach (var key in BooleanAppKeys)
            {
                if (!app.TryGetPropertyValue(key, out var val) || val is null)
                    continue;
                if (val is JsonValue jv)
                {
                    if (jv.TryGetValue<bool>(out var b))
                        app[key] = JsonValue.Create(b);
                    else if (jv.TryGetValue<int>(out var n))
                        app[key] = JsonValue.Create(n != 0);
                }
            }
        }
    }
}
