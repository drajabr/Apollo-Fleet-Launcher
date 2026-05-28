using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public interface ISettingsStore
{
    Task<AppSettings> LoadSettingsAsync(CancellationToken cancellationToken = default);

    Task SaveSettingsAsync(AppSettings settings, bool allowEmptyFleetOverwrite = false, CancellationToken cancellationToken = default);

    Task<AppState> LoadStateAsync(CancellationToken cancellationToken = default);

    Task SaveStateAsync(AppState state, CancellationToken cancellationToken = default);
}
