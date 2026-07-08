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

    public void DisableAndStopApolloService()
    {
        try
        {
            using var sc = new ServiceController(ServiceName);
            if (sc.Status == ServiceControllerStatus.Running)
                sc.Stop();
            sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30));
        }
        catch
        {
            /* ignore */
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
