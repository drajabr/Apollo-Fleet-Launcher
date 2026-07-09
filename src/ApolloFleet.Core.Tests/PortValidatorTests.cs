using ApolloFleet.Core.Models;
using Xunit;

namespace ApolloFleet.Core.Tests;

public class PortValidatorTests
{
    [Fact]
    public void DuplicateEnabledPorts_Fails()
    {
        var fleet = new List<FleetInstance>
        {
            new() { Id = "1", Port = 4800, Enabled = true },
            new() { Id = "2", Port = 4800, Enabled = true }
        };
        Assert.Equal(PortValidationKind.Duplicate, PortValidator.ValidateFleet(fleet));
    }

    [Fact]
    public void SamePortOneDisabled_Ok()
    {
        var fleet = new List<FleetInstance>
        {
            new() { Id = "1", Port = 4800, Enabled = true },
            new() { Id = "2", Port = 4800, Enabled = false }
        };
        Assert.Equal(PortValidationKind.None, PortValidator.ValidateFleet(fleet));
    }

    [Fact]
    public void OutOfRange_Fails()
    {
        var fleet = new List<FleetInstance>
        {
            new() { Id = "1", Port = 0, Enabled = true }
        };
        Assert.Equal(PortValidationKind.OutOfRange, PortValidator.ValidateFleet(fleet));
    }

    [Fact]
    public void PortsWithinApolloRange_TooClose()
    {
        var fleet = new List<FleetInstance>
        {
            new() { Id = "1", Port = 47990, Enabled = true },
            new() { Id = "2", Port = 48000, Enabled = true } // only 10 apart
        };
        Assert.Equal(PortValidationKind.TooClose, PortValidator.ValidateFleet(fleet));
    }

    [Fact]
    public void PortsSpacedByHundred_Ok()
    {
        var fleet = new List<FleetInstance>
        {
            new() { Id = "1", Port = 47990, Enabled = true },
            new() { Id = "2", Port = 48090, Enabled = true }
        };
        Assert.Equal(PortValidationKind.None, PortValidator.ValidateFleet(fleet));
    }

    [Fact]
    public void ValidateInstance_FlagsTooCloseNeighbor()
    {
        var self = new FleetInstance { Id = "1", Port = 47990, Enabled = true };
        var fleet = new List<FleetInstance>
        {
            self,
            new() { Id = "2", Port = 48005, Enabled = true } // 15 apart
        };
        Assert.Equal(PortValidationKind.TooClose, PortValidator.ValidateInstance(self, fleet));
    }
}
