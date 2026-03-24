using System;
using System.Globalization;

namespace LazExtractor.Cli;

internal sealed class ProgressPrinter : IDisposable
{
    private static readonly TimeSpan UpdateInterval = TimeSpan.FromMilliseconds(300);

    private readonly string _fileName;
    private readonly long _total;
    private readonly string _totalText;
    private readonly bool _supportsInline;
    private DateTime _lastWrite = DateTime.MinValue;
    private long _lastReported;
    private bool _completed;
    private int _lastRenderedLength;

    public ProgressPrinter(string fileName, long total)
    {
        _fileName = fileName;
        _total = total;
        _totalText = total > 0 ? total.ToString("N0", CultureInfo.InvariantCulture) : "neznámý";
        _supportsInline = !Console.IsOutputRedirected;
        Console.WriteLine($"Zpracování {_fileName} ({_totalText} bodů):");
    }

    public void Report(long current)
    {
        if (_completed || current == _lastReported)
        {
            return;
        }

        var now = DateTime.UtcNow;
        if (current < _total && now - _lastWrite < UpdateInterval)
        {
            return;
        }

        _lastWrite = now;
        _lastReported = current;

        var line = BuildLine(current);

        if (_supportsInline)
        {
            if (_lastRenderedLength > line.Length)
            {
                line = line.PadRight(_lastRenderedLength);
            }

            Console.Write($"\r{line}");
            _lastRenderedLength = line.Length;
        }
        else
        {
            Console.WriteLine(line);
        }
    }

    public void Complete()
    {
        if (_completed)
        {
            return;
        }

        _completed = true;
        Report(_total <= 0 ? _lastReported : _total);
        if (_supportsInline)
        {
            Console.WriteLine();
        }
    }

    public void Dispose() => Complete();

    private string BuildLine(long current)
    {
        var percentage = _total > 0
            ? (current / (double)_total).ToString("P1", CultureInfo.InvariantCulture)
            : "?";

        return $"    {current.ToString("N0", CultureInfo.InvariantCulture)}/{_totalText} ({percentage})";
    }
}
