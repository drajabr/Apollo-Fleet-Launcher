param (
    [string]$exePath = "C:\Program Files\Apollo\sunshine.exe",
    [string]$workingDirectory = "C:\Program Files\Apollo\",
    [string]$sessionId = (Get-Process -PID $pid).SessionID,
    # Path to PsExec
    # You can download it from https://learn.microsoft.com/en-us/sysinternals/downloads/psexec
    [string]$psexecPath = ".\bin\PsTools\PsExec64.exe",
    # Adjust with the actual config files you want to start.
    # e.g. if you have only one config, leave only the first entry.
    [string[]]$exeParams = @(
        ".\config\fleet-1.conf"
        ,".\config\fleet-2.conf"
    )
)

# Self elevate the script
# Taken from https://github.com/itsmikethetech/Virtual-Display-Driver/blob/master/Community%20Scripts/toggle-VDD.ps1
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine -WindowStyle Hidden
        Exit
    }
}

# Generate commands dynamically
$commands = $exeParams | ForEach-Object {
    "powershell -Command `"start '$exePath' '$_' -WorkingDirectory '$workingDirectory' -WindowStyle Hidden`""
}

# Execute each command
foreach ($command in $commands) {
    Start-Process -FilePath $psexecPath -ArgumentList "-accepteula -i $sessionId -s $command" -WindowStyle Hidden
    Start-Sleep -Seconds 1  # Optional: Add a delay to avoid conflicts
}