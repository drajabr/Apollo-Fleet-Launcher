using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using ApolloFleet.Core;

namespace ApolloFleet.App.Services;

public sealed class FileLogWriter
{
    private const int MaxLines = 500;
    private readonly object _gate = new();
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
            try
            {
                Directory.CreateDirectory(AppStoragePaths.LogsDirectory);
                File.AppendAllText(
                    AppStoragePaths.SupervisorLogPath,
                    $"{DateTimeOffset.Now:O}\t[{level}]\t{message}{Environment.NewLine}");
            }
            catch
            {
                /* ignore */
            }
        });
        LogChanged?.Invoke(this, EventArgs.Empty);
    }

    public string Snapshot()
    {
        lock (_gate)
            return string.Join(Environment.NewLine, _buffer);
    }
}
