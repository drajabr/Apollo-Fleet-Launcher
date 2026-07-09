using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using ApolloFleet.Core;

namespace ApolloFleet.App.Services;

public sealed class FileLogWriter
{
    private const int MaxLines = 500;
    private const long MaxFileBytes = 2 * 1024 * 1024; // rotate the on-disk log at 2 MB
    private readonly object _gate = new();
    private readonly object _fileGate = new();
    private readonly LinkedList<string> _buffer = new();

    public event EventHandler? LogChanged;

    public void Info(string message) => Write("INFO ", message);
    public void Warn(string message) => Write("WARN ", message);
    public void Error(string message) => Write("ERROR", message);

    private void Write(string level, string message)
    {
        var line = $"{DateTime.Now:HH:mm:ss} [{level}] {message}";
        lock (_gate)
        {
            _buffer.AddLast(line);
            while (_buffer.Count > MaxLines)
                _buffer.RemoveFirst();
        }
        _ = Task.Run(() =>
        {
            // Serialize disk writes: concurrent AppendAllText from the supervisor's
            // timers otherwise throws sharing violations (and would drop lines).
            lock (_fileGate)
            {
                try
                {
                    Directory.CreateDirectory(AppStoragePaths.LogsDirectory);
                    var path = AppStoragePaths.SupervisorLogPath;
                    RotateIfLarge(path);
                    File.AppendAllText(
                        path,
                        $"{DateTimeOffset.Now:O}\t[{level}]\t{message}{Environment.NewLine}");
                }
                catch
                {
                    /* ignore */
                }
            }
        });
        LogChanged?.Invoke(this, EventArgs.Empty);
    }

    // Caller holds _fileGate.
    private static void RotateIfLarge(string path)
    {
        try
        {
            var fi = new FileInfo(path);
            if (!fi.Exists || fi.Length < MaxFileBytes)
                return;
            var old = path + ".old";
            if (File.Exists(old))
                File.Delete(old);
            File.Move(path, old);
        }
        catch
        {
            /* if rotation fails, keep appending to the current file */
        }
    }

    public string Snapshot()
    {
        lock (_gate)
            return string.Join(Environment.NewLine, _buffer);
    }
}
