using System;
using System.IO;
using System.Text;

namespace LazExtractor.Cli;

internal interface IPointWriter : IDisposable
{
    void Write(Point3D point);
}

internal static class PointWriterFactory
{
    public static IPointWriter Create(OutputFormat format, Stream stream) =>
        format switch
        {
            OutputFormat.Txt => new TxtPointWriter(stream),
            OutputFormat.Dxf => new DxfPointWriter(stream),
            _ => new TxtPointWriter(stream)
        };
}

internal sealed class TxtPointWriter : IPointWriter
{
    private readonly StreamWriter _writer;

    public TxtPointWriter(Stream stream)
    {
        _writer = new StreamWriter(stream, Encoding.ASCII, bufferSize: 1 << 16, leaveOpen: false)
        {
            NewLine = "\n"
        };
    }

    public void Write(Point3D point)
    {
        _writer.Write(CoordinateFormatter.Format(point.X));
        _writer.Write(' ');
        _writer.Write(CoordinateFormatter.Format(point.Y));
        _writer.Write(' ');
        _writer.WriteLine(CoordinateFormatter.Format(point.Z));
    }

    public void Dispose()
    {
        _writer.Flush();
        _writer.Dispose();
    }
}

internal sealed class DxfPointWriter : IPointWriter
{
    private const string LayerName = "Laz Points";
    private readonly StreamWriter _writer;
    private bool _isDisposed;

    public DxfPointWriter(Stream stream)
    {
        _writer = new StreamWriter(stream, Encoding.ASCII, bufferSize: 1 << 16, leaveOpen: false)
        {
            NewLine = "\r\n"
        };
        WritePreamble();
    }

    public void Write(Point3D point)
    {
        WriteGroup("0", "POINT");
        WriteGroup("8", LayerName);
        WriteGroup("10", CoordinateFormatter.Format(point.X));
        WriteGroup("20", CoordinateFormatter.Format(point.Y));
        WriteGroup("30", CoordinateFormatter.Format(point.Z));
    }

    public void Dispose()
    {
        if (_isDisposed)
        {
            return;
        }

        WriteEntitiesEpilogue();
        _writer.Flush();
        _writer.Dispose();
        _isDisposed = true;
    }

    private void WritePreamble()
    {
        // HEADER
        WriteGroup("0", "SECTION");
        WriteGroup("2", "HEADER");
        WriteGroup("0", "ENDSEC");

        // TABLES with single layer definition.
        WriteGroup("0", "SECTION");
        WriteGroup("2", "TABLES");
        WriteGroup("0", "TABLE");
        WriteGroup("2", "LAYER");
        WriteGroup("70", "1");
        WriteGroup("0", "LAYER");
        WriteGroup("2", LayerName);
        WriteGroup("70", "0");
        WriteGroup("62", "7");
        WriteGroup("6", "CONTINUOUS");
        WriteGroup("0", "ENDTAB");
        WriteGroup("0", "ENDSEC");

        // ENTITIES start.
        WriteGroup("0", "SECTION");
        WriteGroup("2", "ENTITIES");
    }

    private void WriteEntitiesEpilogue()
    {
        WriteGroup("0", "ENDSEC");
        WriteGroup("0", "EOF");
    }

    private void WriteGroup(string code, string value)
    {
        _writer.WriteLine(code);
        _writer.WriteLine(value);
    }
}
