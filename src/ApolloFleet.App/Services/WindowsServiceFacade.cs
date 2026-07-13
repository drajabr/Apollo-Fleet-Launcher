using System;
using System.Diagnostics;
using System.ServiceProcess;

namespace ApolloFleet.App.Services;

public sealed class WindowsServiceFacade
{
    private const string ServiceName = "ApolloService";

    public bool IsApolloServiceInstalled()
    {
        try
        {
            using var sc = new ServiceController(ServiceName);
            _ = sc.Status;
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// True when the stock ApolloService exists and is not fully stopped (running,
    /// starting, or in any pending state). When this is true the service is actively
    /// managing its own sunshine.exe, so the fleet must not force-kill sunshine — the
    /// service would just respawn it, producing an endless restart loop.
    /// </summary>
    public bool IsApolloServiceRunning()
    {
        try
        {
            using var sc = new ServiceController(ServiceName);
            return sc.Status != ServiceControllerStatus.Stopped;
        }
        catch
        {
            // Not installed / not queryable → treat as not running.
            return false;
        }
    }

    /// <summary>
    /// Stops and disables the stock service. Returns true only if the service ended up
    /// confirmed Stopped, so callers can tell when it could NOT be disabled gracefully
    /// (insufficient rights, protected service, re-enabled out of band).
    /// </summary>
    public bool DisableAndStopApolloService()
    {
        var stopped = false;
        try
        {
            using var sc = new ServiceController(ServiceName);
            if (sc.Status == ServiceControllerStatus.Running)
                sc.Stop();
            sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30));
            sc.Refresh();
            stopped = sc.Status == ServiceControllerStatus.Stopped;
        }
        catch
        {
            /* ignore — reported via the returned flag */
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "sc",
                Arguments = "config ApolloService start= disabled",
                UseShellExecute = false,
                CreateNoWindow = true
            })?.WaitForExit(5000);
        }
        catch
        {
            /* ignore */
        }

        return stopped;
    }

    public void EnableAndStartApolloService()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "sc",
                Arguments = "config ApolloService start= auto",
                UseShellExecute = false,
                CreateNoWindow = true
            })?.WaitForExit(5000);
        }
        catch
        {
            /* ignore */
        }

        try
        {
            using var sc = new ServiceController(ServiceName);
            sc.Start();
            sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30));
        }
        catch
        {
            /* ignore */
        }
    }
}
