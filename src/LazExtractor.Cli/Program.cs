using System;
using System.Globalization;
using System.IO;
using System.Threading;

namespace LazExtractor.Cli;

internal static class Program
{
    private const int CancelExitCode = 130;

    public static int Main(string[] args)
    {
        if (!ArgumentParser.TryParse(args, out var options, out var showHelp, out var error))
        {
            if (showHelp)
            {
                ArgumentParser.PrintUsage();
                return 0;
            }

            if (!string.IsNullOrWhiteSpace(error))
            {
                Console.Error.WriteLine(error);
            }

            ArgumentParser.PrintUsage();
            return 1;
        }

        var extractor = new LazCoordinateExtractor(new LaszipPointSourceFactory());
        using var cts = new CancellationTokenSource();
        Console.CancelKeyPress += (_, eventArgs) =>
        {
            eventArgs.Cancel = true;
            cts.Cancel();
        };

        try
        {
            var summary = extractor.Extract(options, cts.Token);
            Console.WriteLine(
                $"Hotovo: {summary.ProcessedFiles} souborů, {summary.ProcessedPoints.ToString("N0", CultureInfo.InvariantCulture)} bodů.");
            return 0;
        }
        catch (OperationCanceledException)
        {
            Console.Error.WriteLine("Zpracování přerušeno uživatelem.");
            return CancelExitCode;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Chyba: {ex.Message}");
            return 1;
        }
    }
}

internal static class ArgumentParser
{
    private static readonly string Usage = """
Použití:
  LazExtractor --input <soubor|složka> --output <soubor|složka> [--recursive] [--overwrite] [--format <txt|dxf>]

Volby:
  -i, --input        Vstupní LAZ/LAS soubor nebo složka.
  -o, --output       Výstupní TXT soubor nebo složka.
  -r, --recursive    Rekurzivní procházení vstupní složky (pokud je vstup složka).
  -f, --format       Formát výstupu: txt (výchozí) nebo dxf.
      --overwrite    Přepsat existující výstupní soubory.
  -h, --help         Zobrazí tuto nápovědu.
""";

    public static bool TryParse(
        string[] args,
        out ExtractionOptions options,
        out bool showHelp,
        out string? error)
    {
        options = default!;
        showHelp = false;
        error = null;

        string? input = null;
        string? output = null;
        var recursive = false;
        var overwrite = false;
        var format = OutputFormat.Txt;

        for (var i = 0; i < args.Length; i++)
        {
            var current = args[i];
            switch (current)
            {
                case "-h":
                case "--help":
                    showHelp = true;
                    break;
                case "-i":
                case "--input":
                    if (!TryReadValue(args, ref i, out input))
                    {
                        error = "Chybí hodnota pro --input.";
                        return false;
                    }
                    break;
                case "-o":
                case "--output":
                    if (!TryReadValue(args, ref i, out output))
                    {
                        error = "Chybí hodnota pro --output.";
                        return false;
                    }
                    break;
                case "-r":
                case "--recursive":
                    recursive = true;
                    break;
                case "--overwrite":
                    overwrite = true;
                    break;
                case "-f":
                case "--format":
                    if (!TryReadValue(args, ref i, out var formatValue))
                    {
                        error = "Chybí hodnota pro --format.";
                        return false;
                    }

                    if (!TryParseFormat(formatValue!, out format, out error))
                    {
                        return false;
                    }
                    break;
                default:
                    error = $"Neznámý argument '{current}'.";
                    return false;
            }
        }

        if (showHelp)
        {
            return false;
        }

        if (string.IsNullOrWhiteSpace(input) || string.IsNullOrWhiteSpace(output))
        {
            error = "Musíte zadat --input i --output.";
            return false;
        }

        options = new ExtractionOptions(
            Path.GetFullPath(input),
            Path.GetFullPath(output),
            recursive,
            overwrite,
            format);
        return true;
    }

    public static void PrintUsage() => Console.WriteLine(Usage);

    private static bool TryReadValue(string[] args, ref int index, out string? value)
    {
        if (index + 1 >= args.Length)
        {
            value = null;
            return false;
        }

        value = args[++index];
        return true;
    }

    private static bool TryParseFormat(string value, out OutputFormat format, out string? error)
    {
        if (string.Equals(value, "txt", StringComparison.OrdinalIgnoreCase))
        {
            format = OutputFormat.Txt;
            error = null;
            return true;
        }

        if (string.Equals(value, "dxf", StringComparison.OrdinalIgnoreCase))
        {
            format = OutputFormat.Dxf;
            error = null;
            return true;
        }

        format = OutputFormat.Txt;
        error = "Neznámý formát. Povolené hodnoty jsou 'txt' a 'dxf'.";
        return false;
    }
}
