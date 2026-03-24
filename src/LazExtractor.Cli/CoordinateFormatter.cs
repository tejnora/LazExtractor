using System.Globalization;

namespace LazExtractor.Cli;

internal static class CoordinateFormatter
{
    private const string NumberFormat = "0.0000";

    public static string Format(double value) =>
        value.ToString(NumberFormat, CultureInfo.InvariantCulture);
}
