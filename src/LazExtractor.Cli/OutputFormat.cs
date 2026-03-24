namespace LazExtractor.Cli;

internal enum OutputFormat
{
    Txt,
    Dxf
}

internal static class OutputFormatExtensions
{
    public static string GetFileExtension(this OutputFormat format) =>
        format switch
        {
            OutputFormat.Txt => ".txt",
            OutputFormat.Dxf => ".dxf",
            _ => ".txt"
        };
}
