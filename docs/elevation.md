# Elevation and Sunshine launch (ApolloFleet)

## Goal

Apollo (`sunshine.exe`) must run in the **interactive user session** with access to the desktop, audio devices, and GPU stack. Starting it as a child of a normal WinUI process usually satisfies this. Some setups still require launching via a **session-aware helper** (legacy AutoHotkey builds used PaExec-style tools).

## Chosen approach

`ApolloFleet.App` uses a single interface:

- `IProcessLauncher.StartSunshineAsync(sunshineExePath, configPath, instanceId, helperExePath, ...)`

### 1. Direct start (default)

If **no** helper executable is configured, the app uses `Process.Start` with `UseShellExecute = false` and `CreateNoWindow = true` (sunshine.exe is a console-subsystem binary — without `CREATE_NO_WINDOW` every instance pops a visible console), passing the config file as the argument. The new process runs in the same security context as ApolloFleet (standard user, interactive session).

Because instances run unelevated, each instance's `.conf` points `cert` / `pkey` (TLS material) into the user-writable fleet directory; Sunshine generates them on first launch. Leaving those at their defaults makes Sunshine resolve them against its install directory and die with `use_certificate_chain_file: Access is denied` when ApolloFleet is not elevated.

**Use when:** You run ApolloFleet at logon as your user and Sunshine does not need a different token.

### 2. PaExec-compatible helper (optional)

If the user sets **Optional PaExec-compatible helper** in the UI (e.g. path to `paexec.exe`), ApolloFleet starts Sunshine the same way the legacy AHK launcher did: helper runs PowerShell in the **active console session** (`WTSGetActiveConsoleSessionId`) to `Start-Process` Sunshine hidden, and writes the PID to a temp file.

Bundled helper locations are auto-probed **only when ApolloFleet itself is elevated** — PaExec-style session launch fails without administrator rights (the legacy AHK build ran with `requireAdministrator`). If a helper attempt yields no PID, the launcher **falls back to direct start** instead of reporting failure.

**Use when:** Direct start fails because Sunshine must be elevated or session-placed in a way that only the helper provides.

**Caveats:** Third-party helpers can trigger **defender / AV heuristics**. Prefer **code signing** for production distribution when budget allows. Document the helper path in your own runbooks; ApolloFleet does not ship PaExec.

## Privileges and UAC

- ApolloFleet itself runs **asInvoker** (see `app.manifest`).
- Sunshine may still request elevation via its own manifest; that is independent of ApolloFleet.
- If UAC prompts appear per instance, consider adjusting Sunshine install rights or using the helper path documented above.

## Failures

- If no PID is returned, the **process supervisor** retries with backoff and logs to `%LocalAppData%\ApolloFleet\logs\supervisor.log`.
- Task Scheduler / `ApolloService` interactions are logged there as well.

## References

- Legacy behavior: `Apollo Fleet.ahk` (`RunPsExecAndGetPID`, `MaintainInstance`).
- Product plan: `docs/winui-port.plan.md` (Step 0 — elevation spike).
