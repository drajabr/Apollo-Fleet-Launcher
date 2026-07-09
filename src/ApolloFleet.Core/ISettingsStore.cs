using ApolloFleet.Core.Models;

namespace ApolloFleet.Core;

public interface ISettingsStore
{
    Task<AppSettings> LoadSettingsAsync(CancellationToken cancellationToken = default);

    Task SaveSettingsAsync(AppSettings settings, bool allowEmptyFleetOverwrite = false, CancellationToken cancellationToken = default);

    Task<AppState> LoadStateAsync(CancellationToken cancellationToken = default);

    Task SaveStateAsync(AppState state, CancellationToken cancellationToken = default);

    /// <summary>
    /// Atomically load, mutate, and save the runtime state under a single lock so
    /// concurrent writers (supervisor timers + UI) can't clobber each other's fields.
    /// </summary>
    Task UpdateStateAsync(Action<AppState> mutate, CancellationToken cancellationToken = default);
}
