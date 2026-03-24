using System;
using LASzip.Net;

namespace LazExtractor.Cli;

internal sealed class LaszipPointSourceFactory : ILasPointSourceFactory
{
    public ILasPointSource Open(string filePath) => new LaszipPointSource(filePath);

    private sealed class LaszipPointSource : ILasPointSource
    {
        private readonly string _filePath;
        private readonly laszip _handle;
        private readonly laszip_header _header;
        private readonly laszip_point _point;
        private readonly long _totalPoints;
        private long _remaining;
        private bool _readerOpen;
        private bool _disposed;

        public LaszipPointSource(string filePath)
        {
            _filePath = filePath;
            _handle = laszip.create();

            if (_handle.open_reader(filePath, out _) != 0)
            {
                throw new InvalidOperationException(BuildError("Nepodařilo se otevřít soubor"));
            }

            _readerOpen = true;
            _header = _handle.get_header_pointer();
            _point = _handle.get_point_pointer();

            if (_handle.get_number_of_point(out var totalPoints) != 0)
            {
                throw new InvalidOperationException(BuildError("Nelze načíst počet bodů"));
            }

            _remaining = totalPoints;
            _totalPoints = totalPoints;
        }

        public long TotalPoints => _totalPoints;

        public long ProcessedPoints => _totalPoints - _remaining;

        public bool TryReadNext(out Point3D point)
        {
            if (_remaining <= 0)
            {
                point = default;
                return false;
            }

            if (_handle.read_point() != 0)
            {
                throw new InvalidOperationException(BuildError("Chyba při čtení bodu"));
            }

            _remaining--;
            point = new Point3D(
                ConvertCoordinate(_header.x_offset, _header.x_scale_factor, _point.X),
                ConvertCoordinate(_header.y_offset, _header.y_scale_factor, _point.Y),
                ConvertCoordinate(_header.z_offset, _header.z_scale_factor, _point.Z));
            return true;
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;

            try
            {
                if (_readerOpen && _handle.close_reader() != 0)
                {
                    throw new InvalidOperationException(BuildError("Chyba při zavírání readeru"));
                }
            }
            finally
            {
                _readerOpen = false;
                _handle.clean();
            }
        }

        private static double ConvertCoordinate(double offset, double scale, int value) =>
            offset + scale * value;

        private string BuildError(string prefix)
        {
            var message = _handle.get_error();
            if (string.IsNullOrWhiteSpace(message))
            {
                message = "Neznámá chyba LASzip knihovny.";
            }

            return $"{prefix} '{_filePath}': {message}";
        }
    }
}
