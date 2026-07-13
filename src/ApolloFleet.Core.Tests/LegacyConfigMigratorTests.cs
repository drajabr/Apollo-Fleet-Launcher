using System.Text.Json;
using ApolloFleet.Core;
using ApolloFleet.Core.Models;
using Xunit;

namespace ApolloFleet.Core.Tests;

public class LegacyConfigMigratorTests : IDisposable
{
    private readonly string _tmp;
    private readonly string _legacy;
    private readonly string _new;

    public LegacyConfigMigratorTests()
    {
        _tmp = Path.Combine(Path.GetTempPath(), "aflt-migrate-" + Guid.NewGuid().ToString("N"));
        _legacy = Path.Combine(_tmp, "config");
        _new = Path.Combine(_tmp, "ProgramData", "ApolloFleet");
    }

    public void Dispose()
    {
        try { Directory.Delete(_tmp, recursive: true); } catch { /* best effort */ }
    }

    private void SeedLegacy(string fleetDirInSettings, params (string id, string name, int port)[] instances)
    {
        Directory.CreateDirectory(_legacy);
        var fleet = Path.Combine(_legacy, "fleet");
        Directory.CreateDirectory(fleet);

        var settings = new AppSettings();
        settings.Paths.FleetConfigDirectory = fleetDirInSettings;
        settings.Instances.Clear();
        foreach (var (id, name, port) in instances)
        {
            settings.Instances.Add(new FleetInstance { Id = id, Name = name, Port = port, Enabled = true });
            // Per-instance pairing material keyed by Id.
            File.WriteAllText(Path.Combine(fleet, $"fleet-{id}.conf"), $"port = {port}\ncert = {fleet}\\fleet-{id}-cacert.pem\n");
            File.WriteAllText(Path.Combine(fleet, $"fleet-{id}-cacert.pem"), "CERT");
            File.WriteAllText(Path.Combine(fleet, $"fleet-{id}-cakey.pem"), "KEY");
            File.WriteAllText(Path.Combine(fleet, $"state-{id}.json"), "{\"paired\":true}");
        }
        File.WriteAllText(Path.Combine(_legacy, "settings.json"),
            JsonSerializer.Serialize(settings, SettingsJson.Options));
        File.WriteAllText(Path.Combine(_legacy, "state.json"), "{}");
    }

    private AppSettings ReadNewSettings()
    {
        var json = File.ReadAllText(Path.Combine(_new, "settings.json"));
        return JsonSerializer.Deserialize<AppSettings>(json, SettingsJson.Options)!;
    }

    [Fact]
    public void Migrate_PreservesInstancesAndPairingFiles()
    {
        SeedLegacy("", ("id-one", "Laptop", 47990), ("id-two", "Tablet", 48090));

        var did = LegacyConfigMigrator.TryMigrate(_legacy, _new, out _);

        Assert.True(did);
        var migrated = ReadNewSettings();
        Assert.Equal(2, migrated.Instances.Count);
        Assert.Contains(migrated.Instances, i => i.Id == "id-one" && i.Name == "Laptop" && i.Port == 47990);
        Assert.Contains(migrated.Instances, i => i.Id == "id-two" && i.Name == "Tablet" && i.Port == 48090);

        // Pairing material (cert/key/state) carried over for every instance — these are
        // what a lost Id would have orphaned, forcing a re-pair.
        var newFleet = Path.Combine(_new, "fleet");
        foreach (var id in new[] { "id-one", "id-two" })
        {
            Assert.True(File.Exists(Path.Combine(newFleet, $"fleet-{id}-cacert.pem")));
            Assert.True(File.Exists(Path.Combine(newFleet, $"fleet-{id}-cakey.pem")));
            Assert.Equal("{\"paired\":true}", File.ReadAllText(Path.Combine(newFleet, $"state-{id}.json")));
        }

        // Marker written so it never runs again.
        Assert.True(File.Exists(Path.Combine(_new, ".legacy-migrated")));
    }

    [Fact]
    public void Migrate_IsIdempotent_SecondRunIsNoOp()
    {
        SeedLegacy("", ("id-one", "Laptop", 47990));

        Assert.True(LegacyConfigMigrator.TryMigrate(_legacy, _new, out _));
        var didSecond = LegacyConfigMigrator.TryMigrate(_legacy, _new, out var msg);

        Assert.False(didSecond);
        Assert.Contains("already done", msg);
    }

    [Fact]
    public void Migrate_NormalizesFleetDirWhenEmpty_ToNewLocation()
    {
        SeedLegacy("", ("id-one", "Laptop", 47990));

        LegacyConfigMigrator.TryMigrate(_legacy, _new, out _);

        Assert.Equal(Path.Combine(_new, "fleet"), ReadNewSettings().Paths.FleetConfigDirectory);
    }

    [Fact]
    public void Migrate_RewritesLegacyFleetPath_ToNewLocation()
    {
        var legacyFleet = Path.Combine(_legacy, "fleet");
        SeedLegacy(legacyFleet, ("id-one", "Laptop", 47990));

        LegacyConfigMigrator.TryMigrate(_legacy, _new, out _);

        Assert.Equal(Path.Combine(_new, "fleet"), ReadNewSettings().Paths.FleetConfigDirectory);
    }

    [Fact]
    public void Migrate_BacksUpExistingDefault_BeforeOverwriting()
    {
        SeedLegacy("", ("id-one", "Laptop", 47990));
        // Simulate the user having already launched the new build once: a fresh single
        // default instance already sitting at the new location.
        Directory.CreateDirectory(_new);
        var fresh = new AppSettings();
        fresh.Instances.Clear();
        fresh.Instances.Add(new FleetInstance { Id = "fresh-default", Name = "Instance 1", Port = 47990 });
        File.WriteAllText(Path.Combine(_new, "settings.json"), JsonSerializer.Serialize(fresh, SettingsJson.Options));

        var did = LegacyConfigMigrator.TryMigrate(_legacy, _new, out _);

        Assert.True(did);
        // Real instance restored...
        Assert.Contains(ReadNewSettings().Instances, i => i.Id == "id-one");
        // ...and the pre-migration default preserved as a restore point.
        Assert.True(File.Exists(Path.Combine(_new, "settings.json.prelegacy")));
    }

    [Fact]
    public void Migrate_KeepsCurrentConfig_WhenNewLocationHasPairings()
    {
        // Legacy exists (stale leftover)...
        SeedLegacy("", ("legacy-id", "Old", 47990));
        // ...but the current location already holds a real, paired instance (a user who
        // set things up on a v0.4.4-v0.4.6 build). That must NOT be clobbered.
        var newFleet = Path.Combine(_new, "fleet");
        Directory.CreateDirectory(newFleet);
        var real = new AppSettings();
        real.Instances.Clear();
        real.Instances.Add(new FleetInstance { Id = "real-id", Name = "Current", Port = 48090 });
        File.WriteAllText(Path.Combine(_new, "settings.json"), JsonSerializer.Serialize(real, SettingsJson.Options));
        File.WriteAllText(Path.Combine(newFleet, "state-real-id.json"), "{\"devices\":[{\"name\":\"phone\"}]}");

        var did = LegacyConfigMigrator.TryMigrate(_legacy, _new, out var msg);

        Assert.False(did);
        Assert.Contains("kept the current config", msg);
        Assert.Contains(ReadNewSettings().Instances, i => i.Id == "real-id");
        Assert.DoesNotContain(ReadNewSettings().Instances, i => i.Id == "legacy-id");
        // Nothing was overwritten, so no destructive backup was needed.
        Assert.False(File.Exists(Path.Combine(_new, "settings.json.prelegacy")));
        // Marked done so it won't rescan and risk importing later.
        Assert.True(File.Exists(Path.Combine(_new, ".legacy-migrated")));
    }

    [Fact]
    public void Migrate_NormalizesConfPaths_ToNewFleetDir()
    {
        SeedLegacy("", ("id-one", "Laptop", 47990));

        LegacyConfigMigrator.TryMigrate(_legacy, _new, out _);

        // The migrated .conf must reference the NEW fleet dir for its TLS/state paths,
        // not the stale legacy <exeDir>\config\fleet the file was copied from.
        var newFleet = Path.Combine(_new, "fleet");
        var conf = File.ReadAllText(Path.Combine(newFleet, "fleet-id-one.conf"));
        Assert.Contains(Path.Combine(newFleet, "fleet-id-one-cacert.pem"), conf);
        Assert.DoesNotContain(Path.Combine(_legacy, "fleet"), conf);
        // Real pairing state preserved (applier seeds {} only when missing).
        Assert.Equal("{\"paired\":true}", File.ReadAllText(Path.Combine(newFleet, "state-id-one.json")));
    }

    [Fact]
    public void Migrate_NoLegacyConfig_DoesNothing()
    {
        var did = LegacyConfigMigrator.TryMigrate(_legacy, _new, out var msg);

        Assert.False(did);
        Assert.Contains("no legacy config", msg);
        Assert.False(File.Exists(Path.Combine(_new, "settings.json")));
    }
}
