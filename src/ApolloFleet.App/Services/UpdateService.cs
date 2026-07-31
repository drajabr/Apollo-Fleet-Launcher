using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using ApolloFleet.Core;

namespace ApolloFleet.App.Services;

/// <summary>
/// Self-updater: checks the GitHub releases feed, downloads the installer, and hands
/// off to it silently.
///
/// The install handoff mirrors <see cref="ViewModels.MainViewModel.ReloadApp"/>: setup is
/// launched, then the app exits WITHOUT stopping the fleet, so running sunshine instances
/// survive the swap and the relaunched new version adopts them. Setup waits for this
/// process's single-instance mutex to clear before replacing files (see installer/ApolloFleet.iss).
///
/// All state changes raise <see cref="StateChanged"/>; the view model marshals to the UI thread.
/// </summary>
public sealed class UpdateService
{
    private static readonly HttpClient Http = CreateClient();

    private readonly FileLogWriter _log;
    private readonly SemaphoreSlim _gate = new(1, 1);

    public UpdateService(FileLogWriter log)
    {
        _log = log;
        CurrentVersion = UpdateFeed.Normalize(
            Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0, 0, 0));
    }

    public Version CurrentVersion { get; }

    public UpdatePhase Phase { get; private set; } = UpdatePhase.Idle;

    /// <summary>The newer release found by the last successful check, if any.</summary>
    public ReleaseInfo? Available { get; private set; }

    public int DownloadPercent { get; private set; }

    public string? ErrorMessage { get; private set; }

    public event Action? StateChanged;

    /// <summary>True while an operation owns the state machine; the UI disables the button.</summary>
    public bool IsBusy => Phase is UpdatePhase.Checking or UpdatePhase.Downloading or UpdatePhase.Installing;

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        // GitHub rejects requests without a User-Agent.
        var ver = Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "0.0.0";
        client.DefaultRequestHeaders.UserAgent.ParseAdd($"ApolloFleetLauncher/{ver}");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return client;
    }

    private void SetState(UpdatePhase phase, string? error = null)
    {
        Phase = phase;
        ErrorMessage = error;
        StateChanged?.Invoke();
    }

    /// <summary>
    /// Queries the releases API. Never throws — failures land in <see cref="UpdatePhase.Error"/>
    /// so a missing network or a rate limit can't take down startup.
    /// </summary>
    public async Task CheckAsync(CancellationToken ct = default)
    {
        if (!await _gate.WaitAsync(0, ct).ConfigureAwait(false))
            return;

        try
        {
            SetState(UpdatePhase.Checking);
            using var resp = await Http.GetAsync(UpdateFeed.LatestReleaseApiUrl, ct).ConfigureAwait(false);

            if (!resp.IsSuccessStatusCode)
            {
                // 403 without auth is almost always the 60 req/h anonymous rate limit.
                var reason = resp.StatusCode == HttpStatusCode.Forbidden
                    ? "GitHub rate limit reached; try again later."
                    : $"Releases API returned {(int)resp.StatusCode}.";
                _log.Warn($"Update check failed: {reason}");
                SetState(UpdatePhase.Error, reason);
                return;
            }

            var json = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            if (!UpdateFeed.TryParseLatestRelease(json, out var info, out var parseError))
            {
                _log.Warn($"Update check failed: {parseError}");
                SetState(UpdatePhase.Error, parseError);
                return;
            }

            if (UpdateFeed.IsNewer(info!.Version, CurrentVersion))
            {
                Available = info;
                _log.Info($"Update available: v{info.Version.ToString(3)} (running v{CurrentVersion.ToString(3)}).");
                SetState(UpdatePhase.UpdateAvailable);
            }
            else
            {
                Available = null;
                _log.Info($"Up to date (v{CurrentVersion.ToString(3)}).");
                SetState(UpdatePhase.UpToDate);
            }
        }
        catch (OperationCanceledException)
        {
            SetState(UpdatePhase.Error, "Update check timed out.");
        }
        catch (Exception ex)
        {
            _log.Warn($"Update check failed: {ex.Message}");
            SetState(UpdatePhase.Error, ex.Message);
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>
    /// Downloads the pending release installer to <see cref="AppStoragePaths.UpdatesDirectory"/>,
    /// reporting progress. On failure the partial file is removed and
    /// <see cref="Available"/> is kept so clicking again retries the download.
    /// </summary>
    public async Task DownloadAsync(CancellationToken ct = default)
    {
        var release = Available;
        if (release is null)
            return;
        if (!await _gate.WaitAsync(0, ct).ConfigureAwait(false))
            return;

        var dir = AppStoragePaths.UpdatesDirectory;
        var target = Path.Combine(dir, release.AssetName);
        var partial = target + ".partial";

        try
        {
            DownloadPercent = 0;
            SetState(UpdatePhase.Downloading);
            Directory.CreateDirectory(dir);

            // A previously completed download of the same asset is reusable.
            if (File.Exists(target) && release.AssetSize > 0 && new FileInfo(target).Length == release.AssetSize)
            {
                _log.Info($"Update installer already downloaded: {target}");
                DownloadPercent = 100;
                SetState(UpdatePhase.ReadyToInstall);
                return;
            }

            TryDelete(partial);

            using (var resp = await Http
                       .GetAsync(release.DownloadUrl, HttpCompletionOption.ResponseHeadersRead, ct)
                       .ConfigureAwait(false))
            {
                resp.EnsureSuccessStatusCode();
                var total = resp.Content.Headers.ContentLength ?? release.AssetSize;

                await using var src = await resp.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
                await using var dst = new FileStream(partial, FileMode.Create, FileAccess.Write, FileShare.None);

                var buffer = new byte[81920];
                long written = 0;
                var lastReported = -1;
                int read;
                while ((read = await src.ReadAsync(buffer, ct).ConfigureAwait(false)) > 0)
                {
                    await dst.WriteAsync(buffer.AsMemory(0, read), ct).ConfigureAwait(false);
                    written += read;
                    if (total > 0)
                    {
                        var pct = (int)Math.Min(100, written * 100 / total);
                        // Only surface whole-percent changes; the UI redraws per event.
                        if (pct != lastReported)
                        {
                            lastReported = pct;
                            DownloadPercent = pct;
                            StateChanged?.Invoke();
                        }
                    }
                }

                if (release.AssetSize > 0 && written != release.AssetSize)
                    throw new IOException($"Download incomplete ({written} of {release.AssetSize} bytes).");
            }

            // Only publish the final name once the bytes are complete, so a crashed
            // download can never be mistaken for a usable installer.
            TryDelete(target);
            File.Move(partial, target);

            DownloadPercent = 100;
            _log.Info($"Downloaded update installer to {target}");
            SetState(UpdatePhase.ReadyToInstall);
        }
        catch (OperationCanceledException)
        {
            TryDelete(partial);
            SetState(UpdatePhase.Error, "Download timed out.");
        }
        catch (Exception ex)
        {
            TryDelete(partial);
            _log.Warn($"Update download failed: {ex.Message}");
            SetState(UpdatePhase.Error, ex.Message);
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>
    /// Launches the downloaded installer unattended and returns true when the caller
    /// should now exit the app (setup waits for our mutex before touching files).
    /// </summary>
    public bool BeginInstall()
    {
        var release = Available;
        if (release is null || Phase != UpdatePhase.ReadyToInstall)
            return false;

        var setup = Path.Combine(AppStoragePaths.UpdatesDirectory, release.AssetName);
        if (!File.Exists(setup))
        {
            SetState(UpdatePhase.Error, "Downloaded installer is missing.");
            return false;
        }

        try
        {
            Directory.CreateDirectory(AppStoragePaths.LogsDirectory);
            var setupLog = Path.Combine(AppStoragePaths.LogsDirectory, "update-setup.log");

            // /RELAUNCH=1 is our own switch: the installer's [Code] gates the post-install
            // app start on it, because the normal [Run] entry is skipifsilent.
            var args = $"/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1 /LOG=\"{setupLog}\"";

            Process.Start(new ProcessStartInfo
            {
                FileName = setup,
                Arguments = args,
                UseShellExecute = true
            });

            _log.Info($"Launched update installer v{release.Version.ToString(3)}; exiting for the swap.");
            SetState(UpdatePhase.Installing);
            return true;
        }
        catch (Exception ex)
        {
            _log.Error($"Could not start the update installer: {ex.Message}");
            SetState(UpdatePhase.Error, ex.Message);
            return false;
        }
    }

    /// <summary>
    /// Removes interrupted downloads and installers for versions we're already past.
    /// Best effort — a locked or missing file must never affect startup.
    /// </summary>
    public void CleanUpdatesDirectory()
    {
        try
        {
            var dir = AppStoragePaths.UpdatesDirectory;
            if (!Directory.Exists(dir))
                return;

            foreach (var f in Directory.EnumerateFiles(dir, "*.partial"))
                TryDelete(f);

            foreach (var f in Directory.EnumerateFiles(dir, "ApolloFleet-Setup-v*.exe"))
            {
                var name = Path.GetFileNameWithoutExtension(f);
                var start = name.IndexOf("-v", StringComparison.OrdinalIgnoreCase);
                var end = name.LastIndexOf("-win", StringComparison.OrdinalIgnoreCase);
                if (start < 0 || end <= start)
                    continue;

                var tag = name[(start + 1)..end];
                if (UpdateFeed.TryParseVersionTag(tag, out var v) && !UpdateFeed.IsNewer(v, CurrentVersion))
                    TryDelete(f); // already installed (or older)
            }
        }
        catch
        {
            /* best effort */
        }
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path))
                File.Delete(path);
        }
        catch
        {
            /* best effort */
        }
    }
}
