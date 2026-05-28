using System;
using System.Collections.Generic;
using NAudio.CoreAudioApi;

namespace ApolloFleet.App.Services;

public sealed class AudioVolumeSink : IDisposable
{
    private readonly MMDeviceEnumerator _enumerator = new();

    public void SyncPlaybackToSessions(IReadOnlyCollection<int> sunshineProcessIds)
    {
        if (sunshineProcessIds.Count == 0)
            return;

        try
        {
            using var device = _enumerator.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia);
            var master = device.AudioEndpointVolume.MasterVolumeLevelScalar;
            var mute = device.AudioEndpointVolume.Mute;
            var sessions = device.AudioSessionManager.Sessions;
            for (var i = 0; i < sessions.Count; i++)
            {
                var session = sessions[i];
                try
                {
                    var pid = (int)session.GetProcessID;
                    if (!sunshineProcessIds.Contains(pid))
                        continue;
                    var vol = session.SimpleAudioVolume;
                    vol.Volume = master;
                    vol.Mute = mute;
                }
                catch
                {
                    /* ignore */
                }
                finally
                {
                    session.Dispose();
                }
            }
        }
        catch
        {
            /* ignore */
        }
    }

    public void Dispose() => _enumerator.Dispose();
}
