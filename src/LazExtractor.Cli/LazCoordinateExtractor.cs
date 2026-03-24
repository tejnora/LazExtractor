using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

namespace LazExtractor.Cli;

internal sealed class LazCoordinateExtractor
{
    private static readonly string[] SupportedExtensions = [".las", ".laz"];
    private readonly ILasPointSourceFactory _pointSourceFactory;

    public LazCoordinateExtractor(ILasPointSourceFactory pointSourceFactory)
    {
        _pointSourceFactory = pointSourceFactory;
    }

    public ExtractionSummary Extract(ExtractionOptions options, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var inputFiles = ResolveInputFiles(options.InputPath, options.Recursive);
        if (inputFiles.Count == 0)
        {
            throw new InvalidOperationException("Nebyl nalezen žádný LAZ/LAS soubor.");
        }

        var planner = new OutputPlanner(options, inputFiles);
        var processedFiles = 0;
        long processedPoints = 0;

        foreach (var lazFile in inputFiles)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var outputFile = planner.GetOutputPath(lazFile);
            var points = ExtractSingleFile(lazFile, outputFile, options.Overwrite, options.Format, cancellationToken);
            processedFiles++;
            processedPoints += points;
            Console.WriteLine($"→ {Path.GetFileName(lazFile)} ({points.ToString("N0", CultureInfo.InvariantCulture)} bodů)");
        }

        return new ExtractionSummary(processedFiles, processedPoints);
    }

    private static IReadOnlyList<string> ResolveInputFiles(string inputPath, bool recursive)
    {
        if (File.Exists(inputPath))
        {
            if (!HasSupportedExtension(inputPath))
            {
                throw new InvalidOperationException($"Soubor '{inputPath}' nemá podporovanou příponu (.laz/.las).");
            }

            return new List<string> { Path.GetFullPath(inputPath) };
        }

        if (Directory.Exists(inputPath))
        {
            var searchOption = recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
            var files = Directory
                .EnumerateFiles(inputPath, "*.*", searchOption)
                .Where(HasSupportedExtension)
                .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
                .Select(Path.GetFullPath)
                .ToList();

            if (files.Count == 0)
            {
                throw new InvalidOperationException($"Ve složce '{inputPath}' nejsou žádné LAZ/LAS soubory.");
            }

            return files;
        }

        throw new FileNotFoundException($"Cesta '{inputPath}' neexistuje.");
    }

    private long ExtractSingleFile(
        string inputFile,
        string outputFile,
        bool overwrite,
        OutputFormat format,
        CancellationToken cancellationToken)
    {
        if (!overwrite && File.Exists(outputFile))
        {
            throw new IOException($"Výstupní soubor '{outputFile}' již existuje. Přidejte --overwrite pro přepsání.");
        }

        var outputDirectory = Path.GetDirectoryName(outputFile);
        if (!string.IsNullOrEmpty(outputDirectory))
        {
            Directory.CreateDirectory(outputDirectory);
        }

        using var source = _pointSourceFactory.Open(inputFile);
        using var progress = new ProgressPrinter(Path.GetFileName(inputFile) ?? inputFile, source.TotalPoints);
        progress.Report(source.ProcessedPoints);
        using var stream = new FileStream(outputFile, FileMode.Create, FileAccess.Write, FileShare.Read);
        using var writer = PointWriterFactory.Create(format, stream);

        long written = 0;
        while (source.TryReadNext(out var point))
        {
            cancellationToken.ThrowIfCancellationRequested();
            writer.Write(point);
            written++;
            progress.Report(source.ProcessedPoints);
        }

        progress.Complete();
        return written;
    }

    private static bool HasSupportedExtension(string path)
    {
        var extension = Path.GetExtension(path);
        return SupportedExtensions.Any(ext => string.Equals(ext, extension, StringComparison.OrdinalIgnoreCase));
    }

    private sealed class OutputPlanner
    {
        private readonly string _outputDirectory;
        private readonly string? _explicitFile;
        private readonly string? _inputRoot;
        private readonly string _outputExtension;

        public OutputPlanner(ExtractionOptions options, IReadOnlyList<string> inputFiles)
        {
            var inputIsDirectory = Directory.Exists(options.InputPath);
            _inputRoot = inputIsDirectory ? Path.GetFullPath(options.InputPath) : null;
            _outputExtension = options.Format.GetFileExtension();
            var requiresDirectory = inputFiles.Count > 1 || inputIsDirectory;
            var outputExistsDirectory = Directory.Exists(options.OutputPath);
            var looksLikeDirectory = !Path.HasExtension(options.OutputPath);
            var treatAsDirectory = requiresDirectory
                                   || outputExistsDirectory
                                   || EndsWithDirectorySeparator(options.OutputPath)
                                   || looksLikeDirectory;

            if (!treatAsDirectory && inputFiles.Count > 1)
            {
                throw new InvalidOperationException("Více vstupních souborů vyžaduje výstupní složku.");
            }

            if (treatAsDirectory)
            {
                _outputDirectory = EnsureDirectory(options.OutputPath);
            }
            else
            {
                _explicitFile = options.OutputPath;
                var targetDirectory = Path.GetDirectoryName(_explicitFile);
                if (string.IsNullOrEmpty(targetDirectory))
                {
                    targetDirectory = Directory.GetCurrentDirectory();
                    _explicitFile = Path.Combine(targetDirectory, Path.GetFileName(_explicitFile)!);
                }
                Directory.CreateDirectory(targetDirectory);
                _outputDirectory = targetDirectory;
            }
        }

        public string GetOutputPath(string inputFile)
        {
            if (_explicitFile != null)
            {
                return _explicitFile;
            }

            var fileName = Path.GetFileNameWithoutExtension(inputFile) + _outputExtension;
            if (_inputRoot == null)
            {
                return Path.Combine(_outputDirectory, fileName);
            }

            var relativePath = Path.GetRelativePath(_inputRoot, inputFile);
            var relativeDirectory = Path.GetDirectoryName(relativePath);
            return string.IsNullOrEmpty(relativeDirectory) || relativeDirectory == "."
                ? Path.Combine(_outputDirectory, fileName)
                : Path.Combine(_outputDirectory, relativeDirectory, fileName);
        }

        private static bool EndsWithDirectorySeparator(string path) =>
            path.EndsWith(Path.DirectorySeparatorChar)
            || path.EndsWith(Path.AltDirectorySeparatorChar);

        private static string EnsureDirectory(string path)
        {
            Directory.CreateDirectory(path);
            return Path.GetFullPath(path);
        }
    }
}

internal readonly record struct ExtractionSummary(int ProcessedFiles, long ProcessedPoints);

internal readonly record struct Point3D(double X, double Y, double Z);

internal interface ILasPointSourceFactory
{
    ILasPointSource Open(string filePath);
}

internal interface ILasPointSource : IDisposable
{
    long TotalPoints { get; }
    long ProcessedPoints { get; }
    bool TryReadNext(out Point3D point);
}
