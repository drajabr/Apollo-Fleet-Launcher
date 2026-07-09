# Elevation and Sunshine launch (ApolloFleet)

## Goal

Apollo (`sunshine.exe`) must run in the **interactive user session** with access to the desktop, audio devices, and GPU stack. Starting it as a child of a normal WinUI process usually satisfies this. Some setups still require launching via a **session-aware helper** (legacy AutoHotkey builds used PaExec-style tools).

## Chosen approach

`ApolloFleet.App` uses a single interface:

- `IProcessLauncher.StartSunshineAsync(sunshineExePath, configPath, instanceId, helperExePath, ...)`

### 1. Direct start (default, always used unless a helper is configured)

The app uses `Process.Start` with `UseShellExecute = false` and `CreateNoWindow = true` (sunshine.exe is a console-subsystem binary — without `CREATE_NO_WINDOW` every instance pops a visible console), passing the config file as the argument. The child **inherits the launcher's token and session**:

- Launcher runs **unelevated** → Sunshine runs unelevated.
- Launcher runs **elevated** (via "Run as administrator" or the Highest-privilege logon task) → Sunshine runs **elevated too, with no additional UAC prompt** and no helper service.

This is why the launcher does **not** auto-probe a bundled PaExec: doing so spun up a service and could surface extra consent / AV prompts even when the launcher was already elevated. A direct child start inherits elevation silently, which is what we want.

Because unelevated instances can't write into the Apollo install dir, each instance's `.conf` points `cert` / `pkey` (TLS material) into the user-writable fleet directory; Sunshine generates them on first launch. Leaving those at their defaults makes Sunshine resolve them against its install directory and die with `use_certificate_chain_file: Access is denied` when ApolloFleet is not elevated.

### 2. PaExec-compatible helper (optional, explicit only)

If — and only if — the user sets an **Optional PaExec-compatible helper** path in settings (e.g. `paexec.exe`), ApolloFleet starts Sunshine the way the legacy AHK launcher did: the helper runs PowerShell in the **active console session** (`WTSGetActiveConsoleSessionId`) to `Start-Process` Sunshine hidden and writes the PID to a temp file. If the helper yields no PID, the launcher **falls back to direct start**.

**Use when:** the launcher runs from a true session-0 service context and Sunshine must be placed into the interactive session — a case the direct child start above does not cover.

**Caveats:** Third-party helpers can trigger **defender / AV heuristics**. ApolloFleet no longer ships PaExec; supply your own path.

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
