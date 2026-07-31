using System.Text.Json;

namespace ApolloFleet.Core;

/// <summary>A release asset the updater can download and run.</summary>
public sealed record ReleaseInfo(Version Version, string AssetName, string DownloadUrl, long AssetSize);

/// <summary>
/// Pure parsing/comparison logic for the GitHub releases feed, kept in Core (no HTTP,
/// no WPF) so it is unit-testable — the test project references Core only.
///
/// Release contract produced by .github/workflows/apollofleet-release.yml:
/// tag <c>vX.Y.Z</c> with exactly one asset named
/// <c>ApolloFleet-Setup-vX.Y.Z-win-x64.exe</c>.
/// </summary>
public static class UpdateFeed
{
    public const string Owner = "drajabr";
    public const string Repo = "Apollo-Fleet-Launcher";

    public static string LatestReleaseApiUrl =>
        $"https://api.github.com/repos/{Owner}/{Repo}/releases/latest";

    /// <summary>The installer file name the release workflow publishes for a version.</summary>
    public static string ExpectedAssetName(Version version) =>
        $"ApolloFleet-Setup-v{Normalize(version).ToString(3)}-win-x64.exe";

    /// <summary>
    /// Parses a release tag (<c>v0.5.0</c> or <c>0.5.0</c>) into a 3-part version.
    /// </summary>
    public static bool TryParseVersionTag(string? tag, out Version version)
    {
        version = new Version(0, 0, 0);
        if (string.IsNullOrWhiteSpace(tag))
            return false;

        var t = tag.Trim();
        if (t.Length > 0 && (t[0] == 'v' || t[0] == 'V'))
            t = t[1..];

        if (!Version.TryParse(t, out var parsed))
            return false;

        version = Normalize(parsed);
        return true;
    }

    /// <summary>
    /// True when <paramref name="candidate"/> is a newer release than what is running.
    /// Both sides are normalized to 3 parts first: AssemblyVersion always carries a
    /// trailing build component (0.4.9.0) that a release tag (0.4.9) never has, and a
    /// raw compare would report the tag as older.
    /// </summary>
    public static bool IsNewer(Version candidate, Version current) =>
        Normalize(candidate) > Normalize(current);

    /// <summary>Drops revision/build noise so tags and AssemblyVersion compare cleanly.</summary>
    public static Version Normalize(Version v) =>
        new(v.Major, v.Minor, v.Build < 0 ? 0 : v.Build);

    /// <summary>
    /// Reads the GitHub "latest release" payload. Returns false with a reason rather
    /// than throwing, so a malformed or unexpected feed surfaces as an error state
    /// instead of crashing the app.
    /// </summary>
    public static bool TryParseLatestRelease(string? json, out ReleaseInfo? info, out string? error)
    {
        info = null;
        error = null;

        if (string.IsNullOrWhiteSpace(json))
        {
            error = "Empty response from the releases API.";
            return false;
        }

        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (root.ValueKind != JsonValueKind.Object)
            {
                error = "Unexpected releases API response.";
                return false;
            }

            if (!root.TryGetProperty("tag_name", out var tagEl) || tagEl.ValueKind != JsonValueKind.String)
            {
                error = "Release has no tag_name.";
                return false;
            }

            if (!TryParseVersionTag(tagEl.GetString(), out var version))
            {
                error = $"Unrecognized release tag '{tagEl.GetString()}'.";
                return false;
            }

            var expected = ExpectedAssetName(version);
            if (root.TryGetProperty("assets", out var assets) && assets.ValueKind == JsonValueKind.Array)
            {
                foreach (var asset in assets.EnumerateArray())
                {
                    if (asset.ValueKind != JsonValueKind.Object)
                        continue;
                    var name = asset.TryGetProperty("name", out var n) && n.ValueKind == JsonValueKind.String
                        ? n.GetString()
                        : null;
                    if (!string.Equals(name, expected, StringComparison.OrdinalIgnoreCase))
                        continue;

                    var url = asset.TryGetProperty("browser_download_url", out var u) && u.ValueKind == JsonValueKind.String
                        ? u.GetString()
                        : null;
                    if (string.IsNullOrWhiteSpace(url))
                        continue;

                    var size = asset.TryGetProperty("size", out var s) && s.ValueKind == JsonValueKind.Number && s.TryGetInt64(out var sz)
                        ? sz
                        : 0L;

                    info = new ReleaseInfo(version, expected, url!, size);
                    return true;
                }
            }

            error = $"Release {version.ToString(3)} has no '{expected}' asset.";
            return false;
        }
        catch (JsonException ex)
        {
            error = $"Could not read the releases API response ({ex.Message}).";
            return false;
        }
    }
}
