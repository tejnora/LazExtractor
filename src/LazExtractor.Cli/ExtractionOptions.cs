namespace LazExtractor.Cli;

internal sealed record ExtractionOptions(
    string InputPath,
    string OutputPath,
    bool Recursive,
    bool Overwrite);
