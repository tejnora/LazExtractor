namespace LASzip.Net;

public class laszip_point
{
	public int X;

	public int Y;

	public int Z;

	public ushort intensity;

	internal byte flags;

	internal byte classification_and_classification_flags;

	public sbyte scan_angle_rank;

	public byte user_data;

	public ushort point_source_ID;

	public short extended_scan_angle;

	internal byte extended_flags;

	public byte extended_classification;

	internal byte extended_returns;

	public double gps_time;

	public readonly ushort[] rgb = new ushort[4];

	public readonly byte[] wave_packet = new byte[29];

	public int num_extra_bytes;

	public byte[] extra_bytes;

	public byte return_number
	{
		get
		{
			return (byte)(flags & 7);
		}
		set
		{
			flags = (byte)((flags & 0xF8) | (value & 7));
		}
	}

	public byte number_of_returns
	{
		get
		{
			return (byte)((flags >> 3) & 7);
		}
		set
		{
			flags = (byte)((flags & 0xC7) | ((value & 7) << 3));
		}
	}

	public byte scan_direction_flag
	{
		get
		{
			return (byte)((flags >> 6) & 1);
		}
		set
		{
			flags = (byte)((flags & 0xBF) | ((value & 1) << 6));
		}
	}

	public byte edge_of_flight_line
	{
		get
		{
			return (byte)((flags >> 7) & 1);
		}
		set
		{
			flags = (byte)((flags & 0x7F) | ((value & 1) << 7));
		}
	}

	public byte classification
	{
		get
		{
			return (byte)(classification_and_classification_flags & 0x1F);
		}
		set
		{
			classification_and_classification_flags = (byte)((classification_and_classification_flags & 0xE0) | (value & 0x1F));
		}
	}

	public byte synthetic_flag
	{
		get
		{
			return (byte)((classification_and_classification_flags >> 5) & 1);
		}
		set
		{
			classification_and_classification_flags = (byte)((classification_and_classification_flags & 0xDF) | ((value & 1) << 5));
		}
	}

	public byte keypoint_flag
	{
		get
		{
			return (byte)((classification_and_classification_flags >> 6) & 1);
		}
		set
		{
			classification_and_classification_flags = (byte)((classification_and_classification_flags & 0xBF) | ((value & 1) << 6));
		}
	}

	public byte withheld_flag
	{
		get
		{
			return (byte)((classification_and_classification_flags >> 7) & 1);
		}
		set
		{
			classification_and_classification_flags = (byte)((classification_and_classification_flags & 0x7F) | ((value & 1) << 7));
		}
	}

	public byte extended_point_type
	{
		get
		{
			return (byte)(extended_flags & 3);
		}
		set
		{
			extended_flags = (byte)((extended_flags & 0xFC) | (value & 3));
		}
	}

	public byte extended_scanner_channel
	{
		get
		{
			return (byte)((extended_flags >> 2) & 3);
		}
		set
		{
			extended_flags = (byte)((extended_flags & 0xF3) | ((value & 3) << 2));
		}
	}

	public byte extended_classification_flags
	{
		get
		{
			return (byte)((extended_flags >> 4) & 0xF);
		}
		set
		{
			extended_flags = (byte)((extended_flags & 0xF) | ((value & 0xF) << 4));
		}
	}

	public byte extended_return_number
	{
		get
		{
			return (byte)(extended_returns & 0xF);
		}
		set
		{
			extended_returns = (byte)((extended_returns & 0xF0) | (value & 0xF));
		}
	}

	public byte extended_number_of_returns
	{
		get
		{
			return (byte)((extended_returns >> 4) & 0xF);
		}
		set
		{
			extended_returns = (byte)((extended_returns & 0xF) | ((value & 0xF) << 4));
		}
	}

	public bool IsSame(laszip_point p)
	{
		if (X != p.X)
		{
			return false;
		}
		if (Y != p.Y)
		{
			return false;
		}
		if (Z != p.Z)
		{
			return false;
		}
		if (intensity != p.intensity)
		{
			return false;
		}
		if (flags != p.flags)
		{
			return false;
		}
		if (classification_and_classification_flags != p.classification_and_classification_flags)
		{
			return false;
		}
		if (scan_angle_rank != p.scan_angle_rank)
		{
			return false;
		}
		if (user_data != p.user_data)
		{
			return false;
		}
		if (point_source_ID != p.point_source_ID)
		{
			return false;
		}
		if (extended_flags != p.extended_flags)
		{
			return false;
		}
		if (extended_classification != p.extended_classification)
		{
			return false;
		}
		if (extended_returns != p.extended_returns)
		{
			return false;
		}
		if (extended_scan_angle != p.extended_scan_angle)
		{
			return false;
		}
		if (gps_time != p.gps_time)
		{
			return false;
		}
		if (rgb[0] != p.rgb[0])
		{
			return false;
		}
		if (rgb[1] != p.rgb[1])
		{
			return false;
		}
		if (rgb[2] != p.rgb[2])
		{
			return false;
		}
		if (rgb[3] != p.rgb[3])
		{
			return false;
		}
		for (int i = 0; i < 29; i++)
		{
			if (wave_packet[i] != p.wave_packet[i])
			{
				return false;
			}
		}
		if (num_extra_bytes != p.num_extra_bytes)
		{
			return false;
		}
		for (int j = 0; j < num_extra_bytes; j++)
		{
			if (extra_bytes[j] != p.extra_bytes[j])
			{
				return false;
			}
		}
		return true;
	}
}
