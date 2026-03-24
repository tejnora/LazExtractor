using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace LASzip.Net;

public class laszip
{
	private class Inventory
	{
		public uint number_of_point_records;

		public readonly uint[] number_of_points_by_return = new uint[16];

		public int max_X;

		public int min_X;

		public int max_Y;

		public int min_Y;

		public int max_Z;

		public int min_Z;

		public bool active { get; private set; }

		public void add(laszip_point point)
		{
			number_of_point_records++;
			if (point.extended_point_type != 0)
			{
				number_of_points_by_return[point.extended_return_number]++;
			}
			else
			{
				number_of_points_by_return[point.return_number]++;
			}
			if (active)
			{
				if (point.X < min_X)
				{
					min_X = point.X;
				}
				else if (point.X > max_X)
				{
					max_X = point.X;
				}
				if (point.Y < min_Y)
				{
					min_Y = point.Y;
				}
				else if (point.Y > max_Y)
				{
					max_Y = point.Y;
				}
				if (point.Z < min_Z)
				{
					min_Z = point.Z;
				}
				else if (point.Z > max_Z)
				{
					max_Z = point.Z;
				}
			}
			else
			{
				min_X = (max_X = point.X);
				min_Y = (max_Y = point.Y);
				min_Z = (max_Z = point.Z);
				active = true;
			}
		}
	}

	public readonly laszip_header header = new laszip_header();

	private long p_count;

	private long npoints;

	public readonly laszip_point point = new laszip_point();

	private Stream streamin;

	private bool leaveStreamInOpen;

	private LASreadPoint reader;

	private Stream streamout;

	private bool leaveStreamOutOpen;

	private LASwritePoint writer;

	private LASattributer attributer;

	private string error = "";

	private string warning = "";

	private LASindex lax_index;

	private double lax_r_min_x;

	private double lax_r_min_y;

	private double lax_r_max_x;

	private double lax_r_max_y;

	private string lax_file_name;

	private bool lax_create;

	private bool lax_append;

	private bool lax_exploit;

	private LASZIP_DECOMPRESS_SELECTIVE las14_decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL;

	private bool m_preserve_generating_software;

	private bool m_request_native_extension = true;

	private bool m_request_compatibility_mode;

	private bool m_compatibility_mode;

	private uint m_set_chunk_size = 50000u;

	private int start_scan_angle;

	private int start_extended_returns;

	private int start_classification;

	private int start_flags_and_channel;

	private int start_NIR_band;

	private Inventory inventory;

	public List<laszip_evlr> evlrs;

	private unsafe static List<LASattribute> ToLASattributeList(byte[] data)
	{
		int num = data.Length / sizeof(LASattribute);
		List<LASattribute> list = new List<LASattribute>(num);
		fixed (byte* ptr = data)
		{
			LASattribute* ptr2 = (LASattribute*)ptr;
			for (int i = 0; i < num; i++)
			{
				list.Add(*ptr2);
				ptr2++;
			}
		}
		return list;
	}

	private unsafe static byte[] ToByteArray(List<LASattribute> attributes)
	{
		int num = attributes.Count * sizeof(LASattribute);
		try
		{
			byte[] array = new byte[num];
			fixed (byte* ptr = array)
			{
				LASattribute* ptr2 = (LASattribute*)ptr;
				for (int i = 0; i < attributes.Count; i++)
				{
					*ptr2 = attributes[i];
					ptr2++;
				}
			}
			return array;
		}
		catch
		{
			return null;
		}
	}

	private static bool strcmp(byte[] a, string b)
	{
		if (a.Length < b.Length)
		{
			return false;
		}
		for (int i = 0; i < b.Length; i++)
		{
			if (a[i] != b[i])
			{
				return false;
			}
			if (a[i] == 0)
			{
				return true;
			}
		}
		return true;
	}

	private static bool strncmp(byte[] a, byte[] b, int num)
	{
		if (a.Length != num || b.Length != num)
		{
			return false;
		}
		for (int i = 0; i < num; i++)
		{
			if (a[i] != b[i])
			{
				return false;
			}
			if (a[i] == 0)
			{
				return true;
			}
		}
		return true;
	}

	public static int get_version(out byte version_major, out byte version_minor, out ushort version_revision, out uint version_build)
	{
		version_major = 3;
		version_minor = 2;
		version_revision = 9;
		version_build = 181227u;
		return 0;
	}

	public static laszip create()
	{
		laszip obj = new laszip();
		obj.clean();
		return obj;
	}

	public string get_error()
	{
		return error;
	}

	public string get_warning()
	{
		return warning;
	}

	public int clean()
	{
		try
		{
			if (reader != null)
			{
				error = "cannot clean while reader is open.";
				return 1;
			}
			if (writer != null)
			{
				error = "cannot clean while writer is open.";
				return 1;
			}
			header.file_source_ID = 0;
			header.global_encoding = 0;
			header.project_ID_GUID_data_1 = 0u;
			header.project_ID_GUID_data_2 = 0;
			header.project_ID_GUID_data_3 = 0;
			Array.Clear(header.project_ID_GUID_data_4, 0, header.project_ID_GUID_data_4.Length);
			header.version_major = 0;
			header.version_minor = 0;
			Array.Clear(header.system_identifier, 0, header.system_identifier.Length);
			Array.Clear(header.generating_software, 0, header.generating_software.Length);
			header.file_creation_day = 0;
			header.file_creation_year = 0;
			header.header_size = 0;
			header.offset_to_point_data = 0u;
			header.number_of_variable_length_records = 0u;
			header.point_data_format = 0;
			header.point_data_record_length = 0;
			header.number_of_point_records = 0u;
			Array.Clear(header.number_of_points_by_return, 0, header.number_of_points_by_return.Length);
			header.x_scale_factor = 0.0;
			header.y_scale_factor = 0.0;
			header.z_scale_factor = 0.0;
			header.x_offset = 0.0;
			header.y_offset = 0.0;
			header.z_offset = 0.0;
			header.max_x = 0.0;
			header.min_x = 0.0;
			header.max_y = 0.0;
			header.min_y = 0.0;
			header.max_z = 0.0;
			header.min_z = 0.0;
			header.start_of_waveform_data_packet_record = 0uL;
			header.start_of_first_extended_variable_length_record = 0uL;
			header.number_of_extended_variable_length_records = 0u;
			header.extended_number_of_point_records = 0uL;
			Array.Clear(header.extended_number_of_points_by_return, 0, header.extended_number_of_points_by_return.Length);
			header.user_data_in_header_size = 0u;
			header.user_data_in_header = null;
			header.vlrs.Clear();
			header.user_data_after_header_size = 0u;
			header.user_data_after_header = null;
			point.X = 0;
			point.Y = 0;
			point.Z = 0;
			point.intensity = 0;
			point.flags = 0;
			point.classification_and_classification_flags = 0;
			point.scan_angle_rank = 0;
			point.user_data = 0;
			point.point_source_ID = 0;
			point.extended_flags = 0;
			point.extended_classification = 0;
			point.extended_returns = 0;
			point.extended_scan_angle = 0;
			point.gps_time = 0.0;
			Array.Clear(point.rgb, 0, 4);
			Array.Clear(point.wave_packet, 0, 29);
			point.num_extra_bytes = 0;
			point.extra_bytes = null;
			streamin = null;
			leaveStreamInOpen = false;
			reader = null;
			streamout = null;
			leaveStreamOutOpen = false;
			writer = null;
			attributer = null;
			lax_index = null;
			lax_file_name = null;
			inventory = null;
			p_count = (npoints = 0L);
			error = (warning = "");
			lax_r_min_x = (lax_r_min_y = (lax_r_max_x = (lax_r_max_y = 0.0)));
			lax_create = (lax_append = (lax_exploit = false));
			m_set_chunk_size = 50000u;
			las14_decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL;
			m_request_native_extension = true;
			m_preserve_generating_software = (m_request_compatibility_mode = (m_compatibility_mode = false));
			start_scan_angle = (start_extended_returns = (start_classification = (start_flags_and_channel = (start_NIR_band = 0))));
			header.setDefault();
		}
		catch
		{
			error = "internal error in laszip_clean";
			return 1;
		}
		return 0;
	}

	public laszip_header get_header_pointer()
	{
		error = (warning = "");
		return header;
	}

	public laszip_point get_point_pointer()
	{
		error = (warning = "");
		return point;
	}

	public int get_point_count(out long count)
	{
		count = 0L;
		if (reader == null && writer == null)
		{
			error = "getting count before reader or writer was opened";
			return 1;
		}
		count = p_count;
		error = (warning = "");
		return 0;
	}

	public int get_number_of_point(out long npoints)
	{
		npoints = 0L;
		if (reader == null && writer == null)
		{
			error = "getting count before reader or writer was opened";
			return 1;
		}
		npoints = this.npoints;
		error = (warning = "");
		return 0;
	}

	public int set_header(laszip_header header)
	{
		if (header == null)
		{
			error = "laszip_header_struct pointer 'header' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot set header after reader was opened";
			return 1;
		}
		if (writer != null)
		{
			error = "cannot set header after writer was opened";
			return 1;
		}
		try
		{
			attributer = null;
			this.header.file_source_ID = header.file_source_ID;
			this.header.global_encoding = header.global_encoding;
			this.header.project_ID_GUID_data_1 = header.project_ID_GUID_data_1;
			this.header.project_ID_GUID_data_2 = header.project_ID_GUID_data_2;
			this.header.project_ID_GUID_data_3 = header.project_ID_GUID_data_3;
			Array.Copy(header.project_ID_GUID_data_4, this.header.project_ID_GUID_data_4, 8);
			this.header.version_major = header.version_major;
			this.header.version_minor = header.version_minor;
			Array.Copy(header.system_identifier, this.header.system_identifier, 32);
			Array.Copy(header.generating_software, this.header.generating_software, 32);
			this.header.file_creation_day = header.file_creation_day;
			this.header.file_creation_year = header.file_creation_year;
			this.header.header_size = header.header_size;
			this.header.offset_to_point_data = header.offset_to_point_data;
			this.header.number_of_variable_length_records = header.number_of_variable_length_records;
			this.header.point_data_format = header.point_data_format;
			this.header.point_data_record_length = header.point_data_record_length;
			this.header.number_of_point_records = header.number_of_point_records;
			for (int i = 0; i < 5; i++)
			{
				this.header.number_of_points_by_return[i] = header.number_of_points_by_return[i];
			}
			this.header.x_scale_factor = header.x_scale_factor;
			this.header.y_scale_factor = header.y_scale_factor;
			this.header.z_scale_factor = header.z_scale_factor;
			this.header.x_offset = header.x_offset;
			this.header.y_offset = header.y_offset;
			this.header.z_offset = header.z_offset;
			this.header.max_x = header.max_x;
			this.header.min_x = header.min_x;
			this.header.max_y = header.max_y;
			this.header.min_y = header.min_y;
			this.header.max_z = header.max_z;
			this.header.min_z = header.min_z;
			if (this.header.version_minor >= 3)
			{
				this.header.start_of_waveform_data_packet_record = header.start_of_first_extended_variable_length_record;
			}
			if (this.header.version_minor >= 4)
			{
				this.header.start_of_first_extended_variable_length_record = header.start_of_first_extended_variable_length_record;
				this.header.number_of_extended_variable_length_records = header.number_of_extended_variable_length_records;
				this.header.extended_number_of_point_records = header.extended_number_of_point_records;
				for (int j = 0; j < 15; j++)
				{
					this.header.extended_number_of_points_by_return[j] = header.extended_number_of_points_by_return[j];
				}
			}
			this.header.user_data_in_header_size = header.user_data_in_header_size;
			this.header.user_data_in_header = null;
			if (header.user_data_in_header_size != 0)
			{
				if (header.user_data_in_header == null)
				{
					error = $"header->user_data_in_header_size is {header.user_data_in_header_size} but header->user_data_in_header is NULL";
					return 1;
				}
				this.header.user_data_in_header = new byte[header.user_data_in_header_size];
				Array.Copy(header.user_data_in_header, this.header.user_data_in_header, header.user_data_in_header_size);
			}
			this.header.vlrs = null;
			if (header.number_of_variable_length_records != 0)
			{
				this.header.vlrs = new List<laszip_vlr>((int)header.number_of_variable_length_records);
				for (int k = 0; k < header.number_of_variable_length_records; k++)
				{
					this.header.vlrs.Add(new laszip_vlr());
					this.header.vlrs[k].reserved = header.vlrs[k].reserved;
					Array.Copy(header.vlrs[k].user_id, this.header.vlrs[k].user_id, 16);
					this.header.vlrs[k].record_id = header.vlrs[k].record_id;
					this.header.vlrs[k].record_length_after_header = header.vlrs[k].record_length_after_header;
					Array.Copy(header.vlrs[k].description, this.header.vlrs[k].description, 32);
					if (header.vlrs[k].record_length_after_header != 0)
					{
						if (header.vlrs[k].data == null)
						{
							error = $"header->vlrs[{k}].record_length_after_header is {header.vlrs[k].record_length_after_header} but header->vlrs[{k}].data is NULL";
							return 1;
						}
						this.header.vlrs[k].data = new byte[header.vlrs[k].record_length_after_header];
						Array.Copy(header.vlrs[k].data, this.header.vlrs[k].data, header.vlrs[k].record_length_after_header);
					}
					else
					{
						this.header.vlrs[k].data = null;
					}
					if (!strcmp(header.vlrs[k].user_id, "LASF_Spec") || header.vlrs[k].record_id != 4)
					{
						continue;
					}
					if (attributer == null)
					{
						try
						{
							attributer = new LASattributer();
						}
						catch
						{
							error = "cannot allocate LASattributer";
							return 1;
						}
					}
					attributer.init_attributes(ToLASattributeList(header.vlrs[k].data));
				}
			}
			this.header.user_data_after_header_size = header.user_data_after_header_size;
			this.header.user_data_after_header = null;
			if (header.user_data_after_header_size != 0)
			{
				if (header.user_data_after_header == null)
				{
					error = $"header->user_data_after_header_size is {header.user_data_after_header_size} but header->user_data_after_header is NULL";
					return 1;
				}
				this.header.user_data_after_header = new byte[header.user_data_after_header_size];
				Array.Copy(header.user_data_after_header, this.header.user_data_after_header, header.user_data_after_header_size);
			}
		}
		catch
		{
			error = "internal error in laszip_set_header";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int set_point_type_and_size(byte point_type, ushort point_size)
	{
		try
		{
			if (reader != null)
			{
				error = "cannot set point format and point size after reader was opened";
				return 1;
			}
			if (writer != null)
			{
				error = "cannot set point format and point size after writer was opened";
				return 1;
			}
			if (!new LASzip().setup(point_type, point_size, 0))
			{
				error = $"invalid combination of point_type {point_type} and point_size {point_size}";
				return 1;
			}
			header.point_data_format = point_type;
			header.point_data_record_length = point_size;
		}
		catch
		{
			error = "internal error in laszip_set_point_type_and_size";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int check_for_integer_overflow()
	{
		try
		{
			int num = MyDefs.I32_QUANTIZE((header.min_x - header.x_offset) / header.x_scale_factor);
			int num2 = MyDefs.I32_QUANTIZE((header.max_x - header.x_offset) / header.x_scale_factor);
			int num3 = MyDefs.I32_QUANTIZE((header.min_y - header.y_offset) / header.y_scale_factor);
			int num4 = MyDefs.I32_QUANTIZE((header.max_y - header.y_offset) / header.y_scale_factor);
			int num5 = MyDefs.I32_QUANTIZE((header.min_z - header.z_offset) / header.z_scale_factor);
			int num6 = MyDefs.I32_QUANTIZE((header.max_z - header.z_offset) / header.z_scale_factor);
			double num7 = header.x_scale_factor * (double)num + header.x_offset;
			double num8 = header.x_scale_factor * (double)num2 + header.x_offset;
			double num9 = header.y_scale_factor * (double)num3 + header.y_offset;
			double num10 = header.y_scale_factor * (double)num4 + header.y_offset;
			double num11 = header.z_scale_factor * (double)num5 + header.z_offset;
			double num12 = header.z_scale_factor * (double)num6 + header.z_offset;
			if (header.min_x > 0.0 != num7 > 0.0)
			{
				error = $"quantization sign flip for min_x from {header.min_x} to {num7}. set scale factor for x coarser than {header.x_scale_factor}";
				return 1;
			}
			if (header.max_x > 0.0 != num8 > 0.0)
			{
				error = $"quantization sign flip for max_x from {header.max_x} to {num8}. set scale factor for x coarser than {header.x_scale_factor}";
				return 1;
			}
			if (header.min_y > 0.0 != num9 > 0.0)
			{
				error = $"quantization sign flip for min_y from {header.min_y} to {num9}. set scale factor for y coarser than {header.y_scale_factor}";
				return 1;
			}
			if (header.max_y > 0.0 != num10 > 0.0)
			{
				error = $"quantization sign flip for max_y from {header.max_y} to {num10}. set scale factor for y coarser than {header.y_scale_factor}";
				return 1;
			}
			if (header.min_z > 0.0 != num11 > 0.0)
			{
				error = $"quantization sign flip for min_z from {header.min_z} to {num11}. set scale factor for z coarser than {header.z_scale_factor}";
				return 1;
			}
			if (header.max_z > 0.0 != num12 > 0.0)
			{
				error = $"quantization sign flip for max_z from {header.max_z} to {num12}. set scale factor for z coarser than {header.z_scale_factor}";
				return 1;
			}
		}
		catch
		{
			error = "internal error in laszip_auto_offset";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int auto_offset()
	{
		try
		{
			if (reader != null)
			{
				error = "cannot auto offset after reader was opened";
				return 1;
			}
			if (writer != null)
			{
				error = "cannot auto offset after writer was opened";
				return 1;
			}
			double x_scale_factor = header.x_scale_factor;
			double y_scale_factor = header.y_scale_factor;
			double z_scale_factor = header.z_scale_factor;
			if (x_scale_factor <= 0.0 || double.IsInfinity(x_scale_factor))
			{
				error = $"invalid x scale_factor {header.x_scale_factor} in header";
				return 1;
			}
			if (y_scale_factor <= 0.0 || double.IsInfinity(y_scale_factor))
			{
				error = $"invalid y scale_factor {header.y_scale_factor} in header";
				return 1;
			}
			if (z_scale_factor <= 0.0 || double.IsInfinity(z_scale_factor))
			{
				error = $"invalid z scale_factor {header.z_scale_factor} in header";
				return 1;
			}
			double num = (header.min_x + header.max_x) / 2.0;
			double num2 = (header.min_y + header.max_y) / 2.0;
			double num3 = (header.min_z + header.max_z) / 2.0;
			if (double.IsInfinity(num))
			{
				error = $"invalid x coordinate at center of bounding box (min: {header.min_x} max: {header.max_x})";
				return 1;
			}
			if (double.IsInfinity(num2))
			{
				error = $"invalid y coordinate at center of bounding box (min: {header.min_y} max: {header.max_y})";
				return 1;
			}
			if (double.IsInfinity(num3))
			{
				error = $"invalid z coordinate at center of bounding box (min: {header.min_z} max: {header.max_z})";
				return 1;
			}
			double x_offset = header.x_offset;
			double y_offset = header.y_offset;
			double z_offset = header.z_offset;
			header.x_offset = (double)(MyDefs.I64_FLOOR(num / x_scale_factor / 10000000.0) * 10000000) * x_scale_factor;
			header.y_offset = (double)(MyDefs.I64_FLOOR(num2 / y_scale_factor / 10000000.0) * 10000000) * y_scale_factor;
			header.z_offset = (double)(MyDefs.I64_FLOOR(num3 / z_scale_factor / 10000000.0) * 10000000) * z_scale_factor;
			if (check_for_integer_overflow() != 0)
			{
				header.x_offset = x_offset;
				header.y_offset = y_offset;
				header.z_offset = z_offset;
				return 1;
			}
		}
		catch
		{
			error = "internal error in laszip_auto_offset";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int set_point(laszip_point point)
	{
		if (point == null)
		{
			error = "laszip_point_struct pointer 'point' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot set point for reader";
			return 1;
		}
		try
		{
			this.point.classification_and_classification_flags = point.classification_and_classification_flags;
			this.point.edge_of_flight_line = point.edge_of_flight_line;
			this.point.extended_classification = point.extended_classification;
			this.point.extended_classification_flags = point.extended_classification_flags;
			this.point.extended_number_of_returns = point.extended_number_of_returns;
			this.point.extended_point_type = point.extended_point_type;
			this.point.extended_return_number = point.extended_return_number;
			this.point.extended_scan_angle = point.extended_scan_angle;
			this.point.extended_scanner_channel = point.extended_scanner_channel;
			this.point.gps_time = point.gps_time;
			this.point.intensity = point.intensity;
			this.point.num_extra_bytes = point.num_extra_bytes;
			this.point.number_of_returns = point.number_of_returns;
			this.point.point_source_ID = point.point_source_ID;
			this.point.return_number = point.return_number;
			Array.Copy(point.rgb, this.point.rgb, 4);
			this.point.scan_angle_rank = point.scan_angle_rank;
			this.point.scan_direction_flag = point.scan_direction_flag;
			this.point.user_data = point.user_data;
			this.point.X = point.X;
			this.point.Y = point.Y;
			this.point.Z = point.Z;
			Array.Copy(point.wave_packet, this.point.wave_packet, 29);
			if (this.point.extra_bytes != null)
			{
				if (point.extra_bytes != null)
				{
					if (this.point.num_extra_bytes != point.num_extra_bytes)
					{
						error = $"target point has {this.point.num_extra_bytes} extra bytes but source point has {point.num_extra_bytes}";
						return 1;
					}
					Array.Copy(point.extra_bytes, this.point.extra_bytes, point.num_extra_bytes);
				}
				else if (!m_compatibility_mode)
				{
					error = "target point has extra bytes but source point does not";
					return 1;
				}
			}
		}
		catch
		{
			error = "internal error in laszip_set_point";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int set_coordinates(double[] coordinates)
	{
		if (coordinates == null)
		{
			error = "laszip_F64 pointer 'coordinates' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot set coordinates for reader";
			return 1;
		}
		try
		{
			point.X = MyDefs.I32_QUANTIZE((coordinates[0] - header.x_offset) / header.x_scale_factor);
			point.Y = MyDefs.I32_QUANTIZE((coordinates[1] - header.y_offset) / header.y_scale_factor);
			point.Z = MyDefs.I32_QUANTIZE((coordinates[2] - header.z_offset) / header.z_scale_factor);
		}
		catch
		{
			error = "internal error in laszip_set_coordinates";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int get_coordinates(double[] coordinates)
	{
		if (coordinates == null)
		{
			error = "laszip_F64 pointer 'coordinates' is zero";
			return 1;
		}
		try
		{
			coordinates[0] = header.x_scale_factor * (double)point.X + header.x_offset;
			coordinates[1] = header.y_scale_factor * (double)point.Y + header.y_offset;
			coordinates[2] = header.z_scale_factor * (double)point.Z + header.z_offset;
		}
		catch
		{
			error = "internal error in laszip_get_coordinates";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public unsafe int set_geokeys(ushort number, laszip_geokey[] key_entries)
	{
		if (number == 0)
		{
			error = "number of key_entries is zero";
			return 1;
		}
		if (key_entries == null)
		{
			error = "laszip_geokey_struct pointer 'key_entries' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot set geokeys after reader was opened";
			return 1;
		}
		if (writer != null)
		{
			error = "cannot set geokeys after writer was opened";
			return 1;
		}
		try
		{
			byte[] array = new byte[sizeof(laszip_geokey) * (number + 1)];
			fixed (byte* ptr = array)
			{
				laszip_geokey* ptr2 = (laszip_geokey*)ptr;
				ptr2->key_id = 1;
				ptr2->tiff_tag_location = 1;
				ptr2->count = 0;
				ptr2->value_offset = number;
				for (int i = 0; i < number; i++)
				{
					ptr2[i + 1] = key_entries[i];
				}
			}
			laszip_vlr laszip_vlr2 = new laszip_vlr();
			laszip_vlr2.reserved = 0;
			byte[] bytes = Encoding.ASCII.GetBytes("LASF_Projection");
			Array.Copy(bytes, laszip_vlr2.user_id, Math.Min(bytes.Length, 16));
			laszip_vlr2.record_id = 34735;
			laszip_vlr2.record_length_after_header = (ushort)(8 + number * 8);
			laszip_vlr2.description[0] = 0;
			laszip_vlr2.data = array;
			if (add_vlr(laszip_vlr2) != 0)
			{
				error = $"setting {number} geokeys";
				return 1;
			}
		}
		catch
		{
			error = "internal error in laszip_set_geokey_entries";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int set_geodouble_params(ushort number, double[] geodouble_params)
	{
		if (number == 0)
		{
			error = "number of geodouble_params is zero";
			return 1;
		}
		if (geodouble_params == null)
		{
			error = "laszip_F64 pointer 'geodouble_params' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot set geodouble_params after reader was opened";
			return 1;
		}
		if (writer != null)
		{
			error = "cannot set geodouble_params after writer was opened";
			return 1;
		}
		try
		{
			laszip_vlr laszip_vlr2 = new laszip_vlr();
			laszip_vlr2.reserved = 0;
			byte[] bytes = Encoding.ASCII.GetBytes("LASF_Projection");
			Array.Copy(bytes, laszip_vlr2.user_id, Math.Min(bytes.Length, 16));
			laszip_vlr2.record_id = 34736;
			laszip_vlr2.record_length_after_header = (ushort)(number * 8);
			laszip_vlr2.description[0] = 0;
			byte[] array = new byte[number * 8];
			Buffer.BlockCopy(geodouble_params, 0, array, 0, number * 8);
			laszip_vlr2.data = array;
			if (add_vlr(laszip_vlr2) != 0)
			{
				error = $"setting {number} geodouble_params";
				return 1;
			}
		}
		catch
		{
			error = "internal error in laszip_set_geodouble_params";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int set_geoascii_params(ushort number, byte[] geoascii_params)
	{
		if (number == 0)
		{
			error = "number of geoascii_params is zero";
			return 1;
		}
		if (geoascii_params == null)
		{
			error = "laszip_CHAR pointer 'geoascii_params' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot set geoascii_params after reader was opened";
			return 1;
		}
		if (writer != null)
		{
			error = "cannot set geoascii_params after writer was opened";
			return 1;
		}
		try
		{
			laszip_vlr laszip_vlr2 = new laszip_vlr();
			laszip_vlr2.reserved = 0;
			byte[] bytes = Encoding.ASCII.GetBytes("LASF_Projection");
			Array.Copy(bytes, laszip_vlr2.user_id, Math.Min(bytes.Length, 16));
			laszip_vlr2.record_id = 34737;
			laszip_vlr2.record_length_after_header = number;
			laszip_vlr2.description[0] = 0;
			laszip_vlr2.data = geoascii_params;
			if (add_vlr(laszip_vlr2) != 0)
			{
				error = $"setting {number} geoascii_params";
				return 1;
			}
		}
		catch
		{
			error = "internal error in laszip_set_geoascii_params";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public unsafe int add_attribute(LAS_ATTRIBUTE type, string name, string description, double scale, double offset)
	{
		if (type > LAS_ATTRIBUTE.F64)
		{
			error = $"laszip_U32 'type' is {type} but needs to be between {LAS_ATTRIBUTE.U8} and {LAS_ATTRIBUTE.F64}";
			return 1;
		}
		if (string.IsNullOrEmpty(name))
		{
			error = "laszip_CHAR pointer 'name' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot add attribute after reader was opened";
			return 1;
		}
		if (writer != null)
		{
			error = "cannot add attribute after writer was opened";
			return 1;
		}
		try
		{
			LASattribute attribute = new LASattribute(type, name, description);
			attribute.set_scale(scale);
			attribute.set_offset(offset);
			if (attributer == null)
			{
				try
				{
					attributer = new LASattributer();
				}
				catch
				{
					error = "cannot allocate LASattributer";
					return 1;
				}
			}
			if (attributer.add_attribute(attribute) == -1)
			{
				error = $"cannot add attribute '{name}' to attributer";
				return 1;
			}
			laszip_vlr laszip_vlr2 = new laszip_vlr();
			laszip_vlr2.reserved = 0;
			byte[] bytes = Encoding.ASCII.GetBytes("LASF_Spec");
			Array.Copy(bytes, laszip_vlr2.user_id, Math.Min(bytes.Length, 16));
			laszip_vlr2.record_id = 4;
			laszip_vlr2.record_length_after_header = (ushort)(attributer.number_attributes * sizeof(LASattribute));
			laszip_vlr2.description[0] = 0;
			laszip_vlr2.data = ToByteArray(attributer.attributes);
			if (add_vlr(laszip_vlr2) != 0)
			{
				error = $"adding the new extra bytes VLR with the additional attribute '{name}'";
				return 1;
			}
		}
		catch
		{
			error = "internal error in laszip_add_attribute";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int add_vlr(laszip_vlr vlr)
	{
		if (vlr == null)
		{
			error = "laszip_vlr_struct pointer 'vlr' is zero";
			return 1;
		}
		if (vlr.record_length_after_header > 0 && vlr.data == null)
		{
			error = $"VLR record_length_after_header is {vlr.record_length_after_header} but VLR data pointer is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot add vlr after reader was opened";
			return 1;
		}
		if (writer != null)
		{
			error = "cannot add vlr after writer was opened";
			return 1;
		}
		try
		{
			if (header.vlrs.Count > 0)
			{
				for (int num = (int)(header.number_of_variable_length_records - 1); num >= 0; num--)
				{
					if (header.vlrs[num].record_id == vlr.record_id && strncmp(header.vlrs[num].user_id, vlr.user_id, 16))
					{
						if (header.vlrs[num].record_length_after_header != 0)
						{
							header.offset_to_point_data -= header.vlrs[num].record_length_after_header;
						}
						header.offset_to_point_data -= 54u;
						header.vlrs.RemoveAt(num);
					}
				}
			}
			if (vlr.description[0] == 0)
			{
				byte[] bytes = Encoding.ASCII.GetBytes($"LASzip.net DLL {3}.{2} r{9} ({181227})");
				Array.Copy(bytes, vlr.description, Math.Min(bytes.Length, 31));
			}
			header.vlrs.Add(vlr);
			header.number_of_variable_length_records = (uint)header.vlrs.Count;
			header.offset_to_point_data += 54u;
			header.offset_to_point_data += vlr.record_length_after_header;
		}
		catch
		{
			error = "internal error in laszip_add_vlr";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int remove_vlr(byte[] user_id, ushort record_id)
	{
		if (user_id == null)
		{
			error = "laszip_CHAR pointer 'user_id' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot remove vlr after reader was opened";
			return 1;
		}
		if (writer != null)
		{
			error = "cannot remove vlr after writer was opened";
			return 1;
		}
		try
		{
			if (header.number_of_variable_length_records == 0)
			{
				error = $"cannot remove VLR with user_id '{Encoding.ASCII.GetString(user_id)}' and record_id {record_id} because header has no VLRs";
				return 1;
			}
			bool flag = false;
			for (int num = (int)(header.number_of_variable_length_records - 1); num >= 0; num--)
			{
				if (header.vlrs[num].record_id == record_id && strncmp(header.vlrs[num].user_id, user_id, 16))
				{
					flag = true;
					if (header.vlrs[num].record_length_after_header != 0)
					{
						header.offset_to_point_data -= header.vlrs[num].record_length_after_header;
					}
					header.offset_to_point_data -= 54u;
					header.vlrs.RemoveAt(num);
				}
			}
			if (!flag)
			{
				error = $"cannot find VLR with user_id '{Encoding.ASCII.GetString(user_id)}' and record_id {record_id} among the {header.number_of_variable_length_records} VLRs in the header";
				return 1;
			}
		}
		catch
		{
			error = "internal error in laszip_add_vlr";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int remove_vlr(string user_id, ushort record_id)
	{
		if (string.IsNullOrEmpty(user_id))
		{
			error = "laszip_CHAR pointer 'user_id' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "cannot remove vlr after reader was opened";
			return 1;
		}
		if (writer != null)
		{
			error = "cannot remove vlr after writer was opened";
			return 1;
		}
		try
		{
			if (header.number_of_variable_length_records == 0)
			{
				error = $"cannot remove VLR with user_id '{user_id}' and record_id {record_id} because header has no VLRs";
				return 1;
			}
			bool flag = false;
			for (int num = (int)(header.number_of_variable_length_records - 1); num >= 0; num--)
			{
				if (header.vlrs[num].record_id == record_id && strcmp(header.vlrs[num].user_id, user_id))
				{
					flag = true;
					if (header.vlrs[num].record_length_after_header != 0)
					{
						header.offset_to_point_data -= header.vlrs[num].record_length_after_header;
					}
					header.offset_to_point_data -= 54u;
					header.vlrs.RemoveAt(num);
				}
			}
			if (!flag)
			{
				error = $"cannot find VLR with user_id '{user_id}' and record_id {record_id} among the {header.number_of_variable_length_records} VLRs in the header";
				return 1;
			}
		}
		catch
		{
			error = "internal error in laszip_add_vlr";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int create_spatial_index(bool create, bool append)
	{
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		if (append)
		{
			error = "appending of spatial index not (yet) supported in this version";
			return 1;
		}
		lax_create = create;
		lax_append = append;
		error = (warning = "");
		return 0;
	}

	public int preserve_generating_software(bool preserve)
	{
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		m_preserve_generating_software = preserve;
		error = (warning = "");
		return 0;
	}

	public int request_native_extension(bool request)
	{
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		m_request_native_extension = request;
		error = (warning = "");
		return 0;
	}

	public int request_compatibility_mode(bool request)
	{
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		m_request_compatibility_mode = request;
		if (request)
		{
			m_request_native_extension = false;
		}
		error = (warning = "");
		return 0;
	}

	public int set_chunk_size(uint chunk_size)
	{
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		m_set_chunk_size = chunk_size;
		error = (warning = "");
		return 0;
	}

	private int prepare_header_for_write()
	{
		if (header.version_major != 1 || header.version_minor > 4)
		{
			error = $"unknown LAS version {header.version_major}.{header.version_minor}";
			return 1;
		}
		if (header.point_data_format > 5)
		{
			header.number_of_point_records = 0u;
			for (int i = 0; i < 5; i++)
			{
				header.number_of_points_by_return[i] = 0u;
			}
		}
		else if (header.version_minor > 3)
		{
			if (header.number_of_point_records != header.extended_number_of_point_records)
			{
				if (header.number_of_point_records != 0)
				{
					error = $"inconsistent number_of_point_records {header.number_of_point_records} and extended_number_of_point_records {header.extended_number_of_point_records}";
					return 1;
				}
				if (header.extended_number_of_point_records <= uint.MaxValue)
				{
					header.number_of_point_records = (uint)header.extended_number_of_point_records;
				}
			}
			for (int j = 0; j < 5; j++)
			{
				if (header.number_of_points_by_return[j] != header.extended_number_of_points_by_return[j])
				{
					if (header.number_of_points_by_return[j] != 0)
					{
						error = string.Format("inconsistent number_of_points_by_return[{0}] {1} and extended_number_of_points_by_return[{0}] {2}", j, header.number_of_points_by_return[j], header.extended_number_of_points_by_return[j]);
						return 1;
					}
					if (header.extended_number_of_points_by_return[j] <= uint.MaxValue)
					{
						header.number_of_points_by_return[j] = (uint)header.extended_number_of_points_by_return[j];
					}
				}
			}
		}
		return 0;
	}

	private unsafe int prepare_point_for_write(bool compress)
	{
		if (header.point_data_format > 5)
		{
			point.extended_point_type = 1;
			if (m_request_native_extension)
			{
				m_compatibility_mode = false;
			}
			else if (m_request_compatibility_mode)
			{
				m_request_native_extension = false;
				if (header.extended_number_of_point_records > uint.MaxValue)
				{
					error = $"extended_number_of_point_records of {header.extended_number_of_point_records} is too much for 32-bit counters of compatibility mode";
					return 1;
				}
				header.number_of_point_records = (uint)header.extended_number_of_point_records;
				for (int i = 0; i < 5; i++)
				{
					header.number_of_points_by_return[i] = (uint)header.extended_number_of_points_by_return[i];
				}
				int num = 0;
				switch (header.point_data_format)
				{
				case 6:
					num = header.point_data_record_length - 30;
					break;
				case 7:
					num = header.point_data_record_length - 36;
					break;
				case 8:
					num = header.point_data_record_length - 38;
					break;
				case 9:
					num = header.point_data_record_length - 59;
					break;
				case 10:
					num = header.point_data_record_length - 67;
					break;
				default:
					error = $"unknown point_data_format {header.point_data_format}";
					return 1;
				}
				if (num < 0)
				{
					error = $"bad point_data_format {header.point_data_format} point_data_record_length {header.point_data_record_length} combination";
					return 1;
				}
				if (header.point_data_format <= 8)
				{
					header.version_minor = 2;
					header.header_size -= 148;
					header.offset_to_point_data -= 148u;
				}
				else
				{
					header.version_minor = 3;
					header.header_size -= 140;
					header.offset_to_point_data -= 140u;
				}
				header.global_encoding &= 65519;
				header.point_data_record_length -= 2;
				header.point_data_record_length += 5;
				MemoryStream memoryStream = new MemoryStream();
				ushort value = 50155;
				memoryStream.Write(BitConverter.GetBytes(value), 0, 2);
				ushort value2 = 3;
				memoryStream.Write(BitConverter.GetBytes(value2), 0, 2);
				uint value3 = 0u;
				memoryStream.Write(BitConverter.GetBytes(value3), 0, 4);
				ulong num2 = header.start_of_waveform_data_packet_record;
				if (num2 != 0L)
				{
					Console.Error.WriteLine("WARNING: header->start_of_waveform_data_packet_record is {0}. writing 0 instead.", num2);
					num2 = 0uL;
				}
				memoryStream.Write(BitConverter.GetBytes(num2), 0, 8);
				ulong num3 = header.start_of_first_extended_variable_length_record;
				if (num3 != 0L)
				{
					Console.Error.WriteLine("WARNING: EVLRs not supported. header->start_of_first_extended_variable_length_record is {0}. writing 0 instead.", num3);
					num3 = 0uL;
				}
				memoryStream.Write(BitConverter.GetBytes(num3), 0, 8);
				uint num4 = header.number_of_extended_variable_length_records;
				if (num4 != 0)
				{
					Console.Error.WriteLine("WARNING: EVLRs not supported. header->number_of_extended_variable_length_records is {0}. writing 0 instead.", num4);
					num4 = 0u;
				}
				memoryStream.Write(BitConverter.GetBytes(num4), 0, 4);
				ulong value4 = ((header.number_of_point_records == 0) ? header.extended_number_of_point_records : header.number_of_point_records);
				memoryStream.Write(BitConverter.GetBytes(value4), 0, 8);
				for (int j = 0; j < 15; j++)
				{
					ulong value5 = ((j >= 5 || header.number_of_points_by_return[j] == 0) ? header.extended_number_of_points_by_return[j] : header.number_of_points_by_return[j]);
					memoryStream.Write(BitConverter.GetBytes(value5), 0, 8);
				}
				byte[] bytes = Encoding.ASCII.GetBytes("lascompatible");
				laszip_vlr laszip_vlr2 = new laszip_vlr
				{
					reserved = 0,
					record_id = 22204,
					record_length_after_header = 156,
					data = memoryStream.ToArray()
				};
				Array.Copy(bytes, laszip_vlr2.user_id, Math.Min(bytes.Length, 16));
				if (add_vlr(laszip_vlr2) != 0)
				{
					error = "adding the compatibility VLR";
					return 1;
				}
				memoryStream.Close();
				if (attributer == null)
				{
					try
					{
						attributer = new LASattributer();
					}
					catch
					{
						error = "cannot allocate LASattributer";
						return 1;
					}
				}
				if (num > 0)
				{
					if (attributer.get_attributes_size() > num)
					{
						error = $"bad \"extra bytes\" VLR describes {attributer.get_attributes_size() - num} bytes more than points actually have";
						return 1;
					}
					if (attributer.get_attributes_size() < num)
					{
						if (header.vlrs != null)
						{
							for (int k = 0; k < header.number_of_variable_length_records; k++)
							{
								if (strcmp(header.vlrs[k].user_id, "LASF_Spec") && header.vlrs[k].record_id == 4)
								{
									attributer.init_attributes(ToLASattributeList(header.vlrs[k].data));
								}
							}
						}
						for (int l = attributer.get_attributes_size(); l < num; l++)
						{
							string text = $"unknown {l}";
							LASattribute attribute = new LASattribute(LAS_ATTRIBUTE.U8, text, text);
							if (attributer.add_attribute(attribute) == -1)
							{
								error = $"cannot add unknown U8 attribute '{text}' of {num} to attributer";
								return 1;
							}
						}
					}
				}
				LASattribute attribute2 = new LASattribute(LAS_ATTRIBUTE.I16, "LAS 1.4 scan angle", "additional attributes");
				attribute2.set_scale(0.006);
				int index = attributer.add_attribute(attribute2);
				start_scan_angle = attributer.get_attribute_start(index);
				LASattribute attribute3 = new LASattribute(LAS_ATTRIBUTE.U8, "LAS 1.4 extended returns", "additional attributes");
				int index2 = attributer.add_attribute(attribute3);
				start_extended_returns = attributer.get_attribute_start(index2);
				LASattribute attribute4 = new LASattribute(LAS_ATTRIBUTE.U8, "LAS 1.4 classification", "additional attributes");
				int index3 = attributer.add_attribute(attribute4);
				start_classification = attributer.get_attribute_start(index3);
				LASattribute attribute5 = new LASattribute(LAS_ATTRIBUTE.U8, "LAS 1.4 flags and channel", "additional attributes");
				int index4 = attributer.add_attribute(attribute5);
				start_flags_and_channel = attributer.get_attribute_start(index4);
				if (header.point_data_format == 8 || header.point_data_format == 10)
				{
					LASattribute attribute6 = new LASattribute(LAS_ATTRIBUTE.U16, "LAS 1.4 NIR band", "additional attributes");
					int index5 = attributer.add_attribute(attribute6);
					start_NIR_band = attributer.get_attribute_start(index5);
				}
				else
				{
					start_NIR_band = -1;
				}
				bytes = Encoding.ASCII.GetBytes("LASF_Spec");
				laszip_vlr laszip_vlr3 = new laszip_vlr
				{
					reserved = 0,
					record_id = 4,
					record_length_after_header = (ushort)(attributer.number_attributes * sizeof(LASattribute)),
					data = ToByteArray(attributer.attributes)
				};
				Array.Copy(bytes, laszip_vlr3.user_id, Math.Min(bytes.Length, 16));
				if (add_vlr(laszip_vlr3) != 0)
				{
					error = "adding the extra bytes VLR with the additional attributes";
					return 1;
				}
				if (header.point_data_format == 6)
				{
					header.point_data_format = 1;
				}
				else if (header.point_data_format <= 8)
				{
					header.point_data_format = 3;
				}
				else
				{
					header.point_data_format -= 5;
				}
				m_compatibility_mode = true;
			}
			else if (compress)
			{
				error = $"LASzip DLL {3}.{2} r{9} ({181227}) cannot compress point data format {header.point_data_format} without requesting 'compatibility mode'";
				return 1;
			}
		}
		else
		{
			point.extended_point_type = 0;
			m_compatibility_mode = false;
		}
		return 0;
	}

	private int prepare_vlrs_for_write()
	{
		uint num = 0u;
		if (header.number_of_variable_length_records != 0)
		{
			if (header.vlrs == null || header.vlrs.Count == 0)
			{
				error = $"number_of_variable_length_records is {header.number_of_variable_length_records} but vlrs pointer is zero";
				return 1;
			}
			for (int i = 0; i < header.number_of_variable_length_records; i++)
			{
				num += 54;
				if (header.vlrs[i].record_length_after_header != 0)
				{
					if (header.vlrs[i] == null)
					{
						error = string.Format("vlrs[{0}].record_length_after_header is {1} but vlrs[{0}].data pointer is zero", i, header.vlrs[i].record_length_after_header);
						return 1;
					}
					num += header.vlrs[i].record_length_after_header;
				}
			}
		}
		if (num + header.header_size + header.user_data_after_header_size != header.offset_to_point_data)
		{
			error = $"header_size ({header.header_size}) plus vlrs_size ({num}) plus user_data_after_header_size ({header.user_data_after_header_size}) does not equal offset_to_point_data ({header.offset_to_point_data})";
			return 1;
		}
		return 0;
	}

	private static uint vrl_payload_size(LASzip laszip)
	{
		return (uint)(34 + 6 * laszip.num_items);
	}

	private int write_laszip_vlr_header(LASzip laszip, Stream outStream)
	{
		ushort value = 0;
		try
		{
			outStream.Write(BitConverter.GetBytes(value), 0, 2);
		}
		catch
		{
			error = "writing LASzip VLR header.reserved";
			return 1;
		}
		byte[] bytes = Encoding.ASCII.GetBytes("laszip encoded");
		byte[] array = new byte[16];
		Array.Copy(bytes, array, Math.Min(16, bytes.Length));
		try
		{
			outStream.Write(array, 0, 16);
		}
		catch
		{
			error = "writing LASzip VLR header.user_id";
			return 1;
		}
		ushort value2 = 22204;
		try
		{
			outStream.Write(BitConverter.GetBytes(value2), 0, 2);
		}
		catch
		{
			error = "writing LASzip VLR header.record_id";
			return 1;
		}
		ushort value3 = (ushort)vrl_payload_size(laszip);
		try
		{
			outStream.Write(BitConverter.GetBytes(value3), 0, 2);
		}
		catch
		{
			error = "writing LASzip VLR header.record_length_after_header";
			return 1;
		}
		byte[] bytes2 = Encoding.ASCII.GetBytes($"LASzip.net DLL {3}.{2} r{9} ({181227})");
		byte[] array2 = new byte[32];
		Array.Copy(bytes2, array2, Math.Min(31, bytes2.Length));
		try
		{
			outStream.Write(array2, 0, 32);
		}
		catch
		{
			error = "writing LASzip VLR header.description";
			return 1;
		}
		return 0;
	}

	private int write_laszip_vlr_payload(LASzip laszip, Stream outStream)
	{
		try
		{
			outStream.Write(BitConverter.GetBytes(laszip.compressor), 0, 2);
		}
		catch
		{
			error = $"writing compressor {laszip.compressor}";
			return 1;
		}
		try
		{
			outStream.Write(BitConverter.GetBytes(laszip.coder), 0, 2);
		}
		catch
		{
			error = $"writing coder {laszip.coder}";
			return 1;
		}
		try
		{
			outStream.WriteByte(laszip.version_major);
		}
		catch
		{
			error = $"writing version_major {laszip.version_major}";
			return 1;
		}
		try
		{
			outStream.WriteByte(laszip.version_minor);
		}
		catch
		{
			error = $"writing version_minor {laszip.version_minor}";
			return 1;
		}
		try
		{
			outStream.Write(BitConverter.GetBytes(laszip.version_revision), 0, 2);
		}
		catch
		{
			error = $"writing version_revision {laszip.version_revision}";
			return 1;
		}
		try
		{
			outStream.Write(BitConverter.GetBytes(laszip.options), 0, 4);
		}
		catch
		{
			error = $"writing options {laszip.options}";
			return 1;
		}
		try
		{
			outStream.Write(BitConverter.GetBytes(laszip.chunk_size), 0, 4);
		}
		catch
		{
			error = $"writing chunk_size {laszip.chunk_size}";
			return 1;
		}
		try
		{
			outStream.Write(BitConverter.GetBytes(laszip.number_of_special_evlrs), 0, 8);
		}
		catch
		{
			error = $"writing number_of_special_evlrs {laszip.number_of_special_evlrs}";
			return 1;
		}
		try
		{
			outStream.Write(BitConverter.GetBytes(laszip.offset_to_special_evlrs), 0, 8);
		}
		catch
		{
			error = $"writing offset_to_special_evlrs {laszip.offset_to_special_evlrs}";
			return 1;
		}
		try
		{
			outStream.Write(BitConverter.GetBytes(laszip.num_items), 0, 2);
		}
		catch
		{
			error = $"writing num_items {laszip.num_items}";
			return 1;
		}
		for (uint num = 0u; num < laszip.num_items; num++)
		{
			ushort value = (ushort)laszip.items[num].type;
			try
			{
				outStream.Write(BitConverter.GetBytes(value), 0, 2);
			}
			catch
			{
				error = $"writing type {laszip.items[num].type} of item {num}";
				return 1;
			}
			try
			{
				outStream.Write(BitConverter.GetBytes(laszip.items[num].size), 0, 2);
			}
			catch
			{
				error = $"writing size {laszip.items[num].size} of item {num}";
				return 1;
			}
			try
			{
				outStream.Write(BitConverter.GetBytes(laszip.items[num].version), 0, 2);
			}
			catch
			{
				error = $"writing version {laszip.items[num].version} of item {num}";
				return 1;
			}
		}
		return 0;
	}

	private int write_header(LASzip laszip, bool compress)
	{
		try
		{
			streamout.WriteByte(76);
			streamout.WriteByte(65);
			streamout.WriteByte(83);
			streamout.WriteByte(70);
		}
		catch
		{
			error = "writing header.file_signature";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.file_source_ID), 0, 2);
		}
		catch
		{
			error = "writing header.file_source_ID";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.global_encoding), 0, 2);
		}
		catch
		{
			error = "writing header.global_encoding";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.project_ID_GUID_data_1), 0, 4);
		}
		catch
		{
			error = "writing header.project_ID_GUID_data_1";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.project_ID_GUID_data_2), 0, 2);
		}
		catch
		{
			error = "writing header.project_ID_GUID_data_2";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.project_ID_GUID_data_3), 0, 2);
		}
		catch
		{
			error = "writing header.project_ID_GUID_data_3";
			return 1;
		}
		try
		{
			streamout.Write(header.project_ID_GUID_data_4, 0, 8);
		}
		catch
		{
			error = "writing header.project_ID_GUID_data_4";
			return 1;
		}
		try
		{
			streamout.WriteByte(header.version_major);
		}
		catch
		{
			error = "writing header.version_major";
			return 1;
		}
		try
		{
			streamout.WriteByte(header.version_minor);
		}
		catch
		{
			error = "writing header.version_minor";
			return 1;
		}
		try
		{
			streamout.Write(header.system_identifier, 0, 32);
		}
		catch
		{
			error = "writing header.system_identifier";
			return 1;
		}
		if (!m_preserve_generating_software)
		{
			byte[] bytes = Encoding.ASCII.GetBytes($"LASzip.net DLL {3}.{2} r{9} ({181227})");
			Array.Copy(bytes, header.generating_software, Math.Min(bytes.Length, 32));
		}
		try
		{
			streamout.Write(header.generating_software, 0, 32);
		}
		catch
		{
			error = "writing header.generating_software";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.file_creation_day), 0, 2);
		}
		catch
		{
			error = "writing header.file_creation_day";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.file_creation_year), 0, 2);
		}
		catch
		{
			error = "writing header.file_creation_year";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.header_size), 0, 2);
		}
		catch
		{
			error = "writing header.header_size";
			return 1;
		}
		if (compress)
		{
			header.offset_to_point_data += 54 + vrl_payload_size(laszip);
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.offset_to_point_data), 0, 4);
		}
		catch
		{
			error = "writing header.offset_to_point_data";
			return 1;
		}
		if (compress)
		{
			header.offset_to_point_data -= 54 + vrl_payload_size(laszip);
			header.number_of_variable_length_records++;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.number_of_variable_length_records), 0, 4);
		}
		catch
		{
			error = "writing header.number_of_variable_length_records";
			return 1;
		}
		if (compress)
		{
			header.number_of_variable_length_records--;
			header.point_data_format |= 128;
		}
		try
		{
			streamout.WriteByte(header.point_data_format);
		}
		catch
		{
			error = "writing header.point_data_format";
			return 1;
		}
		if (compress)
		{
			header.point_data_format &= 127;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.point_data_record_length), 0, 2);
		}
		catch
		{
			error = "writing header.point_data_record_length";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.number_of_point_records), 0, 4);
		}
		catch
		{
			error = "writing header.number_of_point_records";
			return 1;
		}
		for (uint num = 0u; num < 5; num++)
		{
			try
			{
				streamout.Write(BitConverter.GetBytes(header.number_of_points_by_return[num]), 0, 4);
			}
			catch
			{
				error = $"writing header.number_of_points_by_return {num}";
				return 1;
			}
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.x_scale_factor), 0, 8);
		}
		catch
		{
			error = "writing header.x_scale_factor";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.y_scale_factor), 0, 8);
		}
		catch
		{
			error = "writing header.y_scale_factor";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.z_scale_factor), 0, 8);
		}
		catch
		{
			error = "writing header.z_scale_factor";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.x_offset), 0, 8);
		}
		catch
		{
			error = "writing header.x_offset";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.y_offset), 0, 8);
		}
		catch
		{
			error = "writing header.y_offset";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.z_offset), 0, 8);
		}
		catch
		{
			error = "writing header.z_offset";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.max_x), 0, 8);
		}
		catch
		{
			error = "writing header.max_x";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.min_x), 0, 8);
		}
		catch
		{
			error = "writing header.min_x";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.max_y), 0, 8);
		}
		catch
		{
			error = "writing header.max_y";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.min_y), 0, 8);
		}
		catch
		{
			error = "writing header.min_y";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.max_z), 0, 8);
		}
		catch
		{
			error = "writing header.max_z";
			return 1;
		}
		try
		{
			streamout.Write(BitConverter.GetBytes(header.min_z), 0, 8);
		}
		catch
		{
			error = "writing header.min_z";
			return 1;
		}
		if (header.version_major == 1 && header.version_minor >= 3)
		{
			if (header.header_size < 235)
			{
				error = $"for LAS 1.{header.version_minor} header_size should at least be 235 but it is only {header.header_size}";
				return 1;
			}
			if (header.start_of_waveform_data_packet_record != 0L)
			{
				warning = $"header.start_of_waveform_data_packet_record is {header.start_of_waveform_data_packet_record}. writing 0 instead.";
				header.start_of_waveform_data_packet_record = 0uL;
			}
			try
			{
				streamout.Write(BitConverter.GetBytes(header.start_of_waveform_data_packet_record), 0, 8);
			}
			catch
			{
				error = "writing header.start_of_waveform_data_packet_record";
				return 1;
			}
			header.user_data_in_header_size = (uint)(header.header_size - 235);
		}
		else
		{
			header.user_data_in_header_size = (uint)(header.header_size - 227);
		}
		if (header.version_major == 1 && header.version_minor >= 4)
		{
			if (header.header_size < 375)
			{
				error = $"for LAS 1.{header.version_minor} header_size should at least be 375 but it is only {header.header_size}";
				return 1;
			}
			try
			{
				streamout.Write(BitConverter.GetBytes(header.start_of_first_extended_variable_length_record), 0, 8);
			}
			catch
			{
				error = "writing header.start_of_first_extended_variable_length_record";
				return 1;
			}
			try
			{
				streamout.Write(BitConverter.GetBytes(header.number_of_extended_variable_length_records), 0, 4);
			}
			catch
			{
				error = "writing header.number_of_extended_variable_length_records";
				return 1;
			}
			try
			{
				streamout.Write(BitConverter.GetBytes(header.extended_number_of_point_records), 0, 8);
			}
			catch
			{
				error = "writing header.extended_number_of_point_records";
				return 1;
			}
			for (uint num2 = 0u; num2 < 15; num2++)
			{
				try
				{
					streamout.Write(BitConverter.GetBytes(header.extended_number_of_points_by_return[num2]), 0, 8);
				}
				catch
				{
					error = $"writing header.extended_number_of_points_by_return[{num2}]";
					return 1;
				}
			}
			header.user_data_in_header_size = (uint)(header.header_size - 375);
		}
		if (header.user_data_in_header_size != 0)
		{
			try
			{
				streamout.Write(header.user_data_in_header, 0, (int)header.user_data_in_header_size);
			}
			catch
			{
				error = $"writing {header.user_data_in_header_size} bytes of data into header.user_data_in_header";
				return 1;
			}
		}
		if (header.number_of_variable_length_records != 0)
		{
			for (int i = 0; i < header.number_of_variable_length_records; i++)
			{
				try
				{
					streamout.Write(BitConverter.GetBytes(header.vlrs[i].reserved), 0, 2);
				}
				catch
				{
					error = $"writing header.vlrs[{i}].reserved";
					return 1;
				}
				try
				{
					streamout.Write(header.vlrs[i].user_id, 0, 16);
				}
				catch
				{
					error = $"writing header.vlrs[{i}].user_id";
					return 1;
				}
				try
				{
					streamout.Write(BitConverter.GetBytes(header.vlrs[i].record_id), 0, 2);
				}
				catch
				{
					error = $"writing header.vlrs[{i}].record_id";
					return 1;
				}
				try
				{
					streamout.Write(BitConverter.GetBytes(header.vlrs[i].record_length_after_header), 0, 2);
				}
				catch
				{
					error = $"writing header.vlrs[{i}].record_length_after_header";
					return 1;
				}
				try
				{
					streamout.Write(header.vlrs[i].description, 0, 32);
				}
				catch
				{
					error = $"writing header.vlrs[{i}].description";
					return 1;
				}
				if (header.vlrs[i].record_length_after_header != 0)
				{
					try
					{
						streamout.Write(header.vlrs[i].data, 0, header.vlrs[i].record_length_after_header);
					}
					catch
					{
						error = $"writing {header.vlrs[i].record_length_after_header} bytes of data into header.vlrs[{i}].data";
						return 1;
					}
				}
			}
		}
		if (compress)
		{
			if (write_laszip_vlr_header(laszip, streamout) != 0)
			{
				return 1;
			}
			if (write_laszip_vlr_payload(laszip, streamout) != 0)
			{
				return 1;
			}
		}
		if (header.user_data_after_header_size != 0)
		{
			try
			{
				streamout.Write(header.user_data_after_header, 0, (int)header.user_data_after_header_size);
			}
			catch
			{
				error = $"writing {header.user_data_after_header_size} bytes of data into header.user_data_after_header";
				return 1;
			}
		}
		return 0;
	}

	private int create_point_writer(LASzip laszip)
	{
		try
		{
			writer = new LASwritePoint();
		}
		catch
		{
			error = "could not alloc LASwritePoint";
			return 1;
		}
		if (!writer.setup(laszip.num_items, laszip.items, laszip))
		{
			error = "setup of LASwritePoint failed";
			return 1;
		}
		if (!writer.init(streamout))
		{
			error = "init of LASwritePoint failed";
			return 1;
		}
		return 0;
	}

	private int setup_laszip_items(LASzip laszip, bool compress)
	{
		byte point_data_format = header.point_data_format;
		ushort point_data_record_length = header.point_data_record_length;
		if (compress && point_data_format > 5 && m_request_compatibility_mode && !laszip.request_compatibility_mode(1))
		{
			error = "requesting 'compatibility mode' has failed";
			return 1;
		}
		if (!laszip.setup(point_data_format, point_data_record_length, 0))
		{
			error = $"invalid combination of point_type {point_data_format} and point_size {point_data_record_length}";
			return 1;
		}
		for (int i = 0; i < laszip.num_items; i++)
		{
			switch (laszip.items[i].type)
			{
			case LASitem.Type.BYTE:
			case LASitem.Type.BYTE14:
				point.num_extra_bytes = laszip.items[i].size;
				point.extra_bytes = new byte[point.num_extra_bytes];
				break;
			default:
				error = $"unknown LASitem type {laszip.items[i].type}";
				return 1;
			case LASitem.Type.POINT10:
			case LASitem.Type.GPSTIME11:
			case LASitem.Type.RGB12:
			case LASitem.Type.WAVEPACKET13:
			case LASitem.Type.POINT14:
			case LASitem.Type.RGB14:
			case LASitem.Type.RGBNIR14:
			case LASitem.Type.WAVEPACKET14:
				break;
			}
		}
		if (compress)
		{
			if (point_data_format > 5 && m_request_native_extension)
			{
				if (!laszip.setup(point_data_format, point_data_record_length, 3))
				{
					error = $"cannot compress point_type {point_data_format} with point_size {point_data_record_length} using native";
					return 1;
				}
			}
			else if (!laszip.setup(point_data_format, point_data_record_length, 2))
			{
				error = $"cannot compress point_type {point_data_format} with point_size {point_data_record_length}";
				return 1;
			}
			laszip.request_version(2);
			if (m_set_chunk_size != 50000 && !laszip.set_chunk_size(m_set_chunk_size))
			{
				error = $"setting chunk size {m_set_chunk_size} has failed";
				return 1;
			}
		}
		else
		{
			laszip.request_version(0);
		}
		return 0;
	}

	public int open_writer_stream(Stream streamout, bool compress, bool do_not_write_header, bool leaveOpen = false)
	{
		if (streamout == null || !streamout.CanWrite)
		{
			error = "can not write output stream";
			return 1;
		}
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		try
		{
			this.streamout = streamout;
			leaveStreamOutOpen = leaveOpen;
			LASzip lASzip = new LASzip();
			if (setup_laszip_items(lASzip, compress) != 0)
			{
				return 1;
			}
			if (!do_not_write_header)
			{
				if (prepare_header_for_write() != 0)
				{
					return 1;
				}
				if (prepare_point_for_write(compress) != 0)
				{
					return 1;
				}
				if (prepare_vlrs_for_write() != 0)
				{
					return 1;
				}
				if (write_header(lASzip, compress) != 0)
				{
					return 1;
				}
			}
			if (create_point_writer(lASzip) != 0)
			{
				return 1;
			}
			npoints = (long)((header.number_of_point_records != 0) ? header.number_of_point_records : header.extended_number_of_point_records);
			p_count = 0L;
		}
		catch
		{
			error = "internal error in laszip_open_writer_stream.";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int open_writer(string file_name, bool compress)
	{
		if (file_name == null || file_name.Length == 0)
		{
			error = "string 'file_name' is zero";
			return 1;
		}
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		try
		{
			Stream stream;
			try
			{
				stream = new FileStream(file_name, FileMode.Create, FileAccess.Write, FileShare.Read);
			}
			catch
			{
				error = $"cannot open file '{file_name}'";
				return 1;
			}
			if (lax_create)
			{
				LASquadtree lASquadtree = new LASquadtree();
				lASquadtree.setup(header.min_x, header.max_x, header.min_y, header.max_y, 100f);
				lax_index = new LASindex();
				lax_index.prepare(lASquadtree);
				lax_file_name = file_name;
			}
			return open_writer_stream(stream, compress, do_not_write_header: false);
		}
		catch
		{
			error = $"internal error in laszip_open_writer '{file_name}'";
			return 1;
		}
	}

	public int write_point()
	{
		if (writer == null)
		{
			error = "writing points before writer was opened";
			return 1;
		}
		try
		{
			if (point.extended_point_type != 0 && (point.extended_classification_flags & 7) != point.classification_and_classification_flags >> 5)
			{
				error = "legacy flags and extended flags are not identical";
				return 1;
			}
			if (m_compatibility_mode)
			{
				point.scan_angle_rank = MyDefs.I8_CLAMP(MyDefs.I16_QUANTIZE(0.006 * (double)point.extended_scan_angle));
				int num = point.extended_scan_angle - MyDefs.I16_QUANTIZE((double)point.scan_angle_rank / 0.006);
				if (point.extended_number_of_returns <= 7)
				{
					point.number_of_returns = point.extended_number_of_returns;
					if (point.extended_return_number <= 7)
					{
						point.return_number = point.extended_return_number;
					}
					else
					{
						point.return_number = 7;
					}
				}
				else
				{
					point.number_of_returns = 7;
					if (point.extended_return_number <= 4)
					{
						point.return_number = point.extended_return_number;
					}
					else
					{
						int num2 = point.extended_number_of_returns - point.extended_return_number;
						if (num2 <= 0)
						{
							point.return_number = 7;
						}
						else if (num2 >= 3)
						{
							point.return_number = 4;
						}
						else
						{
							point.return_number = (byte)(7 - num2);
						}
					}
				}
				int num3 = point.extended_return_number - point.return_number;
				int num4 = point.extended_number_of_returns - point.number_of_returns;
				if (point.extended_classification > 31)
				{
					point.classification = 0;
				}
				else
				{
					point.extended_classification = 0;
				}
				int extended_scanner_channel = point.extended_scanner_channel;
				int num5 = point.extended_classification_flags >> 3;
				point.extra_bytes[start_scan_angle] = (byte)num;
				point.extra_bytes[start_scan_angle + 1] = (byte)(num >> 8);
				point.extra_bytes[start_extended_returns] = (byte)((num3 << 4) | num4);
				point.extra_bytes[start_classification] = point.extended_classification;
				point.extra_bytes[start_flags_and_channel] = (byte)((extended_scanner_channel << 1) | num5);
				if (start_NIR_band != -1)
				{
					point.extra_bytes[start_NIR_band] = (byte)point.rgb[3];
					point.extra_bytes[start_NIR_band + 1] = (byte)(point.rgb[3] >> 8);
				}
			}
			if (!writer.write(point))
			{
				error = $"writing point with index {p_count} of {npoints} total points";
				return 1;
			}
			p_count++;
		}
		catch
		{
			error = "internal error in laszip_write_point";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int write_indexed_point()
	{
		try
		{
			if (!writer.write(point))
			{
				error = $"writing point {p_count} of {npoints} total points";
				return 1;
			}
			double x = header.x_scale_factor * (double)point.X + header.x_offset;
			double y = header.y_scale_factor * (double)point.Y + header.y_offset;
			lax_index.add(x, y, (uint)p_count);
			p_count++;
		}
		catch
		{
			error = "internal error in laszip_write_indexed_point";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int update_inventory()
	{
		try
		{
			if (inventory == null)
			{
				inventory = new Inventory();
			}
			inventory.add(point);
		}
		catch
		{
			error = "internal error in laszip_update_inventory";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int close_writer()
	{
		if (writer == null)
		{
			error = "closing writer before it was opened";
			return 1;
		}
		try
		{
			if (!writer.done())
			{
				error = "done of LASwritePoint failed";
				return 1;
			}
			writer = null;
			if (inventory != null)
			{
				if (header.point_data_format <= 5)
				{
					streamout.Seek(107L, SeekOrigin.Begin);
					try
					{
						streamout.Write(BitConverter.GetBytes(inventory.number_of_point_records), 0, 4);
					}
					catch
					{
						error = "updating laszip_dll->inventory->number_of_point_records";
						return 1;
					}
					for (int i = 0; i < 5; i++)
					{
						try
						{
							streamout.Write(BitConverter.GetBytes(inventory.number_of_points_by_return[i + 1]), 0, 4);
						}
						catch
						{
							error = $"updating laszip_dll->inventory->number_of_points_by_return[{i}]";
							return 1;
						}
					}
				}
				streamout.Seek(179L, SeekOrigin.Begin);
				double value = header.x_scale_factor * (double)inventory.max_X + header.x_offset;
				try
				{
					streamout.Write(BitConverter.GetBytes(value), 0, 8);
				}
				catch
				{
					error = "updating laszip_dll->inventory->max_X";
					return 1;
				}
				value = header.x_scale_factor * (double)inventory.min_X + header.x_offset;
				try
				{
					streamout.Write(BitConverter.GetBytes(value), 0, 8);
				}
				catch
				{
					error = "updating laszip_dll->inventory->min_X";
					return 1;
				}
				value = header.y_scale_factor * (double)inventory.max_Y + header.y_offset;
				try
				{
					streamout.Write(BitConverter.GetBytes(value), 0, 8);
				}
				catch
				{
					error = "updating laszip_dll->inventory->max_Y";
					return 1;
				}
				value = header.y_scale_factor * (double)inventory.min_Y + header.y_offset;
				try
				{
					streamout.Write(BitConverter.GetBytes(value), 0, 8);
				}
				catch
				{
					error = "updating laszip_dll->inventory->min_Y";
					return 1;
				}
				value = header.z_scale_factor * (double)inventory.max_Z + header.z_offset;
				try
				{
					streamout.Write(BitConverter.GetBytes(value), 0, 8);
				}
				catch
				{
					error = "updating laszip_dll->inventory->max_Z";
					return 1;
				}
				value = header.z_scale_factor * (double)inventory.min_Z + header.z_offset;
				try
				{
					streamout.Write(BitConverter.GetBytes(value), 0, 8);
				}
				catch
				{
					error = "updating laszip_dll->inventory->min_Z";
					return 1;
				}
				if (header.version_minor >= 4)
				{
					streamout.Seek(247L, SeekOrigin.Begin);
					long value2 = inventory.number_of_point_records;
					try
					{
						streamout.Write(BitConverter.GetBytes(value2), 0, 8);
					}
					catch
					{
						error = "updating laszip_dll->inventory->extended_number_of_point_records";
						return 1;
					}
					for (int j = 0; j < 15; j++)
					{
						value2 = inventory.number_of_points_by_return[j + 1];
						try
						{
							streamout.Write(BitConverter.GetBytes(value2), 0, 8);
						}
						catch
						{
							error = $"updating laszip_dll->inventory->extended_number_of_points_by_return[{j}]";
							return 1;
						}
					}
				}
				streamout.Seek(0L, SeekOrigin.End);
				inventory = null;
			}
			if (lax_index != null)
			{
				lax_index.complete(100000u, -20, verbose: false);
				if (!lax_index.write(lax_file_name))
				{
					error = $"writing LAX file to '{lax_file_name}'";
					return 1;
				}
				lax_file_name = null;
				lax_index = null;
			}
			if (!leaveStreamOutOpen)
			{
				streamout.Close();
			}
			streamout = null;
		}
		catch
		{
			error = "internal error in laszip_writer_close";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int exploit_spatial_index(bool exploit)
	{
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		lax_exploit = exploit;
		error = (warning = "");
		return 0;
	}

	public int decompress_selective(LASZIP_DECOMPRESS_SELECTIVE decompress_selective)
	{
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		las14_decompress_selective = decompress_selective;
		error = (warning = "");
		return 0;
	}

	private unsafe int read_header(out bool is_compressed)
	{
		is_compressed = false;
		try
		{
			byte[] array = new byte[32];
			if (!streamin.getBytes(array, 4))
			{
				error = "reading header.file_signature";
				return 1;
			}
			if (array[0] != 76 && array[1] != 65 && array[2] != 83 && array[3] != 70)
			{
				error = "wrong file_signature. not a LAS/LAZ file.";
				return 1;
			}
			if (!streamin.get16bits(out header.file_source_ID))
			{
				error = "reading header.file_source_ID";
				return 1;
			}
			if (!streamin.get16bits(out header.global_encoding))
			{
				error = "reading header.global_encoding";
				return 1;
			}
			if (!streamin.get32bits(out header.project_ID_GUID_data_1))
			{
				error = "reading header.project_ID_GUID_data_1";
				return 1;
			}
			if (!streamin.get16bits(out header.project_ID_GUID_data_2))
			{
				error = "reading header.project_ID_GUID_data_2";
				return 1;
			}
			if (!streamin.get16bits(out header.project_ID_GUID_data_3))
			{
				error = "reading header.project_ID_GUID_data_3";
				return 1;
			}
			if (!streamin.getBytes(header.project_ID_GUID_data_4, 8))
			{
				error = "reading header.project_ID_GUID_data_4";
				return 1;
			}
			if (!streamin.get8bits(out header.version_major))
			{
				error = "reading header.version_major";
				return 1;
			}
			if (!streamin.get8bits(out header.version_minor))
			{
				error = "reading header.version_minor";
				return 1;
			}
			if (!streamin.getBytes(header.system_identifier, 32))
			{
				error = "reading header.system_identifier";
				return 1;
			}
			if (!streamin.getBytes(header.generating_software, 32))
			{
				error = "reading header.generating_software";
				return 1;
			}
			if (!streamin.get16bits(out header.file_creation_day))
			{
				error = "reading header.file_creation_day";
				return 1;
			}
			if (!streamin.get16bits(out header.file_creation_year))
			{
				error = "reading header.file_creation_year";
				return 1;
			}
			if (!streamin.get16bits(out header.header_size))
			{
				error = "reading header.header_size";
				return 1;
			}
			if (!streamin.get32bits(out header.offset_to_point_data))
			{
				error = "reading header.offset_to_point_data";
				return 1;
			}
			if (!streamin.get32bits(out header.number_of_variable_length_records))
			{
				error = "reading header.number_of_variable_length_records";
				return 1;
			}
			if (!streamin.get8bits(out header.point_data_format))
			{
				error = "reading header.point_data_format";
				return 1;
			}
			if (!streamin.get16bits(out header.point_data_record_length))
			{
				error = "reading header.point_data_record_length";
				return 1;
			}
			if (!streamin.get32bits(out header.number_of_point_records))
			{
				error = "reading header.number_of_point_records";
				return 1;
			}
			for (int i = 0; i < 5; i++)
			{
				if (!streamin.get32bits(out header.number_of_points_by_return[i]))
				{
					error = $"reading header.number_of_points_by_return {i}";
					return 1;
				}
			}
			if (!streamin.get64bits(out header.x_scale_factor))
			{
				error = "reading header.x_scale_factor";
				return 1;
			}
			if (!streamin.get64bits(out header.y_scale_factor))
			{
				error = "reading header.y_scale_factor";
				return 1;
			}
			if (!streamin.get64bits(out header.z_scale_factor))
			{
				error = "reading header.z_scale_factor";
				return 1;
			}
			if (!streamin.get64bits(out header.x_offset))
			{
				error = "reading header.x_offset";
				return 1;
			}
			if (!streamin.get64bits(out header.y_offset))
			{
				error = "reading header.y_offset";
				return 1;
			}
			if (!streamin.get64bits(out header.z_offset))
			{
				error = "reading header.z_offset";
				return 1;
			}
			if (!streamin.get64bits(out header.max_x))
			{
				error = "reading header.max_x";
				return 1;
			}
			if (!streamin.get64bits(out header.min_x))
			{
				error = "reading header.min_x";
				return 1;
			}
			if (!streamin.get64bits(out header.max_y))
			{
				error = "reading header.max_y";
				return 1;
			}
			if (!streamin.get64bits(out header.min_y))
			{
				error = "reading header.min_y";
				return 1;
			}
			if (!streamin.get64bits(out header.max_z))
			{
				error = "reading header.max_z";
				return 1;
			}
			if (!streamin.get64bits(out header.min_z))
			{
				error = "reading header.min_z";
				return 1;
			}
			if (header.version_major == 1 && header.version_minor >= 3)
			{
				if (header.header_size < 235)
				{
					error = $"for LAS 1.{header.version_minor} header_size should at least be 235 but it is only {header.header_size}";
					return 1;
				}
				if (!streamin.get64bits(out header.start_of_waveform_data_packet_record))
				{
					error = "reading header.start_of_waveform_data_packet_record";
					return 1;
				}
				header.user_data_in_header_size = (uint)(header.header_size - 235);
			}
			else
			{
				header.user_data_in_header_size = (uint)(header.header_size - 227);
			}
			if (header.version_major == 1 && header.version_minor >= 4)
			{
				if (header.header_size < 375)
				{
					error = $"for LAS 1.{header.version_minor} header_size should at least be 375 but it is only {header.header_size}";
					return 1;
				}
				if (!streamin.get64bits(out header.start_of_first_extended_variable_length_record))
				{
					error = "reading header.start_of_first_extended_variable_length_record";
					return 1;
				}
				if (!streamin.get32bits(out header.number_of_extended_variable_length_records))
				{
					error = "reading header.number_of_extended_variable_length_records";
					return 1;
				}
				if (!streamin.get64bits(out header.extended_number_of_point_records))
				{
					error = "reading header.extended_number_of_point_records";
					return 1;
				}
				for (int j = 0; j < 15; j++)
				{
					if (!streamin.get64bits(out header.extended_number_of_points_by_return[j]))
					{
						error = $"reading header.extended_number_of_points_by_return[{j}]";
						return 1;
					}
				}
				header.user_data_in_header_size = (uint)(header.header_size - 375);
			}
			if (header.user_data_in_header_size != 0)
			{
				header.user_data_in_header = new byte[header.user_data_in_header_size];
				if (!streamin.getBytes(header.user_data_in_header, (int)header.user_data_in_header_size))
				{
					error = $"reading {header.user_data_in_header_size} bytes of data into header.user_data_in_header";
					return 1;
				}
			}
			uint num = 0u;
			LASzip lASzip = null;
			if (header.number_of_variable_length_records != 0)
			{
				try
				{
					header.vlrs = new List<laszip_vlr>();
				}
				catch
				{
					error = $"allocating {header.number_of_variable_length_records} VLRs";
					return 1;
				}
				for (int k = 0; k < header.number_of_variable_length_records; k++)
				{
					try
					{
						header.vlrs.Add(new laszip_vlr());
					}
					catch
					{
						error = $"allocating VLR #{k}";
						return 1;
					}
					if ((int)header.offset_to_point_data - num - header.header_size < 54)
					{
						warning = $"only {(int)header.offset_to_point_data - num - header.header_size} bytes until point block after reading {k} of {header.number_of_variable_length_records} vlrs. skipping remaining vlrs ...";
						header.number_of_variable_length_records = (uint)k;
						break;
					}
					if (!streamin.get16bits(out header.vlrs[k].reserved))
					{
						error = $"reading header.vlrs[{k}].reserved";
						return 1;
					}
					if (!streamin.getBytes(header.vlrs[k].user_id, 16))
					{
						error = $"reading header.vlrs[{k}].user_id";
						return 1;
					}
					if (!streamin.get16bits(out header.vlrs[k].record_id))
					{
						error = $"reading header.vlrs[{k}].record_id";
						return 1;
					}
					if (!streamin.get16bits(out header.vlrs[k].record_length_after_header))
					{
						error = $"reading header.vlrs[{k}].record_length_after_header";
						return 1;
					}
					if (!streamin.getBytes(header.vlrs[k].description, 32))
					{
						error = $"reading header.vlrs[{k}].description";
						return 1;
					}
					num += 54;
					if (header.vlrs[k].reserved != 43707 && header.vlrs[k].reserved != 0)
					{
						warning = string.Format("wrong header.vlrs[{0}].reserved: {1} != 0xAABB and {1} != 0x0", k, header.vlrs[k].reserved);
					}
					if ((int)header.offset_to_point_data - num - header.header_size < header.vlrs[k].record_length_after_header)
					{
						warning = $"only {(int)header.offset_to_point_data - num - header.header_size} bytes until point block when trying to read {header.vlrs[k].record_length_after_header} bytes into header.vlrs[{k}].data";
						header.vlrs[k].record_length_after_header = (ushort)(header.offset_to_point_data - num - header.header_size);
					}
					if (header.vlrs[k].record_length_after_header != 0)
					{
						if (strcmp(header.vlrs[k].user_id, "laszip encoded") && header.vlrs[k].record_id == 22204)
						{
							try
							{
								lASzip = new LASzip();
							}
							catch
							{
								error = "could not alloc LASzip";
								return 1;
							}
							if (!streamin.get16bits(out lASzip.compressor))
							{
								error = "reading compressor";
								return 1;
							}
							if (!streamin.get16bits(out lASzip.coder))
							{
								error = "reading coder";
								return 1;
							}
							if (!streamin.get8bits(out lASzip.version_major))
							{
								error = "reading version_major";
								return 1;
							}
							if (!streamin.get8bits(out lASzip.version_minor))
							{
								error = "reading version_minor";
								return 1;
							}
							if (!streamin.get16bits(out lASzip.version_revision))
							{
								error = "reading version_revision";
								return 1;
							}
							if (!streamin.get32bits(out lASzip.options))
							{
								error = "reading options";
								return 1;
							}
							if (!streamin.get32bits(out lASzip.chunk_size))
							{
								error = "reading chunk_size";
								return 1;
							}
							if (!streamin.get64bits(out lASzip.number_of_special_evlrs))
							{
								error = "reading number_of_special_evlrs";
								return 1;
							}
							if (!streamin.get64bits(out lASzip.offset_to_special_evlrs))
							{
								error = "reading offset_to_special_evlrs";
								return 1;
							}
							if (!streamin.get16bits(out lASzip.num_items))
							{
								error = "reading num_items";
								return 1;
							}
							lASzip.items = new LASitem[lASzip.num_items];
							for (int l = 0; l < lASzip.num_items; l++)
							{
								lASzip.items[l] = new LASitem();
								if (!streamin.get16bits(out var val))
								{
									error = $"reading type of item {l}";
									return 1;
								}
								lASzip.items[l].type = (LASitem.Type)val;
								if (!streamin.get16bits(out lASzip.items[l].size))
								{
									error = $"reading size of item {l}";
									return 1;
								}
								if (!streamin.get16bits(out lASzip.items[l].version))
								{
									error = $"reading version of item {l}";
									return 1;
								}
							}
						}
						else
						{
							header.vlrs[k].data = new byte[header.vlrs[k].record_length_after_header];
							if (!streamin.getBytes(header.vlrs[k].data, header.vlrs[k].record_length_after_header))
							{
								error = $"reading {header.vlrs[k].record_length_after_header} bytes of data into header.vlrs[{k}].data";
								return 1;
							}
						}
					}
					else
					{
						header.vlrs[k].data = null;
					}
					num += header.vlrs[k].record_length_after_header;
					if (strcmp(header.vlrs[k].user_id, "laszip encoded") && header.vlrs[k].record_id == 22204)
					{
						header.offset_to_point_data -= (uint)(54 + header.vlrs[k].record_length_after_header);
						num -= (uint)(54 + header.vlrs[k].record_length_after_header);
						header.vlrs.RemoveAt(k);
						k--;
						header.number_of_variable_length_records--;
					}
				}
			}
			header.user_data_after_header_size = header.offset_to_point_data - num - header.header_size;
			if (header.user_data_after_header_size != 0)
			{
				header.user_data_after_header = new byte[header.user_data_after_header_size];
				if (!streamin.getBytes(header.user_data_after_header, (int)header.user_data_after_header_size))
				{
					error = $"reading {header.user_data_after_header_size} bytes of data into header.user_data_after_header";
					return 1;
				}
			}
			if ((header.point_data_format & 0x80) != 0 || (header.point_data_format & 0x40) != 0)
			{
				if (lASzip == null)
				{
					error = "this file was compressed with an experimental version of LASzip. contact 'martin.isenburg@rapidlasso.com' for assistance";
					return 1;
				}
				header.point_data_format &= 127;
			}
			if (lASzip != null)
			{
				is_compressed = true;
				if (!lASzip.check(header.point_data_record_length))
				{
					error = $"{lASzip.get_error()} upgrade to the latest release of LAStools (with LASzip) or contact 'martin.isenburg@rapidlasso.com' for assistance";
					return 1;
				}
			}
			else
			{
				is_compressed = false;
				try
				{
					lASzip = new LASzip();
				}
				catch
				{
					error = "could not alloc LASzip";
					return 1;
				}
				if (!lASzip.setup(header.point_data_format, header.point_data_record_length, 0))
				{
					error = $"invalid combination of point_data_format {header.point_data_format} and point_data_record_length {header.point_data_record_length}";
					return 1;
				}
			}
			for (int m = 0; m < lASzip.num_items; m++)
			{
				switch (lASzip.items[m].type)
				{
				case LASitem.Type.BYTE:
				case LASitem.Type.BYTE14:
					point.num_extra_bytes = lASzip.items[m].size;
					point.extra_bytes = new byte[point.num_extra_bytes];
					break;
				default:
					error = $"unknown LASitem type {lASzip.items[m].type}";
					return 1;
				case LASitem.Type.POINT10:
				case LASitem.Type.GPSTIME11:
				case LASitem.Type.RGB12:
				case LASitem.Type.WAVEPACKET13:
				case LASitem.Type.POINT14:
				case LASitem.Type.RGB14:
				case LASitem.Type.RGBNIR14:
				case LASitem.Type.WAVEPACKET14:
					break;
				}
			}
			m_compatibility_mode = false;
			if (m_request_compatibility_mode && header.version_minor < 4)
			{
				laszip_vlr laszip_vlr2 = null;
				if (header.point_data_format == 1 || header.point_data_format == 3 || header.point_data_format == 4 || header.point_data_format == 5)
				{
					for (int n = 0; n < header.number_of_variable_length_records; n++)
					{
						if (strcmp(header.vlrs[n].user_id, "lascompatible") && header.vlrs[n].record_id == 22204 && header.vlrs[n].record_length_after_header == 156)
						{
							laszip_vlr2 = header.vlrs[n];
							break;
						}
					}
					if (laszip_vlr2 != null)
					{
						LASattributer lASattributer = new LASattributer();
						for (int num2 = 0; num2 < header.number_of_variable_length_records; num2++)
						{
							if (strcmp(header.vlrs[num2].user_id, "LASF_Spec") && header.vlrs[num2].record_id == 4)
							{
								lASattributer.init_attributes(ToLASattributeList(header.vlrs[num2].data));
								start_scan_angle = lASattributer.get_attribute_start("LAS 1.4 scan angle");
								start_extended_returns = lASattributer.get_attribute_start("LAS 1.4 extended returns");
								start_classification = lASattributer.get_attribute_start("LAS 1.4 classification");
								start_flags_and_channel = lASattributer.get_attribute_start("LAS 1.4 flags and channel");
								start_NIR_band = lASattributer.get_attribute_start("LAS 1.4 NIR band");
								break;
							}
						}
						if (start_scan_angle != -1 && start_extended_returns != -1 && start_classification != -1 && start_flags_and_channel != -1)
						{
							MemoryStream memoryStream = new MemoryStream(laszip_vlr2.data, 0, laszip_vlr2.record_length_after_header);
							memoryStream.get16bits(out var _);
							memoryStream.get16bits(out var _);
							((Stream)memoryStream).get32bits(out uint _);
							((Stream)memoryStream).get64bits(out ulong val5);
							if (val5 != 0L)
							{
								Console.Error.WriteLine("WARNING: start_of_waveform_data_packet_record is {0}. reading 0 instead.", val5);
							}
							header.start_of_waveform_data_packet_record = 0uL;
							((Stream)memoryStream).get64bits(out ulong val6);
							if (val6 != 0L)
							{
								Console.Error.WriteLine("WARNING: EVLRs not supported. start_of_first_extended_variable_length_record is {0}. reading 0 instead.", val6);
							}
							header.start_of_first_extended_variable_length_record = 0uL;
							((Stream)memoryStream).get32bits(out uint val7);
							if (val7 != 0)
							{
								Console.Error.WriteLine("WARNING: EVLRs not supported. number_of_extended_variable_length_records is {0}. reading 0 instead.", val7);
							}
							header.number_of_extended_variable_length_records = 0u;
							((Stream)memoryStream).get64bits(out ulong val8);
							if (header.number_of_point_records != 0 && header.number_of_point_records != val8)
							{
								Console.Error.WriteLine("WARNING: number_of_point_records is {0}. but extended_number_of_point_records is {1}.", header.number_of_point_records, val8);
							}
							header.extended_number_of_point_records = val8;
							for (int num3 = 0; num3 < 15; num3++)
							{
								((Stream)memoryStream).get64bits(out ulong val9);
								if (num3 < 5 && header.number_of_points_by_return[num3] != 0 && header.number_of_points_by_return[num3] != val9)
								{
									Console.Error.WriteLine("WARNING: number_of_points_by_return[{0}] is {1}. but extended_number_of_points_by_return[{0}] is {2}.", num3, header.number_of_points_by_return[num3], val9);
								}
								header.extended_number_of_points_by_return[num3] = val9;
							}
							memoryStream.Close();
							if (remove_vlr("lascompatible", 22204) != 0)
							{
								error = "removing the compatibility VLR";
								return 1;
							}
							if (start_NIR_band != -1)
							{
								lASattributer.remove_attribute("LAS 1.4 NIR band");
							}
							lASattributer.remove_attribute("LAS 1.4 flags and channel");
							lASattributer.remove_attribute("LAS 1.4 classification");
							lASattributer.remove_attribute("LAS 1.4 extended returns");
							lASattributer.remove_attribute("LAS 1.4 scan angle");
							if (lASattributer.number_attributes != 0)
							{
								laszip_vlr laszip_vlr3 = new laszip_vlr
								{
									reserved = 0,
									record_id = 4,
									record_length_after_header = (ushort)(lASattributer.number_attributes * sizeof(LASattribute)),
									data = ToByteArray(lASattributer.attributes)
								};
								Encoding.ASCII.GetBytes("LASF_Spec").CopyTo(laszip_vlr3.user_id, 0);
								if (add_vlr(laszip_vlr3) != 0)
								{
									error = "rewriting the extra bytes VLR without 'LAS 1.4 compatibility mode' attributes";
									return 1;
								}
							}
							else if (remove_vlr("LASF_Spec", 4) != 0)
							{
								error = "removing the LAS 1.4 attribute VLR";
								return 1;
							}
							if (header.version_minor < 3)
							{
								header.header_size += 148;
								header.offset_to_point_data += 148u;
							}
							else
							{
								header.header_size += 140;
								header.offset_to_point_data += 140u;
							}
							header.version_minor = 4;
							for (int num4 = 0; num4 < header.number_of_variable_length_records; num4++)
							{
								if (strcmp(header.vlrs[num4].user_id, "LASF_Projection") && header.vlrs[num4].record_id == 2112)
								{
									header.global_encoding |= 16;
									break;
								}
							}
							point.extended_point_type = 1;
							if (header.point_data_format == 1)
							{
								header.point_data_format = 6;
								header.point_data_record_length -= 3;
							}
							else if (header.point_data_format == 3)
							{
								if (start_NIR_band == -1)
								{
									header.point_data_format = 7;
									header.point_data_record_length -= 3;
								}
								else
								{
									header.point_data_format = 8;
									header.point_data_record_length -= 3;
								}
							}
							else if (start_NIR_band == -1)
							{
								header.point_data_format = 9;
								header.point_data_record_length -= 3;
							}
							else
							{
								header.point_data_format = 10;
								header.point_data_record_length -= 3;
							}
							m_compatibility_mode = true;
						}
					}
				}
			}
			else if (header.point_data_format > 5)
			{
				point.extended_point_type = 1;
			}
			try
			{
				reader = new LASreadPoint(las14_decompress_selective);
			}
			catch
			{
				error = "could not alloc LASreadPoint";
				return 1;
			}
			if (!reader.setup(lASzip.num_items, lASzip.items, lASzip))
			{
				error = "setup of LASreadPoint failed";
				return 1;
			}
			if (!reader.init(streamin))
			{
				error = "init of LASreadPoint failed";
				return 1;
			}
			lASzip = null;
			npoints = (long)((header.number_of_point_records != 0) ? header.number_of_point_records : header.extended_number_of_point_records);
			p_count = 0L;
		}
		catch
		{
			error = "internal error in laszip_open_reader";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int open_reader_stream(Stream streamin, out bool is_compressed, bool leaveOpen = false)
	{
		is_compressed = false;
		if (!streamin.CanRead)
		{
			error = "can not read input stream";
			return 1;
		}
		if (streamin.CanSeek && streamin.Length <= 0)
		{
			error = "input stream is empty : nothing to read";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		this.streamin = streamin;
		leaveStreamInOpen = leaveOpen;
		return read_header(out is_compressed);
	}

	public int open_reader(string file_name, out bool is_compressed)
	{
		is_compressed = false;
		if (file_name == null || file_name.Length == 0)
		{
			error = "string 'file_name' is zero";
			return 1;
		}
		if (writer != null)
		{
			error = "writer is already open";
			return 1;
		}
		if (reader != null)
		{
			error = "reader is already open";
			return 1;
		}
		try
		{
			Stream stream;
			try
			{
				stream = File.OpenRead(file_name);
			}
			catch
			{
				error = $"cannot open file '{file_name}'";
				return 1;
			}
			if (open_reader_stream(stream, out is_compressed) != 0)
			{
				return 1;
			}
			if (lax_exploit)
			{
				lax_index = new LASindex();
				if (!lax_index.read(file_name))
				{
					lax_index = null;
				}
			}
		}
		catch
		{
			error = "internal error in laszip_open_reader";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int has_spatial_index(out bool is_indexed, out bool is_appended)
	{
		is_indexed = (is_appended = false);
		try
		{
			if (reader == null)
			{
				error = "reader is not open";
				return 1;
			}
			if (writer != null)
			{
				error = "writer is already open";
				return 1;
			}
			if (!lax_exploit)
			{
				error = "exploiting of spatial indexing not enabled before opening reader";
				return 1;
			}
			is_indexed = lax_index != null;
			is_appended = false;
		}
		catch
		{
			error = "internal error in laszip_have_spatial_index";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int inside_rectangle(double min_x, double min_y, double max_x, double max_y, out bool is_empty)
	{
		is_empty = false;
		try
		{
			if (reader == null)
			{
				error = "reader is not open";
				return 1;
			}
			if (!lax_exploit)
			{
				error = "exploiting of spatial indexing not enabled before opening reader";
				return 1;
			}
			lax_r_min_x = min_x;
			lax_r_min_y = min_y;
			lax_r_max_x = max_x;
			lax_r_max_y = max_y;
			if (lax_index != null)
			{
				if (lax_index.intersect_rectangle(min_x, min_y, max_x, max_y))
				{
					is_empty = false;
				}
				else
				{
					is_empty = true;
				}
			}
			else if (header.min_x > max_x || header.min_y > max_y || header.max_x < min_x || header.max_y < min_y)
			{
				is_empty = true;
			}
			else
			{
				is_empty = false;
			}
		}
		catch
		{
			error = "internal error in laszip_inside_rectangle";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int seek_point(long index)
	{
		try
		{
			if (!reader.seek((uint)p_count, (uint)index))
			{
				error = $"seeking from index {p_count} to index {index} for file with {npoints} points";
				return 1;
			}
			p_count = index;
		}
		catch
		{
			error = "internal error in laszip_seek_point";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int read_point()
	{
		if (reader == null)
		{
			error = "reading points before reader was opened";
			return 1;
		}
		try
		{
			if (!reader.read(point))
			{
				error = $"reading point with index {p_count} of {npoints} total points";
				return 1;
			}
			if (m_compatibility_mode)
			{
				laszip_point laszip_point2 = point;
				short num = (short)((laszip_point2.extra_bytes[start_scan_angle + 1] << 8) | laszip_point2.extra_bytes[start_scan_angle]);
				byte num2 = laszip_point2.extra_bytes[start_extended_returns];
				byte b = laszip_point2.extra_bytes[start_classification];
				byte b2 = laszip_point2.extra_bytes[start_flags_and_channel];
				if (start_NIR_band != -1)
				{
					laszip_point2.rgb[3] = (ushort)((laszip_point2.extra_bytes[start_NIR_band + 1] << 8) | laszip_point2.extra_bytes[start_NIR_band]);
				}
				int num3 = (num2 >> 4) & 0xF;
				int num4 = num2 & 0xF;
				int num5 = (b2 >> 1) & 3;
				int num6 = b2 & 1;
				laszip_point2.extended_scan_angle = (short)(num + MyDefs.I16_QUANTIZE((double)laszip_point2.scan_angle_rank / 0.006));
				laszip_point2.extended_return_number = (byte)(num3 + laszip_point2.return_number);
				laszip_point2.extended_number_of_returns = (byte)(num4 + laszip_point2.number_of_returns);
				laszip_point2.extended_classification = (byte)(b + laszip_point2.classification);
				laszip_point2.extended_scanner_channel = (byte)num5;
				laszip_point2.extended_classification_flags = (byte)((num6 << 3) | (laszip_point2.withheld_flag << 2) | (laszip_point2.keypoint_flag << 1) | laszip_point2.synthetic_flag);
			}
			p_count++;
		}
		catch
		{
			error = "internal error in laszip_read_point";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int read_inside_point(out bool is_done)
	{
		is_done = true;
		try
		{
			if (lax_index != null)
			{
				while (lax_index.seek_next(reader, ref p_count))
				{
					if (!reader.read(point))
					{
						continue;
					}
					p_count++;
					double num = header.x_scale_factor * (double)point.X + header.x_offset;
					if (!(num < lax_r_min_x) && !(num >= lax_r_max_x))
					{
						num = header.y_scale_factor * (double)point.Y + header.y_offset;
						if (!(num < lax_r_min_y) && !(num >= lax_r_max_y))
						{
							is_done = false;
							break;
						}
					}
				}
			}
			else
			{
				while (reader.read(point))
				{
					p_count++;
					double num2 = header.x_scale_factor * (double)point.X + header.x_offset;
					if (!(num2 < lax_r_min_x) && !(num2 >= lax_r_max_x))
					{
						num2 = header.y_scale_factor * (double)point.Y + header.y_offset;
						if (!(num2 < lax_r_min_y) && !(num2 >= lax_r_max_y))
						{
							is_done = false;
							break;
						}
					}
				}
				if (is_done && p_count < npoints)
				{
					error = $"reading point {p_count} of {npoints} total points";
					return 1;
				}
			}
		}
		catch
		{
			error = "internal error in laszip_read_inside_point";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int close_reader()
	{
		if (reader == null)
		{
			error = "closing reader before it was opened";
			return 1;
		}
		try
		{
			if (!reader.done())
			{
				error = "done of LASreadPoint failed";
				return 1;
			}
			reader = null;
			if (!leaveStreamInOpen)
			{
				streamin.Close();
			}
			streamin = null;
			lax_index = null;
		}
		catch
		{
			error = "internal error in laszip_close_reader";
			return 1;
		}
		error = (warning = "");
		return 0;
	}

	public int create_laszip_vlr(out byte[] vlr)
	{
		vlr = null;
		LASzip lASzip = new LASzip();
		if (setup_laszip_items(lASzip, compress: true) != 0)
		{
			return 1;
		}
		MemoryStream memoryStream;
		try
		{
			memoryStream = new MemoryStream();
		}
		catch
		{
			error = "could not alloc ByteStreamOutArray";
			return 1;
		}
		if (write_laszip_vlr_header(lASzip, memoryStream) != 0)
		{
			return 1;
		}
		if (write_laszip_vlr_payload(lASzip, memoryStream) != 0)
		{
			return 1;
		}
		vlr = memoryStream.ToArray();
		error = (warning = "");
		return 0;
	}

	public int read_evlrs()
	{
		if (reader == null)
		{
			error = "reading EVLRs before reader was opened";
			return 1;
		}
		if (!streamin.CanSeek)
		{
			error = "stream unable to seek";
			return 1;
		}
		if (header.number_of_extended_variable_length_records == 0)
		{
			error = "";
			warning = "not EVLRs in file";
			return 0;
		}
		try
		{
			long position = streamin.Position;
			streamin.Position = (long)header.start_of_first_extended_variable_length_record;
			try
			{
				evlrs = new List<laszip_evlr>((int)header.number_of_extended_variable_length_records);
			}
			catch
			{
				error = $"allocating {header.number_of_extended_variable_length_records} EVLRs";
				return 1;
			}
			for (int i = 0; i < header.number_of_extended_variable_length_records; i++)
			{
				try
				{
					evlrs.Add(new laszip_evlr());
				}
				catch
				{
					error = $"allocating EVLR #{i}";
					return 1;
				}
				if (streamin.Length - streamin.Position < 60)
				{
					warning = $"only {streamin.Length - streamin.Position} bytes until end of stream reading {i} of {header.number_of_extended_variable_length_records} EVLRs. skipping remaining EVLRs ...";
					header.number_of_extended_variable_length_records = (uint)i;
					break;
				}
				if (!streamin.get16bits(out evlrs[i].reserved))
				{
					error = $"reading EVLRs[{i}].reserved";
					return 1;
				}
				if (!streamin.getBytes(evlrs[i].user_id, 16))
				{
					error = $"reading EVLRs[{i}].user_id";
					return 1;
				}
				if (!streamin.get16bits(out evlrs[i].record_id))
				{
					error = $"reading EVLRs[{i}].record_id";
					return 1;
				}
				if (!streamin.get64bits(out evlrs[i].record_length_after_header))
				{
					error = $"reading EVLRs[{i}].record_length_after_header";
					return 1;
				}
				if (!streamin.getBytes(evlrs[i].description, 32))
				{
					error = $"reading EVLRs[{i}].description";
					return 1;
				}
				if (evlrs[i].reserved != 43707 && evlrs[i].reserved != 0)
				{
					warning = string.Format("wrong EVLRs[{0}].reserved: {1} != 0xAABB and {1} != 0x0", i, evlrs[i].reserved);
				}
				if (streamin.Length - streamin.Position < (long)evlrs[i].record_length_after_header)
				{
					warning = $"only {streamin.Length - streamin.Position} bytes until end of stream when trying to read {evlrs[i].record_length_after_header} bytes into EVLRs[{i}].data";
					evlrs[i].record_length_after_header = (ulong)(streamin.Length - streamin.Position);
				}
				if (evlrs[i].record_length_after_header != 0L)
				{
					evlrs[i].data = new byte[(uint)evlrs[i].record_length_after_header];
					if (!streamin.getBytes(evlrs[i].data, (int)evlrs[i].record_length_after_header))
					{
						error = $"reading {evlrs[i].record_length_after_header} bytes of data into EVLRs[{i}].data";
						return 1;
					}
				}
				else
				{
					evlrs[i].data = null;
				}
			}
			streamin.Position = position;
		}
		catch
		{
			error = "internal error in read_evlrs";
			return 1;
		}
		error = (warning = "");
		return 0;
	}
}
