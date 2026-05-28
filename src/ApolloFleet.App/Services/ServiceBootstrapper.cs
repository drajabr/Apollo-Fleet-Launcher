using Microsoft.Extensions.DependencyInjection;
using ApolloFleet.App.ViewModels;
using ApolloFleet.Core;

namespace ApolloFleet.App.Services;

public static class ServiceBootstrapper
{
    public static ServiceProvider Create()
    {
        var c = new ServiceCollection();
        c.AddSingleton<ISettingsStore, SettingsStore>();
        c.AddSingleton<IFleetConfigurationApplier, FleetConfigurationApplier>();
        c.AddSingleton<IInstanceHealthComputer, InstanceHealthComputer>();
        c.AddSingleton<IProcessLauncher, ProcessLauncher>();
        c.AddSingleton<FileLogWriter>();
        c.AddSingleton<WinUiScheduledTaskService>();
        c.AddSingleton<WindowsServiceFacade>();
        c.AddSingleton<AudioVolumeSink>();
        c.AddSingleton<ProcessSupervisor>();
        c.AddSingleton<FleetCoordinator>();
        c.AddSingleton<MainViewModel>();
        return c.BuildServiceProvider();
    }
}
