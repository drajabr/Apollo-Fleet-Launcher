# Elevation and Sunshine launch (ApolloFleet)

## Goal

Apollo (`sunshine.exe`) must run in the **interactive console session** *and as SYSTEM* to be fully useful: capturing the **UAC secure desktop** (the dimmed elevation prompt) is only possible for a process running as **SYSTEM in the interactive session**. An elevated-*admin* process cannot grab the secure desktop — this is a hard Windows restriction, and it's why the stock `ApolloService` runs Sunshine through a SYSTEM service wrapper (`sunshinesvc.exe`).

## Chosen approach

`ApolloFleet.App` uses a single interface:

- `IProcessLauncher.StartSunshineAsync(sunshineExePath, configPath, instanceId, helperExePath, ...)`

### 1. SYSTEM launch via bundled PaExec (default)

ApolloFleet ships `paexec.exe` next to the app and, because it is always elevated (`requireAdministrator`), uses it to start each instance as **SYSTEM in the active console session**: `paexec -accepteula -i <WTSGetActiveConsoleSessionId> -s powershell.exe -Command "Start-Process -WindowStyle Hidden sunshine <conf>"`. The PID is written to a temp file and read back (with a fallback that detects the newly-spawned `sunshine` process). Running as SYSTEM in the interactive session is what lets Apollo capture the UAC secure desktop, matching the stock service's behavior.

A user may override the helper with their own path in settings; an explicit path wins over the bundled one.

Each instance's `.conf` points `cert` / `pkey` (TLS material) and all state into the machine-wide fleet directory (`%ProgramData%\ApolloFleet\fleet`), which SYSTEM can write; Sunshine generates them on first launch. Leaving those at their defaults makes Sunshine resolve them against its install directory and die with `use_certificate_chain_file: Access is denied`.

### 2. Direct elevated start (fallback)

If no helper is found (or it fails to yield a PID), the app falls back to `Process.Start` with `UseShellExecute = false` and `CreateNoWindow = true`, inheriting the launcher's elevated-admin token. This works for normal desktop/audio/GPU capture **but cannot capture the UAC secure desktop** — restore `paexec.exe` next to the app (or set a helper path) to get that back.

**Caveats:** PaExec is a third-party tool and can trip **Defender / AV heuristics**; you may need an exclusion. It briefly installs a per-launch service to obtain the SYSTEM token.

## Privileges and UAC

- ApolloFleet is manifested **requireAdministrator** (see `app.manifest`): it **always** runs elevated, because managing Apollo (service control, session-correct capture, elevated instances) is impossible otherwise.
- Manual launch shows **one** UAC prompt. After that, everything downstream — Sunshine instances, service control, task registration — runs elevated **in-process with no further prompts**. Relaunches (reload / language change) started from the already-elevated process do not prompt again.
- The auto-start **logon task** is registered with `TaskRunLevel.Highest`, so at logon it starts ApolloFleet elevated with **no** prompt at all.
- Sunshine may still request elevation via its own manifest; that is independent of ApolloFleet.
- If UAC prompts appear per instance, consider adjusting Sunshine install rights or using the helper path documented above.

## Failures

- If no PID is returned, the **process supervisor** retries with backoff and logs to `%LocalAppData%\ApolloFleet\logs\supervisor.log`.
- Task Scheduler / `ApolloService` interactions are logged there as well.

## References

- Legacy behavior: `Apollo Fleet.ahk` (`RunPsExecAndGetPID`, `MaintainInstance`).
- Product plan: `docs/winui-port.plan.md` (Step 0 — elevation spike).
