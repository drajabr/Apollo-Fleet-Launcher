using System.Text.Json;
using Xunit;

namespace ApolloFleet.Core.Tests;

public class AppsJsonServiceTests
{
    private readonly AppsJsonService _sut = new();

    [Fact]
    public void EnsureDesktop_TerminateOnPause_StaysBoolean()
    {
        var json = """
            {
              "apps": [
                {
                  "name": "Desktop",
                  "terminate-on-pause": true,
                  "exclude-global-state-cmd": false
                }
              ],
              "env": {},
              "version": 2
            }
            """;

        var result = _sut.EnsureDesktopAndBooleans(json, terminateOnPause: false);
        using var doc = JsonDocument.Parse(result);
        var desktop = doc.RootElement.GetProperty("apps")[0];
        Assert.Equal(JsonValueKind.False, desktop.GetProperty("terminate-on-pause").ValueKind);
        Assert.Equal(JsonValueKind.False, desktop.GetProperty("exclude-global-state-cmd").ValueKind);
    }

    [Fact]
    public void EnsureDesktop_NormalizesNumericTerminateToBoolean()
    {
        var json = """
            {
              "apps": [
                {
                  "name": "Desktop",
                  "terminate-on-pause": 1
                }
              ],
              "version": 2
            }
            """;

        var result = _sut.EnsureDesktopAndBooleans(json, terminateOnPause: true);
        using var doc = JsonDocument.Parse(result);
        var v = doc.RootElement.GetProperty("apps")[0].GetProperty("terminate-on-pause");
        Assert.Equal(JsonValueKind.True, v.ValueKind);
    }

    [Fact]
    public void EnsureDesktop_AddsDesktopWhenMissing()
    {
        var result = _sut.EnsureDesktopAndBooleans("{}", terminateOnPause: true);
        using var doc = JsonDocument.Parse(result);
        var apps = doc.RootElement.GetProperty("apps");
        Assert.Equal(1, apps.GetArrayLength());
        Assert.Equal("Desktop", apps[0].GetProperty("name").GetString());
    }
}
