using System;
using System.IO;
using Microsoft.Win32.TaskScheduler;

namespace ApolloFleet.App.Services;

public sealed class WinUiScheduledTaskService
{
    public const string TaskName = "ApolloFleet";

    public void Sync(bool autoStart, string applicationExePath)
    {
        using var ts = new TaskService();
        if (autoStart)
        {
            var td = ts.NewTask();
            td.RegistrationInfo.Description = "Apollo Fleet Manager (ApolloFleet) — delayed logon start.";
            td.Principal.RunLevel = TaskRunLevel.Highest;
            td.Settings.Enabled = true;
            td.Settings.StartWhenAvailable = true;
            var trigger = (LogonTrigger)td.Triggers.Add(new LogonTrigger());
            trigger.Delay = TimeSpan.FromSeconds(30);
            td.Actions.Add(new ExecAction(applicationExePath));
            ts.RootFolder.RegisterTaskDefinition(TaskName, td, TaskCreation.CreateOrUpdate, null, null, TaskLogonType.InteractiveToken);
        }
        else
        {
            try
            {
                ts.RootFolder.DeleteTask(TaskName, false);
            }
            catch (FileNotFoundException)
            {
                /* no task */
            }
            catch
            {
                var t = ts.GetTask(TaskName);
                if (t is not null)
                    t.Enabled = false;
            }
        }
    }
}
