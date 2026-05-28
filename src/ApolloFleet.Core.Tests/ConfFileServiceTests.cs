using ApolloFleet.Core.Models;
using Xunit;

namespace ApolloFleet.Core.Tests;

public class ConfFileServiceTests
{
    private readonly ConfFileService _sut = new();

    [Fact]
    public void Merge_RemovesVirtualSinkWhenAudioUnset()
    {
        var instance = new FleetInstance { Id = "a1", Name = "A", Port = 100, AudioDeviceId = null };
        var paths = new PathOptions { FleetConfigDirectory = @"C:\fleet" };
        var desired = _sut.BuildDesiredMap(instance, paths);

        var existing = """
            virtual_sink = old
            audio_sink = old
            port = 1
            """;

        var merged = _sut.MergeAndFormat(existing, desired, instance);
        Assert.DoesNotContain("virtual_sink", merged, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("audio_sink", merged, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("port = 100", merged);
    }

    [Fact]
    public void Merge_KeepsVirtualSinkWhenAudioSet()
    {
        var instance = new FleetInstance { Id = "a1", Name = "A", Port = 100, AudioDeviceId = "dev123" };
        var paths = new PathOptions { FleetConfigDirectory = @"C:\fleet" };
        var desired = _sut.BuildDesiredMap(instance, paths);

        var merged = _sut.MergeAndFormat(null, desired, instance);
        Assert.Contains("virtual_sink = dev123", merged);
        Assert.Contains("audio_sink = dev123", merged);
    }
}
