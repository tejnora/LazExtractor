using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading;
using LazExtractor.Cli;

namespace LazExtractor.Tests;

public sealed class LazCoordinateExtractorTests
{
    [Fact]
    public void Extract_SingleFile_WritesExpectedLines()
    {
        var tempRoot = CreateTemporaryDirectory();
        try
        {
            var inputFile = Path.Combine(tempRoot, "source.laz");
            File.WriteAllText(inputFile, string.Empty);
            var outputDirectory = Path.Combine(tempRoot, "out");
            Directory.CreateDirectory(outputDirectory);

            var options = new ExtractionOptions(
                inputFile,
                outputDirectory,
                Recursive: false,
                Overwrite: true,
                Format: OutputFormat.Txt);

            var expectedPoints = new[]
            {
                new Point3D(10.5, -20.25, 0.0),
                new Point3D(0.123456789, 98765.4321, -12.0)
            };

            var extractor = new LazCoordinateExtractor(new FakePointSourceFactory(expectedPoints));

            var summary = extractor.Extract(options, CancellationToken.None);

            Assert.Equal(1, summary.ProcessedFiles);
            Assert.Equal(expectedPoints.Length, summary.ProcessedPoints);

            var outputFile = Path.Combine(outputDirectory, "source.txt");
            var lines = File.ReadAllLines(outputFile);
            Assert.Equal(expectedPoints.Length, lines.Length);

            var expectedLines = expectedPoints
                .Select(p => string.Join(" ", Format(p.X), Format(p.Y), Format(p.Z)))
                .ToArray();

            Assert.Equal(expectedLines, lines);
        }
        finally
        {
            Directory.Delete(tempRoot, recursive: true);
        }
    }

    [Fact]
    public void Extract_SingleFile_WritesDxfPoints()
    {
        var tempRoot = CreateTemporaryDirectory();
        try
        {
            var inputFile = Path.Combine(tempRoot, "source.laz");
            File.WriteAllText(inputFile, string.Empty);
            var outputDirectory = Path.Combine(tempRoot, "out");
            Directory.CreateDirectory(outputDirectory);

            var options = new ExtractionOptions(
                inputFile,
                outputDirectory,
                Recursive: false,
                Overwrite: true,
                Format: OutputFormat.Dxf);

            var expectedPoints = new[]
            {
                new Point3D(1.0, 2.0, 3.0),
                new Point3D(-4.5, 0.0, 10.25)
            };

            var extractor = new LazCoordinateExtractor(new FakePointSourceFactory(expectedPoints));

            var summary = extractor.Extract(options, CancellationToken.None);

            Assert.Equal(1, summary.ProcessedFiles);
            Assert.Equal(expectedPoints.Length, summary.ProcessedPoints);

            var outputFile = Path.Combine(outputDirectory, "source.dxf");
            Assert.True(File.Exists(outputFile));
            var dxf = File.ReadAllText(outputFile);

            Assert.Contains("2\r\nENTITIES\r\n", dxf);
            foreach (var point in expectedPoints)
            {
                var block = string.Join(
                    "\r\n",
                    "0",
                    "POINT",
                    "8",
                    "Laz Points",
                    "10",
                    Format(point.X),
                    "20",
                    Format(point.Y),
                    "30",
                    Format(point.Z));
                Assert.Contains(block, dxf);
            }

            Assert.EndsWith("0\r\nEOF\r\n", dxf);
        }
        finally
        {
            Directory.Delete(tempRoot, recursive: true);
        }
    }

    private static string CreateTemporaryDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), "LazExtractorTests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(path);
        return path;
    }

    private static string Format(double value) =>
        value.ToString("0.0000", CultureInfo.InvariantCulture);

    private sealed class FakePointSourceFactory : ILasPointSourceFactory
    {
        private readonly IReadOnlyList<Point3D> _points;

        public FakePointSourceFactory(IReadOnlyList<Point3D> points)
        {
            _points = points;
        }

        public ILasPointSource Open(string filePath) => new FakePointSource(_points);

        private sealed class FakePointSource : ILasPointSource
        {
            private readonly IReadOnlyList<Point3D> _points;
            private int _index;

            public FakePointSource(IReadOnlyList<Point3D> points)
            {
                _points = points;
            }

            public long TotalPoints => _points.Count;

            public long ProcessedPoints => _index;

            public bool TryReadNext(out Point3D point)
            {
                if (_index >= _points.Count)
                {
                    point = default;
                    return false;
                }

                point = _points[_index++];
                return true;
            }

            public void Dispose()
            {
                // Nothing to dispose in the fake implementation.
            }
        }
    }
}
