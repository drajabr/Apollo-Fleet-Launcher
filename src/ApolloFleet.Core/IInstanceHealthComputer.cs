using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public enum InstanceRunState
{
    Unknown,
    Stopped,
    Running
}

public interface IInstanceHealthComputer
{
    InstanceRunState GetProcessState(int? pid);

    bool IsPortListening(int port);
}
