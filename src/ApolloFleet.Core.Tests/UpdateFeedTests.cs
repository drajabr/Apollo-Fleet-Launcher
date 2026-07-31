using ApolloFleet.Core;
using Xunit;

namespace ApolloFleet.Core.Tests;

public class UpdateFeedTests
{
    [Theory]
    [InlineData("v0.5.0", 0, 5, 0)]
    [InlineData("0.5.0", 0, 5, 0)]
    [InlineData("V1.2.3", 1, 2, 3)]
    [InlineData(" v0.4.9 ", 0, 4, 9)]
    [InlineData("v0.5.0.0", 0, 5, 0)]
    public void TryParseVersionTag_AcceptsTagForms(string tag, int major, int minor, int build)
    {
        Assert.True(UpdateFeed.TryParseVersionTag(tag, out var v));
        Assert.Equal(new Version(major, minor, build), v);
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    [InlineData("latest")]
    [InlineData("vNext")]
    public void TryParseVersionTag_RejectsJunk(string? tag)
    {
        Assert.False(UpdateFeed.TryParseVersionTag(tag, out _));
    }

    [Fact]
    public void IsNewer_TreatsFourPartAssemblyVersionAsEqual()
    {
        // AssemblyVersion is 0.4.9.0; the release tag is 0.4.9. Without normalization
        // the tag would compare as OLDER and the app would never see an update.
        Assert.False(UpdateFeed.IsNewer(new Version("0.4.9"), new Version("0.4.9.0")));
        Assert.True(UpdateFeed.IsNewer(new Version("0.5.0"), new Version("0.4.9.0")));
        Assert.False(UpdateFeed.IsNewer(new Version("0.4.8"), new Version("0.4.9.0")));
    }

    [Fact]
    public void ExpectedAssetName_MatchesReleaseWorkflowNaming()
    {
        Assert.Equal("ApolloFleet-Setup-v0.4.9-win-x64.exe", UpdateFeed.ExpectedAssetName(new Version("0.4.9")));
        // A 4-part version must still produce the 3-part asset name CI publishes.
        Assert.Equal("ApolloFleet-Setup-v0.5.0-win-x64.exe", UpdateFeed.ExpectedAssetName(new Version("0.5.0.0")));
    }

    private static string ReleaseJson(string tag, params string[] assetNames)
    {
        var assets = string.Join(",", assetNames.Select(n =>
            $$"""{"name":"{{n}}","browser_download_url":"https://example.test/{{n}}","size":12345}"""));
        return $$"""{"tag_name":"{{tag}}","assets":[{{assets}}]}""";
    }

    [Fact]
    public void TryParseLatestRelease_ReadsVersionAndAsset()
    {
        var json = ReleaseJson("v0.5.0", "ApolloFleet-Setup-v0.5.0-win-x64.exe");

        Assert.True(UpdateFeed.TryParseLatestRelease(json, out var info, out var err));
        Assert.Null(err);
        Assert.NotNull(info);
        Assert.Equal(new Version(0, 5, 0), info!.Version);
        Assert.Equal("ApolloFleet-Setup-v0.5.0-win-x64.exe", info.AssetName);
        Assert.Equal("https://example.test/ApolloFleet-Setup-v0.5.0-win-x64.exe", info.DownloadUrl);
        Assert.Equal(12345, info.AssetSize);
    }

    [Fact]
    public void TryParseLatestRelease_IgnoresUnrelatedAssets()
    {
        var json = ReleaseJson("v0.5.0", "checksums.txt", "ApolloFleet-Setup-v0.5.0-win-x64.exe");

        Assert.True(UpdateFeed.TryParseLatestRelease(json, out var info, out _));
        Assert.Equal("ApolloFleet-Setup-v0.5.0-win-x64.exe", info!.AssetName);
    }

    [Fact]
    public void TryParseLatestRelease_FailsWhenInstallerAssetMissing()
    {
        // e.g. the release exists but the upload failed / naming drifted.
        var json = ReleaseJson("v0.5.0", "some-other-file.zip");

        Assert.False(UpdateFeed.TryParseLatestRelease(json, out var info, out var err));
        Assert.Null(info);
        Assert.Contains("ApolloFleet-Setup-v0.5.0-win-x64.exe", err);
    }

    [Fact]
    public void TryParseLatestRelease_FailsOnEmptyAssets()
    {
        Assert.False(UpdateFeed.TryParseLatestRelease("""{"tag_name":"v0.5.0","assets":[]}""", out _, out var err));
        Assert.NotNull(err);
    }

    [Fact]
    public void TryParseLatestRelease_FailsWithoutTagName()
    {
        Assert.False(UpdateFeed.TryParseLatestRelease("""{"assets":[]}""", out _, out var err));
        Assert.Contains("tag_name", err);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not json")]
    [InlineData("[]")]
    public void TryParseLatestRelease_FailsGracefullyOnBadPayloads(string json)
    {
        Assert.False(UpdateFeed.TryParseLatestRelease(json, out var info, out var err));
        Assert.Null(info);
        Assert.NotNull(err);
    }
}
