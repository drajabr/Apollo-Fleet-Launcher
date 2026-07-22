using System.Text.Json;
using ApolloFleet.Core;
using ApolloFleet.Core.Models;
using Xunit;

namespace ApolloFleet.Core.Tests;

public class FleetConfigurationApplierTests
{
    private static AppSettings SettingsIn(string dir, FleetInstance inst)
    {
        var s = AppSettings.CreateDefault();
        s.Instances.Clear();
        s.Instances.Add(inst);
        s.Paths.FleetConfigDirectory = dir;
        return s;
    }

    [Fact]
    public async Task Apply_SeedsStateWithPersistentUuid_WhenSet()
    {
        var dir = Path.Combine(Path.GetTempPath(), "afl-test-" + Guid.NewGuid().ToString("N"));
        try
        {
            var inst = new FleetInstance { Id = "abc", Name = "A", Port = 47990, Uuid = "60A6753D-1DEB-D027-1184-B920AA7104E5" };
            await new FleetConfigurationApplier().ApplyAsync(SettingsIn(dir, inst));

            var statePath = Path.Combine(dir, inst.StateFileName);
            Assert.True(File.Exists(statePath));
            using var doc = JsonDocument.Parse(File.ReadAllText(statePath));
            Assert.Equal(inst.Uuid, doc.RootElement.GetProperty("root").GetProperty("uniqueid").GetString());
        }
        finally
        {
            if (Directory.Exists(dir)) Directory.Delete(dir, recursive: true);
        }
    }

    [Fact]
    public async Task Apply_DoesNotOverwriteExistingState()
    {
        var dir = Path.Combine(Path.GetTempPath(), "afl-test-" + Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(dir);
            var inst = new FleetInstance { Id = "abc", Name = "A", Port = 47990, Uuid = "NEW-UUID" };
            var statePath = Path.Combine(dir, inst.StateFileName);
            File.WriteAllText(statePath, "{\"root\":{\"uniqueid\":\"ORIGINAL\"}}");

            await new FleetConfigurationApplier().ApplyAsync(SettingsIn(dir, inst));

            using var doc = JsonDocument.Parse(File.ReadAllText(statePath));
            Assert.Equal("ORIGINAL", doc.RootElement.GetProperty("root").GetProperty("uniqueid").GetString());
        }
        finally
        {
            if (Directory.Exists(dir)) Directory.Delete(dir, recursive: true);
        }
    }
}
