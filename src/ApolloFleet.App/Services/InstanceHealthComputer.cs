using System;
using System.Diagnostics;
using System.Net.Sockets;
using ApolloFleet.Core;

namespace ApolloFleet.App.Services;

public sealed class InstanceHealthComputer : IInstanceHealthComputer
{
    public InstanceRunState GetProcessState(int? pid)
    {
        if (pid is null or 0)
            return InstanceRunState.Stopped;
        try
        {
            using var p = Process.GetProcessById(pid.Value);
            // Confirm the PID is actually sunshine — PIDs are recycled, so a dead
            // instance's PID may now belong to an unrelated process.
            return string.Equals(p.ProcessName, "sunshine", StringComparison.OrdinalIgnoreCase)
                ? InstanceRunState.Running
                : InstanceRunState.Stopped;
        }
        catch
        {
            return InstanceRunState.Stopped;
        }
    }

    public bool IsPortListening(int port)
    {
        try
        {
            using var client = new TcpClient();
            var ar = client.BeginConnect("127.0.0.1", port, null, null);
            var ok = ar.AsyncWaitHandle.WaitOne(TimeSpan.FromMilliseconds(250));
            if (!ok)
            {
                client.Close();
                return false;
            }

            client.EndConnect(ar);
            return client.Connected;
        }
        catch
        {
            return false;
        }
    }
}
