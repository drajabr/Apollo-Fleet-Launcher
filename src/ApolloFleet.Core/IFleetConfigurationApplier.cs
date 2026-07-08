using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public interface IFleetConfigurationApplier
{
    Task ApplyAsync(AppSettings settings, CancellationToken cancellationToken = default);
}
