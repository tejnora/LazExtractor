using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security;
using System.Security.Permissions;
using System.Text;

[assembly: CompilationRelaxations(8)]
[assembly: RuntimeCompatibility(WrapNonExceptionThrows = true)]
[assembly: Debuggable(DebuggableAttribute.DebuggingModes.IgnoreSymbolStoreSequencePoints)]
[assembly: TargetFramework(".NETStandard,Version=v2.0", FrameworkDisplayName = ".NET Standard 2.0")]
[assembly: AssemblyCompany("Unofficial.laszip.netstandard")]
[assembly: AssemblyConfiguration("Release")]
[assembly: AssemblyFileVersion("5.6.0.0")]
[assembly: AssemblyInformationalVersion("5.6.2+ed85bce04618437bcbee5c68b5a0fbcaffeb6ba8")]
[assembly: AssemblyProduct("Unofficial.laszip.netstandard")]
[assembly: AssemblyTitle("Unofficial.laszip.netstandard")]
[assembly: SecurityPermission(SecurityAction.RequestMinimum, SkipVerification = true)]
[assembly: AssemblyVersion("5.6.0.0")]
[module: UnverifiableCode]
namespace LASzip.Net;

internal class ArithmeticBitModel
{
	internal uint update_cycle;

	internal uint bits_until_update;

	internal uint bit_0_prob;

	internal uint bit_0_count;

	internal uint bit_count;

	public ArithmeticBitModel()
	{
		init();
	}

	public int init()
	{
		bit_0_count = 1u;
		bit_count = 2u;
		bit_0_prob = 4096u;
		update_cycle = (bits_until_update = 4u);
		return 0;
	}

	internal void update()
	{
		if ((bit_count += update_cycle) > 8192)
		{
			bit_count = bit_count + 1 >> 1;
			bit_0_count = bit_0_count + 1 >> 1;
			if (bit_0_count == bit_count)
			{
				bit_count++;
			}
		}
		uint num = 2147483648u / bit_count;
		bit_0_prob = bit_0_count * num >> 18;
		update_cycle = 5 * update_cycle >> 2;
		if (update_cycle > 64)
		{
			update_cycle = 64u;
		}
		bits_until_update = update_cycle;
	}
}
internal class ArithmeticDecoder
{
	private Stream instream;

	private uint value;

	private uint length;

	public ArithmeticDecoder()
	{
		instream = null;
	}

	public bool init(Stream instream, bool really_init = true)
	{
		if (instream == null)
		{
			return false;
		}
		this.instream = instream;
		length = uint.MaxValue;
		if (really_init)
		{
			value = (uint)(instream.ReadByte() << 24);
			value |= (uint)(instream.ReadByte() << 16);
			value |= (uint)(instream.ReadByte() << 8);
			value |= (uint)instream.ReadByte();
		}
		return true;
	}

	public void done()
	{
		instream = null;
	}

	public ArithmeticBitModel createBitModel()
	{
		return new ArithmeticBitModel();
	}

	public void initBitModel(ArithmeticBitModel model)
	{
		model.init();
	}

	public ArithmeticModel createSymbolModel(uint n)
	{
		return new ArithmeticModel(n, compress: false);
	}

	public void initSymbolModel(ArithmeticModel model, uint[] table = null)
	{
		model.init(table);
	}

	public uint decodeBit(ArithmeticBitModel m)
	{
		uint num = m.bit_0_prob * (length >> 13);
		bool num2 = value >= num;
		if (!num2)
		{
			length = num;
			m.bit_0_count++;
		}
		else
		{
			value -= num;
			length -= num;
		}
		if (length < 16777216)
		{
			renorm_dec_interval();
		}
		if (--m.bits_until_update == 0)
		{
			m.update();
		}
		return num2 ? 1u : 0u;
	}

	public uint decodeSymbol(ArithmeticModel m)
	{
		uint num = length;
		uint num4;
		uint num7;
		if (m.decoder_table != null)
		{
			uint num2 = value / (length >>= 15);
			uint num3 = num2 >> m.table_shift;
			num4 = m.decoder_table[num3];
			uint num5 = m.decoder_table[num3 + 1] + 1;
			while (num5 > num4 + 1)
			{
				uint num6 = num4 + num5 >> 1;
				if (m.distribution[num6] > num2)
				{
					num5 = num6;
				}
				else
				{
					num4 = num6;
				}
			}
			num7 = m.distribution[num4] * length;
			if (num4 != m.last_symbol)
			{
				num = m.distribution[num4 + 1] * length;
			}
		}
		else
		{
			num7 = (num4 = 0u);
			length >>= 15;
			uint num5;
			uint num8 = (num5 = m.symbols) >> 1;
			do
			{
				uint num9 = length * m.distribution[num8];
				if (num9 > value)
				{
					num5 = num8;
					num = num9;
				}
				else
				{
					num4 = num8;
					num7 = num9;
				}
			}
			while ((num8 = num4 + num5 >> 1) != num4);
		}
		value -= num7;
		length = num - num7;
		if (length < 16777216)
		{
			renorm_dec_interval();
		}
		m.symbol_count[num4]++;
		if (--m.symbols_until_update == 0)
		{
			m.update();
		}
		return num4;
	}

	public uint readBit()
	{
		uint num = value / (length >>= 1);
		value -= length * num;
		if (length < 16777216)
		{
			renorm_dec_interval();
		}
		if (num >= 2)
		{
			throw new Exception("4711");
		}
		return num;
	}

	public uint readBits(uint bits)
	{
		if (bits > 19)
		{
			uint num = readShort();
			bits -= 16;
			return (readBits(bits) << 16) | num;
		}
		uint num2 = value / (length >>= (int)bits);
		value -= length * num2;
		if (length < 16777216)
		{
			renorm_dec_interval();
		}
		if (num2 >= (uint)(1 << (int)bits))
		{
			throw new Exception("4711");
		}
		return num2;
	}

	public byte readByte()
	{
		uint num = value / (length >>= 8);
		value -= length * num;
		if (length < 16777216)
		{
			renorm_dec_interval();
		}
		if (num >= 256)
		{
			throw new Exception("4711");
		}
		return (byte)num;
	}

	public ushort readShort()
	{
		uint num = value / (length >>= 16);
		value -= length * num;
		if (length < 16777216)
		{
			renorm_dec_interval();
		}
		if (num >= 65536)
		{
			throw new Exception("4711");
		}
		return (ushort)num;
	}

	public uint readInt()
	{
		uint num = readShort();
		return (uint)(readShort() << 16) | num;
	}

	public unsafe float readFloat()
	{
		uint num = readInt();
		return *(float*)(&num);
	}

	public ulong readInt64()
	{
		ulong num = readInt();
		return ((ulong)readInt() << 32) | num;
	}

	public unsafe double readDouble()
	{
		ulong num = readInt64();
		return *(double*)(&num);
	}

	public Stream getByteStreamIn()
	{
		return instream;
	}

	private void renorm_dec_interval()
	{
		do
		{
			value = (value << 8) | (uint)instream.ReadByte();
		}
		while ((length <<= 8) < 16777216);
	}
}
internal class ArithmeticEncoder
{
	private Stream outstream;

	private readonly byte[] outbuffer;

	private int endbuffer;

	private int outbyte;

	private int endbyte;

	private uint interval_base;

	private uint length;

	public ArithmeticEncoder()
	{
		outbuffer = new byte[2048];
		endbuffer = 2048;
	}

	public bool init(Stream outstream)
	{
		if (outstream == null)
		{
			return false;
		}
		this.outstream = outstream;
		interval_base = 0u;
		length = uint.MaxValue;
		outbyte = 0;
		endbyte = endbuffer;
		return true;
	}

	public void done()
	{
		uint num = interval_base;
		bool flag = true;
		if (length > 33554432)
		{
			interval_base += 16777216u;
			length = 8388608u;
		}
		else
		{
			interval_base += 8388608u;
			length = 32768u;
			flag = false;
		}
		if (num > interval_base)
		{
			propagate_carry();
		}
		renorm_enc_interval();
		if (endbyte != endbuffer)
		{
			outstream.Write(outbuffer, 1024, 1024);
		}
		if (outbyte != 0)
		{
			outstream.Write(outbuffer, 0, outbyte);
		}
		outstream.WriteByte(0);
		outstream.WriteByte(0);
		if (flag)
		{
			outstream.WriteByte(0);
		}
		outstream = null;
	}

	public ArithmeticBitModel createBitModel()
	{
		return new ArithmeticBitModel();
	}

	public void initBitModel(ArithmeticBitModel model)
	{
		model.init();
	}

	public ArithmeticModel createSymbolModel(uint n)
	{
		return new ArithmeticModel(n, compress: true);
	}

	public void initSymbolModel(ArithmeticModel model, uint[] table = null)
	{
		model.init(table);
	}

	public void encodeBit(ArithmeticBitModel m, uint bit)
	{
		uint num = m.bit_0_prob * (length >> 13);
		if (bit == 0)
		{
			length = num;
			m.bit_0_count++;
		}
		else
		{
			uint num2 = interval_base;
			interval_base += num;
			length -= num;
			if (num2 > interval_base)
			{
				propagate_carry();
			}
		}
		if (length < 16777216)
		{
			renorm_enc_interval();
		}
		if (--m.bits_until_update == 0)
		{
			m.update();
		}
	}

	public void encodeSymbol(ArithmeticModel m, uint sym)
	{
		uint num = interval_base;
		if (sym == m.last_symbol)
		{
			uint num2 = m.distribution[sym] * (length >> 15);
			interval_base += num2;
			length -= num2;
		}
		else
		{
			uint num2 = m.distribution[sym] * (length >>= 15);
			interval_base += num2;
			length = m.distribution[sym + 1] * length - num2;
		}
		if (num > interval_base)
		{
			propagate_carry();
		}
		if (length < 16777216)
		{
			renorm_enc_interval();
		}
		m.symbol_count[sym]++;
		if (--m.symbols_until_update == 0)
		{
			m.update();
		}
	}

	public void writeBit(uint bit)
	{
		uint num = interval_base;
		interval_base += bit * (length >>= 1);
		if (num > interval_base)
		{
			propagate_carry();
		}
		if (length < 16777216)
		{
			renorm_enc_interval();
		}
	}

	public void writeBits(int bits, uint sym)
	{
		if (bits > 19)
		{
			writeShort((ushort)sym);
			sym >>= 16;
			bits -= 16;
		}
		uint num = interval_base;
		interval_base += sym * (length >>= bits);
		if (num > interval_base)
		{
			propagate_carry();
		}
		if (length < 16777216)
		{
			renorm_enc_interval();
		}
	}

	public void writeByte(byte sym)
	{
		uint num = interval_base;
		interval_base += sym * (length >>= 8);
		if (num > interval_base)
		{
			propagate_carry();
		}
		if (length < 16777216)
		{
			renorm_enc_interval();
		}
	}

	public void writeShort(ushort sym)
	{
		uint num = interval_base;
		interval_base += sym * (length >>= 16);
		if (num > interval_base)
		{
			propagate_carry();
		}
		if (length < 16777216)
		{
			renorm_enc_interval();
		}
	}

	public void writeInt(uint sym)
	{
		writeShort((ushort)(sym & 0xFFFF));
		writeShort((ushort)(sym >> 16));
	}

	public unsafe void writeFloat(float sym)
	{
		writeInt(*(uint*)(&sym));
	}

	public void writeInt64(ulong sym)
	{
		writeInt((uint)(sym & 0xFFFFFFFFu));
		writeInt((uint)(sym >> 32));
	}

	public unsafe void writeDouble(double sym)
	{
		writeInt64(*(ulong*)(&sym));
	}

	public Stream getByteStreamOut()
	{
		return outstream;
	}

	private void propagate_carry()
	{
		int num = ((outbyte != 0) ? (outbyte - 1) : (endbuffer - 1));
		while (outbuffer[num] == byte.MaxValue)
		{
			outbuffer[num] = 0;
			num = ((num != 0) ? (num - 1) : (endbuffer - 1));
		}
		outbuffer[num]++;
	}

	private void renorm_enc_interval()
	{
		do
		{
			outbuffer[outbyte++] = (byte)(interval_base >> 24);
			if (outbyte == endbyte)
			{
				manage_outbuffer();
			}
			interval_base <<= 8;
		}
		while ((length <<= 8) < 16777216);
	}

	private void manage_outbuffer()
	{
		if (outbyte == endbuffer)
		{
			outbyte = 0;
		}
		outstream.Write(outbuffer, outbyte, 1024);
		endbyte = outbyte + 1024;
	}
}
internal class ArithmeticModel
{
	internal uint[] distribution;

	internal uint[] symbol_count;

	internal uint[] decoder_table;

	internal uint total_count;

	internal uint update_cycle;

	internal uint symbols_until_update;

	internal uint symbols;

	internal uint last_symbol;

	internal uint table_size;

	internal int table_shift;

	private bool compress;

	public ArithmeticModel(uint symbols, bool compress)
	{
		this.symbols = symbols;
		this.compress = compress;
		distribution = null;
	}

	public int init(uint[] table = null)
	{
		if (distribution == null)
		{
			if (symbols < 2 || symbols > 2048)
			{
				return -1;
			}
			try
			{
				last_symbol = symbols - 1;
				if (!compress && symbols > 16)
				{
					int i;
					for (i = 3; symbols > (uint)(1 << i + 2); i++)
					{
					}
					table_size = (uint)(1 << i);
					table_shift = 15 - i;
					decoder_table = new uint[table_size + 2];
				}
				else
				{
					decoder_table = null;
					table_size = 0u;
					table_shift = 0;
				}
				distribution = new uint[symbols];
				symbol_count = new uint[symbols];
			}
			catch
			{
				return -1;
			}
		}
		total_count = 0u;
		update_cycle = symbols;
		if (table != null)
		{
			for (uint num = 0u; num < symbols; num++)
			{
				symbol_count[num] = table[num];
			}
		}
		else
		{
			for (uint num2 = 0u; num2 < symbols; num2++)
			{
				symbol_count[num2] = 1u;
			}
		}
		update();
		symbols_until_update = (update_cycle = symbols + 6 >> 1);
		return 0;
	}

	internal void update()
	{
		if ((total_count += update_cycle) > 32768)
		{
			total_count = 0u;
			for (uint num = 0u; num < symbols; num++)
			{
				total_count += (symbol_count[num] = symbol_count[num] + 1 >> 1);
			}
		}
		uint num2 = 0u;
		uint num3 = 0u;
		uint num4 = 2147483648u / total_count;
		if (compress || table_size == 0)
		{
			for (uint num5 = 0u; num5 < symbols; num5++)
			{
				distribution[num5] = num4 * num2 >> 16;
				num2 += symbol_count[num5];
			}
		}
		else
		{
			for (uint num6 = 0u; num6 < symbols; num6++)
			{
				distribution[num6] = num4 * num2 >> 16;
				num2 += symbol_count[num6];
				uint num7 = distribution[num6] >> table_shift;
				while (num3 < num7)
				{
					decoder_table[++num3] = num6 - 1;
				}
			}
			decoder_table[0] = 0u;
			while (num3 <= table_size)
			{
				decoder_table[++num3] = symbols - 1;
			}
		}
		update_cycle = 5 * update_cycle >> 2;
		uint num8 = symbols + 6 << 3;
		if (update_cycle > num8)
		{
			update_cycle = num8;
		}
		symbols_until_update = update_cycle;
	}
}
internal static class ByteStreamIn
{
	[ThreadStatic]
	private static byte[] _buffer;

	private static byte[] buffer
	{
		get
		{
			if (_buffer == null)
			{
				_buffer = new byte[8];
			}
			return _buffer;
		}
	}

	public static bool getBytes(this Stream stream, byte[] bytes, int num_bytes)
	{
		return stream.Read(bytes, 0, num_bytes) == num_bytes;
	}

	public static bool getBytes(this Stream stream, byte[] bytes, int offset, int num_bytes)
	{
		return stream.Read(bytes, offset, num_bytes) == num_bytes;
	}

	public static bool get8bits(this Stream stream, out byte val)
	{
		val = 0;
		int num = stream.ReadByte();
		if (num < 0)
		{
			return false;
		}
		val = (byte)num;
		return true;
	}

	public static bool get16bits(this Stream stream, out ushort val)
	{
		val = 0;
		if (stream.Read(buffer, 0, 2) != 2)
		{
			return false;
		}
		val = BitConverter.ToUInt16(buffer, 0);
		return true;
	}

	public static bool get16bits(this Stream stream, ushort[] val, int num_ushorts)
	{
		if (stream.Read(buffer, 0, 2 * num_ushorts) != 2 * num_ushorts)
		{
			return false;
		}
		for (int i = 0; i < num_ushorts; i++)
		{
			val[i] = BitConverter.ToUInt16(buffer, 2 * i);
		}
		return true;
	}

	public static bool get32bits(this Stream stream, out int val)
	{
		val = 0;
		if (stream.Read(buffer, 0, 4) != 4)
		{
			return false;
		}
		val = BitConverter.ToInt32(buffer, 0);
		return true;
	}

	public static bool get32bits(this Stream stream, out uint val)
	{
		val = 0u;
		if (stream.Read(buffer, 0, 4) != 4)
		{
			return false;
		}
		val = BitConverter.ToUInt32(buffer, 0);
		return true;
	}

	public static bool get32bits(this Stream stream, out float val)
	{
		val = 0f;
		if (stream.Read(buffer, 0, 4) != 4)
		{
			return false;
		}
		val = BitConverter.ToSingle(buffer, 0);
		return true;
	}

	public static bool get64bits(this Stream stream, out ulong val)
	{
		val = 0uL;
		if (stream.Read(buffer, 0, 8) != 8)
		{
			return false;
		}
		val = BitConverter.ToUInt64(buffer, 0);
		return true;
	}

	public static bool get64bits(this Stream stream, out long val)
	{
		val = 0L;
		if (stream.Read(buffer, 0, 8) != 8)
		{
			return false;
		}
		val = BitConverter.ToInt64(buffer, 0);
		return true;
	}

	public static bool get64bits(this Stream stream, out double val)
	{
		val = 0.0;
		if (stream.Read(buffer, 0, 8) != 8)
		{
			return false;
		}
		val = BitConverter.ToDouble(buffer, 0);
		return true;
	}
}
internal static class AC
{
	internal const int HEADER_BYTE = 2;

	internal const int BUFFER_SIZE = 1024;

	internal const uint MinLength = 16777216u;

	internal const uint MaxLength = uint.MaxValue;
}
internal static class BM
{
	internal const int LengthShift = 13;

	internal const uint MaxCount = 8192u;
}
internal static class DM
{
	internal const int LengthShift = 15;

	internal const uint MaxCount = 32768u;
}
internal class IntegerCompressor
{
	private uint k;

	private uint contexts;

	private uint bits_high;

	private uint bits;

	private uint range;

	private uint corr_bits;

	private uint corr_range;

	private int corr_min;

	private int corr_max;

	private ArithmeticEncoder enc;

	private ArithmeticDecoder dec;

	private ArithmeticModel[] mBits;

	private ArithmeticModel[] mCorrector;

	private ArithmeticBitModel mCorrectorBit;

	public IntegerCompressor(ArithmeticEncoder enc, uint bits = 16u, uint contexts = 1u, uint bits_high = 8u, uint range = 0u)
	{
		this.enc = enc;
		dec = null;
		Init(bits, contexts, bits_high, range);
	}

	public IntegerCompressor(ArithmeticDecoder dec, uint bits = 16u, uint contexts = 1u, uint bits_high = 8u, uint range = 0u)
	{
		enc = null;
		this.dec = dec;
		Init(bits, contexts, bits_high, range);
	}

	private void Init(uint bits = 16u, uint contexts = 1u, uint bits_high = 8u, uint range = 0u)
	{
		this.bits = bits;
		this.contexts = contexts;
		this.bits_high = bits_high;
		this.range = range;
		if (range != 0)
		{
			corr_bits = 0u;
			corr_range = range;
			while (range != 0)
			{
				range >>= 1;
				corr_bits++;
			}
			if (corr_range == (uint)(1 << (int)(corr_bits - 1)))
			{
				corr_bits--;
			}
			corr_min = (int)(0 - corr_range / 2);
			corr_max = (int)(corr_min + corr_range - 1);
		}
		else if (bits != 0 && bits < 32)
		{
			corr_bits = bits;
			corr_range = (uint)(1 << (int)bits);
			corr_min = (int)(0 - corr_range / 2);
			corr_max = (int)(corr_min + corr_range - 1);
		}
		else
		{
			corr_bits = 32u;
			corr_range = 0u;
			corr_min = int.MinValue;
			corr_max = int.MaxValue;
		}
		k = 0u;
		mBits = null;
		mCorrector = null;
	}

	public void initCompressor()
	{
		if (mBits == null)
		{
			mBits = new ArithmeticModel[contexts];
			for (uint num = 0u; num < contexts; num++)
			{
				mBits[num] = enc.createSymbolModel(corr_bits + 1);
			}
			mCorrector = new ArithmeticModel[corr_bits + 1];
			mCorrectorBit = enc.createBitModel();
			for (uint num2 = 1u; num2 <= corr_bits; num2++)
			{
				if (num2 <= bits_high)
				{
					mCorrector[num2] = enc.createSymbolModel((uint)(1 << (int)num2));
				}
				else
				{
					mCorrector[num2] = enc.createSymbolModel((uint)(1 << (int)bits_high));
				}
			}
		}
		for (uint num3 = 0u; num3 < contexts; num3++)
		{
			enc.initSymbolModel(mBits[num3]);
		}
		enc.initBitModel(mCorrectorBit);
		for (uint num4 = 1u; num4 <= corr_bits; num4++)
		{
			enc.initSymbolModel(mCorrector[num4]);
		}
	}

	public void compress(int pred, int real, uint context = 0u)
	{
		int num = real - pred;
		if (num < corr_min)
		{
			num += (int)corr_range;
		}
		else if (num > corr_max)
		{
			num -= (int)corr_range;
		}
		writeCorrector(num, mBits[context]);
	}

	public void initDecompressor()
	{
		if (mBits == null)
		{
			mBits = new ArithmeticModel[contexts];
			for (uint num = 0u; num < contexts; num++)
			{
				mBits[num] = dec.createSymbolModel(corr_bits + 1);
			}
			mCorrector = new ArithmeticModel[corr_bits + 1];
			mCorrectorBit = dec.createBitModel();
			for (uint num2 = 1u; num2 <= corr_bits; num2++)
			{
				if (num2 <= bits_high)
				{
					mCorrector[num2] = dec.createSymbolModel((uint)(1 << (int)num2));
				}
				else
				{
					mCorrector[num2] = dec.createSymbolModel((uint)(1 << (int)bits_high));
				}
			}
		}
		for (uint num3 = 0u; num3 < contexts; num3++)
		{
			dec.initSymbolModel(mBits[num3]);
		}
		dec.initBitModel(mCorrectorBit);
		for (uint num4 = 1u; num4 <= corr_bits; num4++)
		{
			dec.initSymbolModel(mCorrector[num4]);
		}
	}

	public int decompress(int pred, uint context = 0u)
	{
		int num = pred + readCorrector(mBits[context]);
		if (num < 0)
		{
			num += (int)corr_range;
		}
		else if ((uint)num >= corr_range)
		{
			num -= (int)corr_range;
		}
		return num;
	}

	public uint getK()
	{
		return k;
	}

	private void writeCorrector(int c, ArithmeticModel model)
	{
		k = 0u;
		uint num = (uint)((c <= 0) ? (-c) : (c - 1));
		while (num != 0)
		{
			num >>= 1;
			k++;
		}
		enc.encodeSymbol(model, k);
		if (k != 0)
		{
			if (k < 32)
			{
				c = ((c >= 0) ? (c - 1) : (c + ((1 << (int)k) - 1)));
				if (k <= bits_high)
				{
					enc.encodeSymbol(mCorrector[k], (uint)c);
					return;
				}
				int num2 = (int)(k - bits_high);
				num = (uint)(c & ((1 << num2) - 1));
				c >>= num2;
				enc.encodeSymbol(mCorrector[k], (uint)c);
				enc.writeBits(num2, num);
			}
		}
		else
		{
			enc.encodeBit(mCorrectorBit, (uint)c);
		}
	}

	private int readCorrector(ArithmeticModel model)
	{
		k = dec.decodeSymbol(model);
		if (k != 0)
		{
			if (k < 32)
			{
				int num;
				if (k <= bits_high)
				{
					num = (int)dec.decodeSymbol(mCorrector[k]);
				}
				else
				{
					uint num2 = k - bits_high;
					num = (int)dec.decodeSymbol(mCorrector[k]);
					int num3 = (int)dec.readBits(num2);
					num = (num << (int)num2) | num3;
				}
				if (num >= 1 << (int)(k - 1))
				{
					return num + 1;
				}
				return num - ((1 << (int)k) - 1);
			}
			return corr_min;
		}
		return (int)dec.decodeBit(mCorrectorBit);
	}
}
public enum LAS_ATTRIBUTE
{
	U8,
	I8,
	U16,
	I16,
	U32,
	I32,
	U64,
	I64,
	F32,
	F64
}
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct LASattribute
{
	private unsafe fixed byte reserved[2];

	public byte data_type;

	public byte options;

	private unsafe fixed byte name[32];

	private unsafe fixed byte unused[4];

	public U64I64F64 no_data;

	private ulong no_data_1;

	private ulong no_data_2;

	public U64I64F64 min;

	private ulong min_1;

	private ulong min_2;

	public U64I64F64 max;

	private ulong max_1;

	private ulong max_2;

	public double scale;

	private double scale_1;

	private double scale_2;

	public double offset;

	private double offset_1;

	private double offset_2;

	private unsafe fixed byte description[32];

	public unsafe string Name
	{
		get
		{
			fixed (byte* value = name)
			{
				return new string((sbyte*)value);
			}
		}
		set
		{
			fixed (byte* dst = name)
			{
				strncpy(dst, value, 32);
			}
		}
	}

	public unsafe string Description
	{
		get
		{
			fixed (byte* value = description)
			{
				return new string((sbyte*)value);
			}
		}
		set
		{
			fixed (byte* dst = description)
			{
				strncpy(dst, value, 32);
			}
		}
	}

	private unsafe static int strncpy(byte* dst, byte[] src, int count)
	{
		int num = 0;
		if (src != null)
		{
			num = Math.Min(count, src.Length);
		}
		for (int i = 0; i < num; i++)
		{
			dst[i] = src[i];
		}
		for (int j = num; j < count; j++)
		{
			dst[j] = 0;
		}
		return num;
	}

	private unsafe static int strncpy(byte* dst, string src, int count)
	{
		if (src == null)
		{
			return strncpy(dst, (byte[])null, count);
		}
		return strncpy(dst, Encoding.ASCII.GetBytes(src), count);
	}

	public LASattribute(byte size)
	{
		this = default(LASattribute);
		if (size == 0)
		{
			throw new ArgumentOutOfRangeException("size", "Must be greater zero (0).");
		}
		options = size;
		scale = (scale_1 = (scale_2 = 1.0));
	}

	public LASattribute(LAS_ATTRIBUTE type, string name, string description = null)
	{
		this = default(LASattribute);
		if (type > LAS_ATTRIBUTE.F64)
		{
			throw new ArgumentOutOfRangeException("type", "Must be one of the enum values.");
		}
		if (name == null)
		{
			throw new ArgumentNullException("name");
		}
		scale = (scale_1 = (scale_2 = 1.0));
		data_type = (byte)(type + 1);
		Name = name;
		Description = description;
	}

	public bool set_no_data(byte no_data)
	{
		if (get_type() == 0)
		{
			this.no_data.u64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(sbyte no_data)
	{
		if (1 == get_type())
		{
			this.no_data.i64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(ushort no_data)
	{
		if (2 == get_type())
		{
			this.no_data.u64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(short no_data)
	{
		if (3 == get_type())
		{
			this.no_data.i64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(uint no_data)
	{
		if (4 == get_type())
		{
			this.no_data.u64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(int no_data)
	{
		if (5 == get_type())
		{
			this.no_data.i64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(ulong no_data)
	{
		if (6 == get_type())
		{
			this.no_data.u64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(long no_data)
	{
		if (7 == get_type())
		{
			this.no_data.i64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(float no_data)
	{
		if (8 == get_type())
		{
			this.no_data.f64 = no_data;
			options |= 1;
			return true;
		}
		return false;
	}

	public bool set_no_data(double no_data)
	{
		switch (get_type())
		{
		case 0:
		case 2:
		case 4:
		case 6:
			this.no_data.u64 = (ulong)no_data;
			options |= 1;
			return true;
		case 1:
		case 3:
		case 5:
		case 7:
			this.no_data.i64 = (long)no_data;
			options |= 1;
			return true;
		case 8:
		case 9:
			this.no_data.f64 = no_data;
			options |= 1;
			return true;
		default:
			return false;
		}
	}

	public void set_min(byte[] min)
	{
		this.min = cast(min);
		options |= 2;
	}

	public void update_min(byte[] min)
	{
		this.min = smallest(cast(min), this.min);
	}

	public bool set_min(byte min)
	{
		if (get_type() == 0)
		{
			this.min.u64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(sbyte min)
	{
		if (1 == get_type())
		{
			this.min.i64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(ushort min)
	{
		if (2 == get_type())
		{
			this.min.u64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(short min)
	{
		if (3 == get_type())
		{
			this.min.i64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(uint min)
	{
		if (4 == get_type())
		{
			this.min.u64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(int min)
	{
		if (5 == get_type())
		{
			this.min.i64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(ulong min)
	{
		if (6 == get_type())
		{
			this.min.u64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(long min)
	{
		if (7 == get_type())
		{
			this.min.i64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(float min)
	{
		if (8 == get_type())
		{
			this.min.f64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public bool set_min(double min)
	{
		if (9 == get_type())
		{
			this.min.f64 = min;
			options |= 2;
			return true;
		}
		return false;
	}

	public void set_max(byte[] max)
	{
		this.max = cast(max);
		options |= 4;
	}

	public void update_max(byte[] max)
	{
		this.max = biggest(cast(max), this.max);
	}

	public bool set_max(byte max)
	{
		if (get_type() == 0)
		{
			this.max.u64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(sbyte max)
	{
		if (1 == get_type())
		{
			this.max.i64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(ushort max)
	{
		if (2 == get_type())
		{
			this.max.u64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(short max)
	{
		if (3 == get_type())
		{
			this.max.i64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(uint max)
	{
		if (4 == get_type())
		{
			this.max.u64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(int max)
	{
		if (5 == get_type())
		{
			this.max.i64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(ulong max)
	{
		if (6 == get_type())
		{
			this.max.u64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(long max)
	{
		if (7 == get_type())
		{
			this.max.i64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(float max)
	{
		if (8 == get_type())
		{
			this.max.f64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_max(double max)
	{
		if (9 == get_type())
		{
			this.max.f64 = max;
			options |= 4;
			return true;
		}
		return false;
	}

	public bool set_scale(double scale)
	{
		if (data_type != 0)
		{
			this.scale = scale;
			options |= 8;
			return true;
		}
		return false;
	}

	public bool set_offset(double offset)
	{
		if (data_type != 0)
		{
			this.offset = offset;
			options |= 16;
			return true;
		}
		return false;
	}

	public bool has_no_data()
	{
		if (data_type != 0)
		{
			return (options & 1) != 0;
		}
		return false;
	}

	public bool has_min()
	{
		if (data_type != 0)
		{
			return (options & 2) != 0;
		}
		return false;
	}

	public bool has_max()
	{
		if (data_type != 0)
		{
			return (options & 4) != 0;
		}
		return false;
	}

	public bool has_scale()
	{
		if (data_type != 0)
		{
			return (options & 8) != 0;
		}
		return false;
	}

	public bool has_offset()
	{
		if (data_type != 0)
		{
			return (options & 0x10) != 0;
		}
		return false;
	}

	public int get_size()
	{
		if (data_type == 0)
		{
			return options;
		}
		switch (get_type())
		{
		default:
			return 1;
		case 2:
		case 3:
			return 2;
		case 4:
		case 5:
		case 8:
			return 4;
		case 6:
		case 7:
		case 9:
			return 8;
		}
	}

	public double get_value_as_float(byte[] value)
	{
		double num;
		switch (get_type())
		{
		case 0:
			num = (int)value[0];
			break;
		case 1:
			num = (sbyte)value[0];
			break;
		case 2:
			num = (int)BitConverter.ToUInt16(value, 0);
			break;
		case 3:
			num = BitConverter.ToInt16(value, 0);
			break;
		case 4:
			num = BitConverter.ToUInt32(value, 0);
			break;
		case 5:
			num = BitConverter.ToInt32(value, 0);
			break;
		case 6:
			num = BitConverter.ToUInt64(value, 0);
			break;
		case 7:
			num = BitConverter.ToInt64(value, 0);
			break;
		case 8:
			num = BitConverter.ToSingle(value, 0);
			break;
		case 9:
			num = BitConverter.ToDouble(value, 0);
			break;
		default:
			return 0.0;
		}
		return offset + scale * num;
	}

	private int get_type()
	{
		return (data_type - 1) % 10;
	}

	private int get_dim()
	{
		return 1;
	}

	private U64I64F64 cast(byte[] value)
	{
		return get_type() switch
		{
			0 => new U64I64F64
			{
				u64 = value[0]
			}, 
			1 => new U64I64F64
			{
				i64 = (sbyte)value[0]
			}, 
			2 => new U64I64F64
			{
				u64 = BitConverter.ToUInt16(value, 0)
			}, 
			3 => new U64I64F64
			{
				i64 = BitConverter.ToInt16(value, 0)
			}, 
			4 => new U64I64F64
			{
				u64 = BitConverter.ToUInt32(value, 0)
			}, 
			5 => new U64I64F64
			{
				i64 = BitConverter.ToInt32(value, 0)
			}, 
			6 => new U64I64F64
			{
				u64 = BitConverter.ToUInt64(value, 0)
			}, 
			7 => new U64I64F64
			{
				i64 = BitConverter.ToInt64(value, 0)
			}, 
			8 => new U64I64F64
			{
				f64 = BitConverter.ToSingle(value, 0)
			}, 
			9 => new U64I64F64
			{
				f64 = BitConverter.ToDouble(value, 0)
			}, 
			_ => default(U64I64F64), 
		};
	}

	private U64I64F64 smallest(U64I64F64 a, U64I64F64 b)
	{
		int type = get_type();
		if (type >= 8)
		{
			if (!(a.f64 < b.f64))
			{
				return b;
			}
			return a;
		}
		if ((type & 1) != 0)
		{
			if (a.i64 >= b.i64)
			{
				return b;
			}
			return a;
		}
		if (a.u64 >= b.u64)
		{
			return b;
		}
		return a;
	}

	private U64I64F64 biggest(U64I64F64 a, U64I64F64 b)
	{
		int type = get_type();
		if (type >= 8)
		{
			if (!(a.f64 > b.f64))
			{
				return b;
			}
			return a;
		}
		if ((type & 1) != 0)
		{
			if (a.i64 <= b.i64)
			{
				return b;
			}
			return a;
		}
		if (a.u64 <= b.u64)
		{
			return b;
		}
		return a;
	}
}
public class LASattributer
{
	public bool attributes_linked = true;

	public int number_attributes;

	public List<LASattribute> attributes;

	public List<int> attribute_starts;

	public List<int> attribute_sizes;

	public void clean_attributes()
	{
		if (attributes_linked)
		{
			number_attributes = 0;
			attributes = null;
			attribute_starts = null;
			attribute_sizes = null;
		}
	}

	public bool init_attributes(IEnumerable<LASattribute> attributes)
	{
		clean_attributes();
		try
		{
			this.attributes = new List<LASattribute>();
			attribute_starts = new List<int>();
			attribute_sizes = new List<int>();
		}
		catch
		{
			return false;
		}
		int num = 0;
		foreach (LASattribute attribute in attributes)
		{
			int size = attribute.get_size();
			if (size > 0)
			{
				number_attributes++;
				this.attributes.Add(attribute);
				attribute_starts.Add(num);
				attribute_sizes.Add(size);
				num += size;
			}
		}
		return true;
	}

	public int add_attribute(LASattribute attribute)
	{
		if (attribute.get_size() <= 0)
		{
			return -1;
		}
		try
		{
			int item = 0;
			if (attributes == null)
			{
				number_attributes = 0;
				attributes = new List<LASattribute>(1);
				attribute_starts = new List<int>(1);
				attribute_sizes = new List<int>(1);
			}
			else
			{
				item = attribute_starts[number_attributes - 1] + attribute_sizes[number_attributes - 1];
			}
			number_attributes++;
			attributes.Add(attribute);
			attribute_starts.Add(item);
			attribute_sizes.Add(attribute.get_size());
			return number_attributes - 1;
		}
		catch
		{
			return -1;
		}
	}

	public short get_attributes_size()
	{
		return (short)((attributes != null) ? (attribute_starts[number_attributes - 1] + attribute_sizes[number_attributes - 1]) : 0);
	}

	public int get_attribute_index(string name)
	{
		if (name.Length > 32)
		{
			name = name.Substring(0, 32);
		}
		for (int i = 0; i < number_attributes; i++)
		{
			if (attributes[i].Name == name)
			{
				return i;
			}
		}
		return -1;
	}

	public int get_attribute_start(int index)
	{
		if (index < 0 || index >= number_attributes)
		{
			return -1;
		}
		return attribute_starts[index];
	}

	public int get_attribute_start(string name)
	{
		return get_attribute_start(get_attribute_index(name));
	}

	public int get_attribute_size(int index)
	{
		if (index < 0 || index >= number_attributes)
		{
			return -1;
		}
		return attribute_sizes[index];
	}

	public int get_attribute_size(string name)
	{
		return get_attribute_size(get_attribute_index(name));
	}

	public bool remove_attribute(int index)
	{
		if (index < 0 || index >= number_attributes)
		{
			return false;
		}
		number_attributes--;
		if (number_attributes == 0)
		{
			clean_attributes();
			return true;
		}
		attributes.RemoveAt(index);
		attribute_starts.RemoveAt(index);
		attribute_sizes.RemoveAt(index);
		int num = ((index != 0) ? attribute_starts[index - 1] : 0);
		while (index < number_attributes)
		{
			attribute_starts[index] = num;
			num += attribute_sizes[index];
			index++;
		}
		return true;
	}

	public bool remove_attribute(string name)
	{
		return remove_attribute(get_attribute_index(name));
	}
}
internal class LASindex : IDisposable
{
	public uint start;

	public uint end;

	public uint full;

	public uint total;

	public uint cells;

	private LASquadtree spatial;

	private LASinterval interval;

	private bool have_interval;

	public void Dispose()
	{
		spatial = null;
		interval = null;
	}

	public void prepare(LASquadtree spatial, int threshold = 1000)
	{
		this.spatial = spatial;
		interval = new LASinterval((uint)threshold);
	}

	public bool add(double x, double y, uint p_index)
	{
		int c_index = (int)spatial.get_cell_index(x, y);
		return interval.add(p_index, c_index);
	}

	public void complete(uint minimum_points = 100000u, int maximum_intervals = -1, bool verbose = true)
	{
		if (verbose)
		{
			Console.Error.WriteLine("before complete {0}{1}", minimum_points, maximum_intervals);
			print(verbose: false);
		}
		if (minimum_points != 0)
		{
			int num = 0;
			Dictionary<int, uint>[] array = new Dictionary<int, uint>[2]
			{
				new Dictionary<int, uint>(),
				new Dictionary<int, uint>()
			};
			interval.get_cells();
			while (interval.has_cells())
			{
				array[num][interval.index] = interval.full;
			}
			while (array[num].Count != 0)
			{
				int num2 = (num + 1) % 2;
				array[num2].Clear();
				bool flag = false;
				HashSet<int> hashSet = new HashSet<int>();
				foreach (KeyValuePair<int, uint> item in array[num])
				{
					if (item.Value == 0 || hashSet.Contains(item.Key) || !spatial.coarsen(item.Key, out var coarser_cell_index, out var num_cell_indices, out var cell_indices))
					{
						continue;
					}
					uint num3 = 0u;
					uint num4 = 0u;
					for (uint num5 = 0u; num5 < num_cell_indices; num5++)
					{
						uint value;
						if (item.Key == cell_indices[num5])
						{
							num3 += item.Value;
							hashSet.Add(item.Key);
							num4++;
						}
						else if (hashSet.Contains(cell_indices[num5]))
						{
							num4++;
						}
						else if (array[num].TryGetValue(cell_indices[num5], out value))
						{
							num3 += value;
							hashSet.Add(cell_indices[num5]);
							num4++;
						}
					}
					if (num3 < minimum_points && num4 == num_cell_indices)
					{
						interval.merge_cells(cell_indices, coarser_cell_index);
						flag = true;
						array[num2][coarser_cell_index] = num3;
					}
				}
				if (!flag)
				{
					break;
				}
				num = (num + 1) % 2;
			}
			interval.get_cells();
			while (interval.has_cells())
			{
				spatial.manage_cell((uint)interval.index);
			}
			if (verbose)
			{
				Console.Error.WriteLine("after minimum_points {0}", minimum_points);
				print(verbose: false);
			}
		}
		if (maximum_intervals < 0)
		{
			maximum_intervals = -maximum_intervals * (int)interval.get_number_cells();
		}
		if (maximum_intervals != 0)
		{
			interval.merge_intervals((uint)maximum_intervals, verbose);
			if (verbose)
			{
				Console.Error.WriteLine("after maximum_intervals {0}", maximum_intervals);
				print(verbose: false);
			}
		}
	}

	public bool read(string file_name)
	{
		if (string.IsNullOrWhiteSpace(file_name))
		{
			return false;
		}
		string text = file_name;
		if (file_name.EndsWith(".las") || file_name.EndsWith(".laz"))
		{
			text = text.Substring(0, text.Length - 1) + "x";
		}
		else if (file_name.EndsWith(".LAS") || file_name.EndsWith(".LAZ"))
		{
			text = text.Substring(0, text.Length - 1) + "X";
		}
		else
		{
			int num = text.LastIndexOfAny(new char[2] { '/', '\\' });
			int num2 = text.LastIndexOf('.');
			if (num2 > num)
			{
				text = text.Substring(0, num2);
			}
			text += ".lax";
		}
		try
		{
			using FileStream stream = File.OpenRead(text);
			if (!read(stream))
			{
				Console.Error.WriteLine("ERROR (LASindex): cannot read '{0}'", text);
				return false;
			}
		}
		catch
		{
			return false;
		}
		return true;
	}

	public bool append(string file_name)
	{
		return false;
	}

	public bool write(string file_name)
	{
		if (string.IsNullOrWhiteSpace(file_name))
		{
			return false;
		}
		string text = file_name;
		if (file_name.EndsWith(".las") || file_name.EndsWith(".laz"))
		{
			text = text.Substring(0, text.Length - 1) + "x";
		}
		else if (file_name.EndsWith(".LAS") || file_name.EndsWith(".LAZ"))
		{
			text = text.Substring(0, text.Length - 1) + "X";
		}
		else
		{
			int num = text.LastIndexOfAny(new char[2] { '/', '\\' });
			int num2 = text.LastIndexOf('.');
			if (num2 > num)
			{
				text = text.Substring(0, num2);
			}
			text += ".lax";
		}
		try
		{
			using FileStream stream = File.OpenWrite(text);
			if (!write(stream))
			{
				Console.Error.WriteLine("ERROR (LASindex): cannot open '{0} for write'", text);
				return false;
			}
		}
		catch
		{
			return false;
		}
		return true;
	}

	public bool read(Stream stream)
	{
		if (interval != null)
		{
			interval.Dispose();
		}
		byte[] array = new byte[4];
		if (!stream.getBytes(array, 4))
		{
			Console.Error.WriteLine("ERROR (LASindex): reading signature");
			return false;
		}
		if (array[0] != 76 || array[1] != 65 || array[2] != 83 || array[3] != 83)
		{
			Console.Error.WriteLine("ERROR (LASindex): wrong signature '{0}{1}{3}{4}' instead of 'LASX'", (char)array[0], (char)array[1], (char)array[2], (char)array[3]);
			return false;
		}
		if (!stream.get32bits(out uint _))
		{
			Console.Error.WriteLine("ERROR (LASindex): reading version");
			return false;
		}
		spatial = new LASquadtree();
		if (!spatial.read(stream))
		{
			Console.Error.WriteLine("ERROR (LASindex): cannot read LASspatial (LASquadtree)");
			return false;
		}
		interval = new LASinterval();
		if (!interval.read(stream))
		{
			Console.Error.WriteLine("ERROR (LASindex): reading LASinterval");
			return false;
		}
		interval.get_cells();
		while (interval.has_cells())
		{
			spatial.manage_cell((uint)interval.index);
		}
		return true;
	}

	public bool write(Stream stream)
	{
		byte[] buffer = new byte[4] { 76, 65, 83, 88 };
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASindex): writing signature");
			return false;
		}
		buffer = BitConverter.GetBytes(0u);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASindex): writing version");
			return false;
		}
		if (!spatial.write(stream))
		{
			Console.Error.WriteLine("ERROR (LASindex): cannot write LASspatial (LASquadtree)");
			return false;
		}
		if (!interval.write(stream))
		{
			Console.Error.WriteLine("ERROR (LASindex): writing LASinterval");
			return false;
		}
		return true;
	}

	public bool intersect_rectangle(double r_min_x, double r_min_y, double r_max_x, double r_max_y)
	{
		have_interval = false;
		cells = spatial.intersect_rectangle(r_min_x, r_min_y, r_max_x, r_max_y);
		if (cells != 0)
		{
			return merge_intervals();
		}
		return false;
	}

	public bool intersect_tile(float ll_x, float ll_y, float size)
	{
		have_interval = false;
		cells = spatial.intersect_tile(ll_x, ll_y, size);
		if (cells != 0)
		{
			return merge_intervals();
		}
		return false;
	}

	public bool intersect_circle(double center_x, double center_y, double radius)
	{
		have_interval = false;
		cells = spatial.intersect_circle(center_x, center_y, radius);
		if (cells != 0)
		{
			return merge_intervals();
		}
		return false;
	}

	public bool get_intervals()
	{
		have_interval = false;
		return interval.get_merged_cell();
	}

	public bool has_intervals()
	{
		if (interval.has_intervals())
		{
			start = interval.start;
			end = interval.end;
			full = interval.full;
			have_interval = true;
			return true;
		}
		have_interval = false;
		return false;
	}

	public bool seek_next(LASreadPoint reader, ref long p_count)
	{
		if (!have_interval)
		{
			if (!has_intervals())
			{
				return false;
			}
			reader.seek((uint)p_count, start);
			p_count = start;
		}
		if (p_count == end)
		{
			have_interval = false;
		}
		return true;
	}

	public void print(bool verbose)
	{
		uint num = 0u;
		uint num2 = 0u;
		uint num3 = 0u;
		uint num4 = 0u;
		interval.get_cells();
		while (interval.has_cells())
		{
			uint num5 = 0u;
			uint num6 = 0u;
			while (interval.has_intervals())
			{
				num5 += interval.end - interval.start + 1;
				num6++;
			}
			if (num5 != interval.total)
			{
				Console.Error.WriteLine("ERROR: total_check {0} != interval->total {1}", num5, interval.total);
			}
			if (verbose)
			{
				Console.Error.WriteLine("cell {0} intervals {1} full {2} total {3} ({4:f2})", interval.index, num6, interval.full, interval.total, 100.0 * (double)interval.full / (double)interval.total);
			}
			num++;
			num2 += interval.full;
			num3 += interval.total;
			num4 += num6;
		}
		if (verbose)
		{
			Console.Error.WriteLine("total cells/intervals {0}/{1} full {2} ({3:f2})", num, num4, num2, 100.0 * (double)num2 / (double)num3);
		}
	}

	public LASquadtree get_spatial()
	{
		return spatial;
	}

	public LASinterval get_interval()
	{
		return interval;
	}

	private bool merge_intervals()
	{
		if (spatial.get_intersected_cells())
		{
			uint num = 0u;
			while (spatial.has_more_cells())
			{
				if (interval.get_cell(spatial.current_cell))
				{
					interval.add_current_cell_to_merge_cell_set();
					num++;
				}
			}
			if (num != 0)
			{
				bool result = interval.merge();
				full = interval.full;
				total = interval.total;
				interval.clear_merge_cell_set();
				return result;
			}
		}
		return false;
	}
}
internal class LASintervalCell
{
	public uint start;

	public uint end;

	public LASintervalCell next;

	public LASintervalCell()
	{
	}

	public LASintervalCell(uint p_index)
	{
		start = (end = p_index);
	}

	public LASintervalCell(LASintervalCell cell)
	{
		start = cell.start;
		end = cell.end;
	}
}
internal class LASintervalStartCell : LASintervalCell
{
	public uint full;

	public uint total;

	public LASintervalCell last;

	public LASintervalStartCell()
	{
	}

	public LASintervalStartCell(uint p_index)
		: base(p_index)
	{
		full = (total = 1u);
	}

	public bool add(uint p_index, uint threshold = 1000u)
	{
		uint num = last?.end ?? end;
		uint num2 = p_index - num;
		full++;
		if (num2 > threshold)
		{
			if (last != null)
			{
				last.next = new LASintervalCell(p_index);
				last = last.next;
			}
			else
			{
				next = new LASintervalCell(p_index);
				last = next;
			}
			total++;
			return true;
		}
		if (last != null)
		{
			last.end = p_index;
		}
		else
		{
			end = p_index;
		}
		total += num2;
		return false;
	}
}
internal class LASinterval : IDisposable
{
	public int index;

	public uint start;

	public uint end;

	public uint full;

	public uint total;

	private Dictionary<int, LASintervalStartCell> cells = new Dictionary<int, LASintervalStartCell>();

	private Dictionary<int, LASintervalStartCell>.Enumerator cellsEnumerator;

	private HashSet<LASintervalStartCell> cells_to_merge;

	private uint threshold;

	private uint number_intervals;

	private int last_index = int.MinValue;

	private LASintervalStartCell last_cell;

	private LASintervalStartCell merged_cells;

	private LASintervalCell current_cell;

	private bool merged_cells_temporary;

	public LASinterval(uint threshold = 1000u)
	{
		this.threshold = threshold;
	}

	public void Dispose()
	{
		foreach (KeyValuePair<int, LASintervalStartCell> cell in cells)
		{
			LASintervalCell lASintervalCell = cell.Value;
			while (lASintervalCell.next != null)
			{
				LASintervalCell next = lASintervalCell.next;
				lASintervalCell.next = null;
				lASintervalCell = next;
			}
		}
		cells.Clear();
		if (merged_cells != null)
		{
			if (merged_cells_temporary)
			{
				LASintervalCell lASintervalCell2 = merged_cells;
				while (lASintervalCell2.next != null)
				{
					LASintervalCell next2 = lASintervalCell2.next;
					lASintervalCell2.next = null;
					lASintervalCell2 = next2;
				}
			}
			merged_cells = null;
		}
		if (cells_to_merge != null)
		{
			cells_to_merge.Clear();
			cells_to_merge = null;
		}
	}

	public bool add(uint p_index, int c_index)
	{
		if (last_cell == null || last_index != c_index)
		{
			last_index = c_index;
			if (!cells.TryGetValue(c_index, out last_cell))
			{
				last_cell = new LASintervalStartCell(p_index);
				cells.Add(c_index, last_cell);
				number_intervals++;
				return true;
			}
		}
		if (last_cell.add(p_index, threshold))
		{
			number_intervals++;
			return true;
		}
		return false;
	}

	public uint get_number_cells()
	{
		return (uint)cells.Count;
	}

	public uint get_number_intervals()
	{
		return number_intervals;
	}

	public bool merge_cells(IReadOnlyList<int> indices, int new_index)
	{
		if (indices == null)
		{
			throw new ArgumentNullException("indices");
		}
		if (indices.Count == 1)
		{
			if (!cells.TryGetValue(indices[0], out var value))
			{
				return false;
			}
			cells.Add(new_index, value);
			cells.Remove(indices[0]);
		}
		else
		{
			if (cells_to_merge != null)
			{
				cells_to_merge.Clear();
			}
			for (int i = 0; i < indices.Count; i++)
			{
				add_cell_to_merge_cell_set(indices[i], erase: true);
			}
			if (!merge(erase: true))
			{
				return false;
			}
			cells.Add(new_index, merged_cells);
			merged_cells = null;
		}
		return true;
	}

	public void merge_intervals(uint maximum_intervals, bool verbose)
	{
		uint num = 0u;
		maximum_intervals = ((maximum_intervals >= get_number_cells()) ? (maximum_intervals - get_number_cells()) : 0u);
		SortedDictionary<uint, List<LASintervalCell>> sortedDictionary = new SortedDictionary<uint, List<LASintervalCell>>();
		uint num2 = 0u;
		foreach (KeyValuePair<int, LASintervalStartCell> cell in cells)
		{
			LASintervalCell lASintervalCell = cell.Value;
			while (lASintervalCell.next != null)
			{
				num = lASintervalCell.next.start - lASintervalCell.end - 1;
				if (!sortedDictionary.ContainsKey(num))
				{
					sortedDictionary[num] = new List<LASintervalCell>();
				}
				sortedDictionary[num].Add(lASintervalCell);
				lASintervalCell = lASintervalCell.next;
				num2++;
			}
		}
		if (num2 <= maximum_intervals)
		{
			if (!verbose)
			{
				return;
			}
			if (num2 == 0)
			{
				Console.Error.WriteLine("maximum_intervals: {0} number of interval gaps: 0", maximum_intervals);
				return;
			}
			using (SortedDictionary<uint, List<LASintervalCell>>.Enumerator enumerator2 = sortedDictionary.GetEnumerator())
			{
				if (enumerator2.MoveNext())
				{
					num = enumerator2.Current.Key;
				}
			}
			Console.Error.WriteLine("maximum_intervals: {0} number of interval gaps: {1} next largest interval gap {2}", maximum_intervals, num2, num);
			return;
		}
		uint num3 = num2;
		while (num3 > maximum_intervals)
		{
			LASintervalCell lASintervalCell2 = null;
			bool flag = false;
			using (SortedDictionary<uint, List<LASintervalCell>>.Enumerator enumerator2 = sortedDictionary.GetEnumerator())
			{
				if (enumerator2.MoveNext())
				{
					KeyValuePair<uint, List<LASintervalCell>> current = enumerator2.Current;
					num = current.Key;
					lASintervalCell2 = current.Value[0];
					current.Value.RemoveAt(0);
					flag = current.Value.Count == 0;
				}
			}
			if (flag)
			{
				sortedDictionary.Remove(num);
			}
			if (lASintervalCell2.start == 1 && lASintervalCell2.end == 0)
			{
				number_intervals--;
				continue;
			}
			LASintervalCell next = lASintervalCell2.next;
			lASintervalCell2.end = next.end;
			lASintervalCell2.next = next.next;
			if (lASintervalCell2.next != null)
			{
				uint key = lASintervalCell2.next.start - lASintervalCell2.end - 1;
				if (!sortedDictionary.ContainsKey(key))
				{
					sortedDictionary[key] = new List<LASintervalCell>();
				}
				sortedDictionary[key].Add(lASintervalCell2);
				next.start = 1u;
				next.end = 0u;
			}
			else
			{
				number_intervals--;
			}
			num3--;
		}
		foreach (KeyValuePair<uint, List<LASintervalCell>> item in sortedDictionary)
		{
			foreach (LASintervalCell item2 in item.Value)
			{
				if (item2.start == 1 && item2.end == 0)
				{
					number_intervals--;
				}
			}
		}
		Console.Error.WriteLine("largest interval gap increased to {0}", num);
		foreach (KeyValuePair<int, LASintervalStartCell> cell2 in cells)
		{
			LASintervalStartCell value = cell2.Value;
			value.total = 0u;
			for (LASintervalCell lASintervalCell3 = value; lASintervalCell3 != null; lASintervalCell3 = lASintervalCell3.next)
			{
				value.total += lASintervalCell3.end - lASintervalCell3.start + 1;
			}
		}
	}

	public void get_cells()
	{
		cellsEnumerator = cells.GetEnumerator();
		current_cell = null;
	}

	public bool has_cells()
	{
		if (!cellsEnumerator.MoveNext())
		{
			current_cell = null;
			return false;
		}
		KeyValuePair<int, LASintervalStartCell> current = cellsEnumerator.Current;
		index = current.Key;
		full = current.Value.full;
		total = current.Value.total;
		current_cell = current.Value;
		return true;
	}

	public bool get_cell(int c_index)
	{
		if (!cells.TryGetValue(c_index, out var value))
		{
			current_cell = null;
			return false;
		}
		index = c_index;
		full = value.full;
		total = value.total;
		current_cell = value;
		return true;
	}

	public bool add_current_cell_to_merge_cell_set()
	{
		if (current_cell == null)
		{
			return false;
		}
		if (cells_to_merge == null)
		{
			cells_to_merge = new HashSet<LASintervalStartCell>();
		}
		cells_to_merge.Add((LASintervalStartCell)current_cell);
		return true;
	}

	public bool add_cell_to_merge_cell_set(int c_index, bool erase)
	{
		if (!cells.TryGetValue(c_index, out var value))
		{
			return false;
		}
		if (cells_to_merge == null)
		{
			cells_to_merge = new HashSet<LASintervalStartCell>();
		}
		cells_to_merge.Add(value);
		if (erase)
		{
			cells.Remove(c_index);
		}
		return true;
	}

	public bool merge(bool erase = false)
	{
		if (merged_cells != null)
		{
			if (merged_cells_temporary)
			{
				LASintervalCell lASintervalCell = merged_cells;
				while (lASintervalCell.next != null)
				{
					LASintervalCell next = lASintervalCell.next;
					lASintervalCell.next = null;
					lASintervalCell = next;
				}
			}
			merged_cells = null;
		}
		if (cells_to_merge == null || cells_to_merge.Count == 0)
		{
			return false;
		}
		if (cells_to_merge.Count == 1)
		{
			merged_cells_temporary = false;
			using HashSet<LASintervalStartCell>.Enumerator enumerator = cells_to_merge.GetEnumerator();
			if (enumerator.MoveNext())
			{
				LASintervalStartCell current = enumerator.Current;
				merged_cells = current;
			}
		}
		else
		{
			merged_cells_temporary = true;
			merged_cells = new LASintervalStartCell();
			SortedDictionary<uint, List<LASintervalCell>> sortedDictionary = new SortedDictionary<uint, List<LASintervalCell>>();
			foreach (LASintervalStartCell item in cells_to_merge)
			{
				LASintervalCell lASintervalCell2 = item;
				merged_cells.full += item.full;
				while (lASintervalCell2 != null)
				{
					if (!sortedDictionary.ContainsKey(lASintervalCell2.start))
					{
						sortedDictionary[lASintervalCell2.start] = new List<LASintervalCell>();
					}
					sortedDictionary[lASintervalCell2.start].Add(lASintervalCell2);
					lASintervalCell2 = lASintervalCell2.next;
				}
			}
			foreach (KeyValuePair<uint, List<LASintervalCell>> item2 in sortedDictionary)
			{
				LASintervalCell lASintervalCell2 = item2.Value[0];
				item2.Value.RemoveAt(0);
				merged_cells.start = lASintervalCell2.start;
				merged_cells.end = lASintervalCell2.end;
				merged_cells.total = lASintervalCell2.end - lASintervalCell2.start + 1;
			}
			LASintervalCell next2 = merged_cells;
			foreach (KeyValuePair<uint, List<LASintervalCell>> item3 in sortedDictionary)
			{
				foreach (LASintervalCell item4 in item3.Value)
				{
					int num = (int)(item4.start - next2.end);
					if (num > (int)threshold)
					{
						next2.next = new LASintervalCell(item4);
						next2 = next2.next;
						merged_cells.total += item4.end - item4.start + 1;
						continue;
					}
					num = (int)(item4.end - next2.end);
					if (num > 0)
					{
						next2.end = item4.end;
						merged_cells.total += (uint)num;
					}
					number_intervals--;
				}
				item3.Value.Clear();
			}
			sortedDictionary.Clear();
		}
		current_cell = merged_cells;
		full = merged_cells.full;
		total = merged_cells.total;
		return false;
	}

	public void clear_merge_cell_set()
	{
		if (cells_to_merge != null)
		{
			cells_to_merge.Clear();
		}
	}

	public bool get_merged_cell()
	{
		if (merged_cells == null)
		{
			return false;
		}
		full = merged_cells.full;
		total = merged_cells.total;
		current_cell = merged_cells;
		return true;
	}

	public bool has_intervals()
	{
		if (current_cell == null)
		{
			return false;
		}
		start = current_cell.start;
		end = current_cell.end;
		current_cell = current_cell.next;
		return true;
	}

	public bool read(Stream stream)
	{
		byte[] array = new byte[4];
		if (!stream.getBytes(array, 4))
		{
			Console.Error.WriteLine("ERROR (LASinterval): reading signature");
			return false;
		}
		if (array[0] != 76 && array[1] != 65 && array[2] != 83 && array[3] != 86)
		{
			Console.Error.WriteLine("ERROR (LASinterval): wrong signature '{0}{1}{3}{4}' instead of 'LASV'", (char)array[0], (char)array[1], (char)array[2], (char)array[3]);
			return false;
		}
		if (!stream.get32bits(out uint _))
		{
			Console.Error.WriteLine("ERROR (LASinterval): reading version");
			return false;
		}
		if (!stream.get32bits(out uint val2))
		{
			Console.Error.WriteLine("ERROR (LASinterval): reading number of cells");
			return false;
		}
		while (val2 != 0)
		{
			if (!stream.get32bits(out int val3))
			{
				Console.Error.WriteLine("ERROR (LASinterval): reading cell index");
				return false;
			}
			LASintervalStartCell lASintervalStartCell = new LASintervalStartCell();
			cells.Add(val3, lASintervalStartCell);
			LASintervalCell lASintervalCell = lASintervalStartCell;
			if (!stream.get32bits(out uint val4))
			{
				Console.Error.WriteLine("ERROR (LASinterval): reading number of intervals in cell");
				return false;
			}
			if (!stream.get32bits(out uint val5))
			{
				Console.Error.WriteLine("ERROR (LASinterval): reading number of points in cell");
				return false;
			}
			lASintervalStartCell.full = val5;
			lASintervalStartCell.total = 0u;
			while (val4 != 0)
			{
				if (!stream.get32bits(out lASintervalCell.start))
				{
					Console.Error.WriteLine("ERROR (LASinterval): reading start of interval");
					return false;
				}
				if (!stream.get32bits(out lASintervalCell.end))
				{
					Console.Error.WriteLine("ERROR (LASinterval): reading end of interval");
					return false;
				}
				lASintervalStartCell.total += lASintervalCell.end - lASintervalCell.start + 1;
				val4--;
				if (val4 != 0)
				{
					lASintervalCell.next = new LASintervalCell();
					lASintervalCell = lASintervalCell.next;
				}
			}
			val2--;
		}
		return true;
	}

	public bool write(Stream stream)
	{
		try
		{
			stream.WriteByte(76);
			stream.WriteByte(65);
			stream.WriteByte(83);
			stream.WriteByte(86);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASinterval): writing signature");
			return false;
		}
		uint value = 0u;
		try
		{
			stream.Write(BitConverter.GetBytes(value), 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASinterval): writing version");
			return false;
		}
		try
		{
			stream.Write(BitConverter.GetBytes((uint)cells.Count), 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASinterval): writing number of cells {0}", (uint)cells.Count);
			return false;
		}
		foreach (KeyValuePair<int, LASintervalStartCell> cell in cells)
		{
			LASintervalCell lASintervalCell = cell.Value;
			uint num = 0u;
			uint num2 = ((LASintervalStartCell)lASintervalCell).full;
			while (lASintervalCell != null)
			{
				num++;
				lASintervalCell = lASintervalCell.next;
			}
			int key = cell.Key;
			try
			{
				stream.Write(BitConverter.GetBytes(key), 0, 4);
			}
			catch
			{
				Console.Error.WriteLine("ERROR (LASinterval): writing cell index {0}", key);
				return false;
			}
			try
			{
				stream.Write(BitConverter.GetBytes(num), 0, 4);
			}
			catch
			{
				Console.Error.WriteLine("ERROR (LASinterval): writing number of intervals {0} in cell", num);
				return false;
			}
			try
			{
				stream.Write(BitConverter.GetBytes(num2), 0, 4);
			}
			catch
			{
				Console.Error.WriteLine("ERROR (LASinterval): writing number of point {0} in cell", num2);
				return false;
			}
			for (lASintervalCell = cell.Value; lASintervalCell != null; lASintervalCell = lASintervalCell.next)
			{
				try
				{
					stream.Write(BitConverter.GetBytes(lASintervalCell.start), 0, 4);
				}
				catch
				{
					Console.Error.WriteLine("ERROR (LASinterval): writing start {0} of interval", lASintervalCell.start);
					return false;
				}
				try
				{
					stream.Write(BitConverter.GetBytes(lASintervalCell.end), 0, 4);
				}
				catch
				{
					Console.Error.WriteLine("ERROR (LASinterval): writing end {0} of interval", lASintervalCell.end);
					return false;
				}
			}
		}
		return true;
	}
}
internal class LASitem
{
	public enum Type
	{
		BYTE,
		SHORT,
		INT,
		LONG,
		FLOAT,
		DOUBLE,
		POINT10,
		GPSTIME11,
		RGB12,
		WAVEPACKET13,
		POINT14,
		RGB14,
		RGBNIR14,
		WAVEPACKET14,
		BYTE14
	}

	public Type type;

	public ushort size;

	public ushort version;

	public bool is_type(Type t)
	{
		if (t != type)
		{
			return false;
		}
		switch (t)
		{
		case Type.POINT10:
			if (size != 20)
			{
				return false;
			}
			break;
		case Type.POINT14:
			if (size != 30)
			{
				return false;
			}
			break;
		case Type.GPSTIME11:
			if (size != 8)
			{
				return false;
			}
			break;
		case Type.RGB12:
			if (size != 6)
			{
				return false;
			}
			break;
		case Type.BYTE:
			if (size < 1)
			{
				return false;
			}
			break;
		case Type.RGB14:
			if (size != 6)
			{
				return false;
			}
			break;
		case Type.RGBNIR14:
			if (size != 8)
			{
				return false;
			}
			break;
		case Type.BYTE14:
			if (size < 1)
			{
				return false;
			}
			break;
		case Type.WAVEPACKET13:
			if (size != 29)
			{
				return false;
			}
			break;
		case Type.WAVEPACKET14:
			if (size != 29)
			{
				return false;
			}
			break;
		default:
			return false;
		}
		return true;
	}

	public string get_name()
	{
		return type switch
		{
			Type.POINT10 => "POINT10", 
			Type.POINT14 => "POINT14", 
			Type.GPSTIME11 => "GPSTIME11", 
			Type.RGB12 => "RGB12", 
			Type.BYTE => "BYTE", 
			Type.RGB14 => "RGB14", 
			Type.RGBNIR14 => "RGBNIR14", 
			Type.BYTE14 => "BYTE14", 
			Type.WAVEPACKET13 => "WAVEPACKET13", 
			Type.WAVEPACKET14 => "WAVEPACKET14", 
			_ => null, 
		};
	}
}
internal delegate bool does_cell_exist_proc(int cell_index);
internal class LASquadtree
{
	private const int LAS_SPATIAL_QUAD_TREE = 0;

	public uint levels;

	public float cell_size;

	public float min_x;

	public float max_x;

	public float min_y;

	public float max_y;

	public uint cells_x;

	public uint cells_y;

	public int current_cell;

	private uint sub_level;

	private uint sub_level_index;

	private readonly uint[] level_offset = new uint[24];

	private uint adaptive_alloc;

	private uint[] adaptive;

	private List<int> current_cells;

	private uint next_cell_index;

	public LASquadtree()
	{
		levels = 0u;
		cell_size = 0f;
		min_x = 0f;
		max_x = 0f;
		min_y = 0f;
		max_y = 0f;
		cells_x = 0u;
		cells_y = 0u;
		sub_level = 0u;
		sub_level_index = 0u;
		level_offset[0] = 0u;
		for (int i = 0; i < 23; i++)
		{
			level_offset[i + 1] = level_offset[i] + (uint)((1 << i) * (1 << i));
		}
		current_cells = null;
		adaptive_alloc = 0u;
		adaptive = null;
	}

	public bool read(Stream stream)
	{
		byte[] array = new byte[4];
		if (!stream.getBytes(array, 4))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading LASspatial signature");
			return false;
		}
		if (array[0] != 76 || array[1] != 65 || array[2] != 83 || array[3] != 83)
		{
			Console.Error.WriteLine("ERROR (LASquadtree): wrong LASspatial signature '{0}{1}{3}{4}' instead of 'LASS'", (char)array[0], (char)array[1], (char)array[2], (char)array[3]);
			return false;
		}
		if (!stream.get32bits(out uint val))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading LASspatial type");
			return false;
		}
		if (val != 0)
		{
			Console.Error.WriteLine("ERROR (LASquadtree): unknown LASspatial type {0}", val);
			return false;
		}
		if (!stream.getBytes(array, 4))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading signature");
			return false;
		}
		if (array[0] != 76 || array[1] != 65 || array[2] != 83 || array[3] != 81)
		{
			levels = (uint)((array[3] << 24) | (array[2] << 16) | (array[1] << 8) | array[0]);
		}
		else
		{
			if (!stream.get32bits(out uint _))
			{
				Console.Error.WriteLine("ERROR (LASquadtree): reading version");
				return false;
			}
			if (!stream.get32bits(out levels))
			{
				Console.Error.WriteLine("ERROR (LASquadtree): reading levels");
				return false;
			}
		}
		if (!stream.get32bits(out uint _))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading level_index");
			return false;
		}
		if (!stream.get32bits(out uint _))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading implicit_levels");
			return false;
		}
		if (!stream.get32bits(out min_x))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading min_x");
			return false;
		}
		if (!stream.get32bits(out max_x))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading max_x");
			return false;
		}
		if (!stream.get32bits(out min_y))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading min_y");
			return false;
		}
		if (!stream.get32bits(out max_y))
		{
			Console.Error.WriteLine("ERROR (LASquadtree): reading max_y");
			return false;
		}
		return true;
	}

	public bool write(Stream stream)
	{
		byte[] buffer = new byte[4] { 76, 65, 83, 83 };
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing LASspatial signature");
			return false;
		}
		uint num = 0u;
		buffer = BitConverter.GetBytes(num);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing LASspatial type {0}", num);
			return false;
		}
		buffer[0] = 76;
		buffer[1] = 65;
		buffer[2] = 83;
		buffer[3] = 81;
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing signature");
			return false;
		}
		buffer = BitConverter.GetBytes(0u);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing version");
			return false;
		}
		buffer = BitConverter.GetBytes(levels);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing levels {0}", levels);
			return false;
		}
		uint num2 = 0u;
		buffer = BitConverter.GetBytes(num2);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing level_index {0}", num2);
			return false;
		}
		uint num3 = 0u;
		buffer = BitConverter.GetBytes(num3);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing implicit_levels {0}", num3);
			return false;
		}
		buffer = BitConverter.GetBytes(min_x);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing min_x {0}", min_x);
			return false;
		}
		buffer = BitConverter.GetBytes(max_x);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing max_x {0}", max_x);
			return false;
		}
		buffer = BitConverter.GetBytes(min_y);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing min_y {0}", min_y);
			return false;
		}
		buffer = BitConverter.GetBytes(max_y);
		try
		{
			stream.Write(buffer, 0, 4);
		}
		catch
		{
			Console.Error.WriteLine("ERROR (LASquadtree): writing max_y {0}", max_y);
			return false;
		}
		return true;
	}

	public bool manage_cell(uint cell_index, bool finalize = false)
	{
		uint num = cell_index / 32;
		uint num2 = (uint)(1 << (int)(cell_index % 32));
		if (num >= adaptive_alloc)
		{
			if (adaptive != null)
			{
				uint[] array = adaptive;
				adaptive = new uint[num * 2];
				Array.Copy(array, adaptive, array.Length);
				for (uint num3 = adaptive_alloc; num3 < num * 2; num3++)
				{
					adaptive[num3] = 0u;
				}
				adaptive_alloc = num * 2;
			}
			else
			{
				adaptive = new uint[num + 1];
				for (uint num4 = adaptive_alloc; num4 <= num; num4++)
				{
					adaptive[num4] = 0u;
				}
				adaptive_alloc = num + 1;
			}
		}
		adaptive[num] &= ~num2;
		uint num5 = get_level(cell_index);
		uint num6 = get_level_index(cell_index, num5);
		while (num5 != 0)
		{
			num5--;
			num6 >>= 2;
			uint num7 = get_cell_index(num6, num5);
			num = num7 / 32;
			num2 = (uint)(1 << (int)(num7 % 32));
			if ((adaptive[num] & num2) != 0)
			{
				break;
			}
			adaptive[num] |= num2;
		}
		return true;
	}

	public bool inside(double x, double y)
	{
		if ((double)min_x <= x && x < (double)max_x && (double)min_y <= y)
		{
			return y < (double)max_y;
		}
		return false;
	}

	public uint get_cell_index(double x, double y)
	{
		return get_cell_index(x, y, levels);
	}

	public bool coarsen(int cell_index, out int coarser_cell_index, out uint num_cell_indices, out int[] cell_indices)
	{
		coarser_cell_index = 0;
		num_cell_indices = 0u;
		cell_indices = null;
		if (cell_index < 0)
		{
			return false;
		}
		uint num = get_level((uint)cell_index);
		if (num == 0)
		{
			return false;
		}
		uint num2 = get_level_index((uint)cell_index, num);
		num2 >>= 2;
		coarser_cell_index = (int)get_cell_index(num2, num - 1);
		num_cell_indices = 4u;
		cell_indices = new int[4];
		num2 <<= 2;
		cell_indices[0] = (int)get_cell_index(num2, num);
		cell_indices[1] = (int)get_cell_index(num2 + 1, num);
		cell_indices[2] = (int)get_cell_index(num2 + 2, num);
		cell_indices[3] = (int)get_cell_index(num2 + 3, num);
		return true;
	}

	public void get_cell_bounding_box(int cell_index, float[] min, float[] max)
	{
		uint level = get_level((uint)cell_index);
		uint level_index = get_level_index((uint)cell_index, level);
		get_cell_bounding_box(level_index, level, min, max);
	}

	public void get_cell_bounding_box(double x, double y, float[] min, float[] max)
	{
		get_cell_bounding_box(x, y, levels, min, max);
	}

	public double get_min_x()
	{
		return min_x;
	}

	public double get_min_y()
	{
		return min_y;
	}

	public double get_max_x()
	{
		return max_x;
	}

	public double get_max_y()
	{
		return max_y;
	}

	public uint intersect_rectangle(double r_min_x, double r_min_y, double r_max_x, double r_max_y)
	{
		return intersect_rectangle(r_min_x, r_min_y, r_max_x, r_max_y, levels);
	}

	public uint intersect_tile(float ll_x, float ll_y, float size)
	{
		return intersect_tile(ll_x, ll_y, size, levels);
	}

	public uint intersect_circle(double center_x, double center_y, double radius)
	{
		return intersect_circle(center_x, center_y, radius, levels);
	}

	public bool get_all_cells()
	{
		intersect_rectangle(min_x, min_y, max_x, max_y);
		return get_intersected_cells();
	}

	public bool get_intersected_cells()
	{
		next_cell_index = 0u;
		if (current_cells == null)
		{
			return false;
		}
		if (current_cells.Count == 0)
		{
			return false;
		}
		return true;
	}

	public bool has_more_cells()
	{
		if (current_cells == null)
		{
			return false;
		}
		if (next_cell_index >= current_cells.Count)
		{
			return false;
		}
		if (adaptive != null)
		{
			current_cell = current_cells[(int)next_cell_index];
		}
		else
		{
			current_cell = (int)level_offset[levels] + current_cells[(int)next_cell_index];
		}
		next_cell_index++;
		return true;
	}

	public bool setup(double bb_min_x, double bb_max_x, double bb_min_y, double bb_max_y, float cell_size = 1000f)
	{
		this.cell_size = cell_size;
		sub_level = 0u;
		sub_level_index = 0u;
		if (bb_min_x >= 0.0)
		{
			min_x = cell_size * (float)(int)(bb_min_x / (double)cell_size);
		}
		else
		{
			min_x = cell_size * (float)((int)(bb_min_x / (double)cell_size) - 1);
		}
		if (bb_max_x >= 0.0)
		{
			max_x = cell_size * (float)((int)(bb_max_x / (double)cell_size) + 1);
		}
		else
		{
			max_x = cell_size * (float)(int)(bb_max_x / (double)cell_size);
		}
		if (bb_min_y >= 0.0)
		{
			min_y = cell_size * (float)(int)(bb_min_y / (double)cell_size);
		}
		else
		{
			min_y = cell_size * (float)((int)(bb_min_y / (double)cell_size) - 1);
		}
		if (bb_max_y >= 0.0)
		{
			max_y = cell_size * (float)((int)(bb_max_y / (double)cell_size) + 1);
		}
		else
		{
			max_y = cell_size * (float)(int)(bb_max_y / (double)cell_size);
		}
		cells_x = MyDefs.U32_QUANTIZE((max_x - min_x) / cell_size);
		cells_y = MyDefs.U32_QUANTIZE((max_y - min_y) / cell_size);
		if (cells_x == 0 || cells_y == 0)
		{
			Console.Error.WriteLine("ERROR: cells_x {0} cells_y {1}", cells_x, cells_y);
			return false;
		}
		uint num = ((cells_x > cells_y) ? (cells_x - 1) : (cells_y - 1));
		levels = 0u;
		while (num != 0)
		{
			num >>= 1;
			levels++;
		}
		num = (uint)(1 << (int)levels) - cells_x;
		uint num2 = num / 2;
		uint num3 = num - num2;
		min_x -= (float)num3 * cell_size;
		max_x += (float)num2 * cell_size;
		num = (uint)(1 << (int)levels) - cells_y;
		num2 = num / 2;
		num3 = num - num2;
		min_y -= (float)num3 * cell_size;
		max_y += (float)num2 * cell_size;
		return true;
	}

	public bool setup(double bb_min_x, double bb_max_x, double bb_min_y, double bb_max_y, float cell_size, float offset_x, float offset_y)
	{
		this.cell_size = cell_size;
		sub_level = 0u;
		sub_level_index = 0u;
		if (bb_min_x - (double)offset_x >= 0.0)
		{
			min_x = cell_size * (float)(int)((bb_min_x - (double)offset_x) / (double)cell_size) + offset_x;
		}
		else
		{
			min_x = cell_size * (float)((int)((bb_min_x - (double)offset_x) / (double)cell_size) - 1) + offset_x;
		}
		if (bb_max_x - (double)offset_x >= 0.0)
		{
			max_x = cell_size * (float)((int)((bb_max_x - (double)offset_x) / (double)cell_size) + 1) + offset_x;
		}
		else
		{
			max_x = cell_size * (float)(int)((bb_max_x - (double)offset_x) / (double)cell_size) + offset_x;
		}
		if (bb_min_y - (double)offset_y >= 0.0)
		{
			min_y = cell_size * (float)(int)((bb_min_y - (double)offset_y) / (double)cell_size) + offset_y;
		}
		else
		{
			min_y = cell_size * (float)((int)((bb_min_y - (double)offset_y) / (double)cell_size) - 1) + offset_y;
		}
		if (bb_max_y - (double)offset_y >= 0.0)
		{
			max_y = cell_size * (float)((int)((bb_max_y - (double)offset_y) / (double)cell_size) + 1) + offset_y;
		}
		else
		{
			max_y = cell_size * (float)(int)((bb_max_y - (double)offset_y) / (double)cell_size) + offset_y;
		}
		cells_x = MyDefs.U32_QUANTIZE((max_x - min_x) / cell_size);
		cells_y = MyDefs.U32_QUANTIZE((max_y - min_y) / cell_size);
		if (cells_x == 0 || cells_y == 0)
		{
			Console.Error.WriteLine("ERROR: cells_x {0} cells_y {1}", cells_x, cells_y);
			return false;
		}
		uint num = ((cells_x > cells_y) ? (cells_x - 1) : (cells_y - 1));
		levels = 0u;
		while (num != 0)
		{
			num >>= 1;
			levels++;
		}
		num = (uint)(1 << (int)levels) - cells_x;
		uint num2 = num / 2;
		uint num3 = num - num2;
		min_x -= (float)num3 * cell_size;
		max_x += (float)num2 * cell_size;
		num = (uint)(1 << (int)levels) - cells_y;
		num2 = num / 2;
		num3 = num - num2;
		min_y -= (float)num3 * cell_size;
		max_y += (float)num2 * cell_size;
		return true;
	}

	public bool tiling_setup(float min_x, float max_x, float min_y, float max_y, uint levels)
	{
		this.min_x = min_x;
		this.max_x = max_x;
		this.min_y = min_y;
		this.max_y = max_y;
		this.levels = levels;
		sub_level = 0u;
		sub_level_index = 0u;
		return true;
	}

	public bool subtiling_setup(float min_x, float max_x, float min_y, float max_y, uint sub_level, uint sub_level_index, uint levels)
	{
		this.min_x = min_x;
		this.max_x = max_x;
		this.min_y = min_y;
		this.max_y = max_y;
		float[] array = new float[2];
		float[] array2 = new float[2];
		get_cell_bounding_box(sub_level_index, sub_level, array, array2);
		this.min_x = array[0];
		this.max_x = array2[0];
		this.min_y = array[1];
		this.max_y = array2[1];
		this.sub_level = sub_level;
		this.sub_level_index = sub_level_index;
		this.levels = levels;
		return true;
	}

	public uint get_level_index(double x, double y, uint level)
	{
		float num = min_x;
		float num2 = max_x;
		float num3 = min_y;
		float num4 = max_y;
		uint num5 = 0u;
		while (level != 0)
		{
			num5 <<= 2;
			float num6 = (num + num2) / 2f;
			float num7 = (num3 + num4) / 2f;
			if (x < (double)num6)
			{
				num2 = num6;
			}
			else
			{
				num = num6;
				num5 |= 1;
			}
			if (y < (double)num7)
			{
				num4 = num7;
			}
			else
			{
				num3 = num7;
				num5 |= 2;
			}
			level--;
		}
		return num5;
	}

	public uint get_level_index(double x, double y)
	{
		return get_level_index(x, y, levels);
	}

	public uint get_level_index(double x, double y, uint level, float[] min, float[] max)
	{
		float num = min_x;
		float num2 = max_x;
		float num3 = min_y;
		float num4 = max_y;
		uint num5 = 0u;
		while (level != 0)
		{
			num5 <<= 2;
			float num6 = (num + num2) / 2f;
			float num7 = (num3 + num4) / 2f;
			if (x < (double)num6)
			{
				num2 = num6;
			}
			else
			{
				num = num6;
				num5 |= 1;
			}
			if (y < (double)num7)
			{
				num4 = num7;
			}
			else
			{
				num3 = num7;
				num5 |= 2;
			}
			level--;
		}
		if (min != null && min.Length >= 2)
		{
			min[0] = num;
			min[1] = num3;
		}
		if (max != null && max.Length >= 2)
		{
			max[0] = num2;
			max[1] = num4;
		}
		return num5;
	}

	public uint get_level_index(double x, double y, float[] min, float[] max)
	{
		return get_level_index(x, y, levels, min, max);
	}

	public uint get_cell_index(double x, double y, uint level)
	{
		if (sub_level != 0)
		{
			return level_offset[sub_level + level] + (sub_level_index << (int)(level * 2)) + get_level_index(x, y, level);
		}
		return level_offset[level] + get_level_index(x, y, level);
	}

	public void get_cell_bounding_box(double x, double y, uint level, float[] min, float[] max)
	{
		float num = min_x;
		float num2 = max_x;
		float num3 = min_y;
		float num4 = max_y;
		while (level != 0)
		{
			float num5 = (num + num2) / 2f;
			float num6 = (num3 + num4) / 2f;
			if (x < (double)num5)
			{
				num2 = num5;
			}
			else
			{
				num = num5;
			}
			if (y < (double)num6)
			{
				num4 = num6;
			}
			else
			{
				num3 = num6;
			}
			level--;
		}
		if (min != null && min.Length >= 2)
		{
			min[0] = num;
			min[1] = num3;
		}
		if (max != null && max.Length >= 2)
		{
			max[0] = num2;
			max[1] = num4;
		}
	}

	public void get_cell_bounding_box(uint level_index, uint level, float[] min, float[] max)
	{
		float num = min_x;
		float num2 = max_x;
		float num3 = min_y;
		float num4 = max_y;
		while (level != 0)
		{
			uint num5 = (level_index >> (int)(2 * (level - 1))) & 3;
			float num6 = (num + num2) / 2f;
			float num7 = (num3 + num4) / 2f;
			if ((num5 & 1) != 0)
			{
				num = num6;
			}
			else
			{
				num2 = num6;
			}
			if ((num5 & 2) != 0)
			{
				num3 = num7;
			}
			else
			{
				num4 = num7;
			}
			level--;
		}
		if (min != null && min.Length >= 2)
		{
			min[0] = num;
			min[1] = num3;
		}
		if (max != null && max.Length >= 2)
		{
			max[0] = num2;
			max[1] = num4;
		}
	}

	public void get_cell_bounding_box(uint level_index, uint level, double[] min, double[] max)
	{
		double num = min_x;
		double num2 = max_x;
		double num3 = min_y;
		double num4 = max_y;
		while (level != 0)
		{
			uint num5 = (level_index >> (int)(2 * (level - 1))) & 3;
			double num6 = (num + num2) / 2.0;
			double num7 = (num3 + num4) / 2.0;
			if ((num5 & 1) != 0)
			{
				num = num6;
			}
			else
			{
				num2 = num6;
			}
			if ((num5 & 2) != 0)
			{
				num3 = num7;
			}
			else
			{
				num4 = num7;
			}
			level--;
		}
		if (min != null && min.Length >= 2)
		{
			min[0] = num;
			min[1] = num3;
		}
		if (max != null && max.Length >= 2)
		{
			max[0] = num2;
			max[1] = num4;
		}
	}

	public void get_cell_bounding_box(uint level_index, float[] min, float[] max)
	{
		get_cell_bounding_box(level_index, levels, min, max);
	}

	public void get_cell_bounding_box(uint level_index, double[] min, double[] max)
	{
		get_cell_bounding_box(level_index, levels, min, max);
	}

	public uint get_level(uint cell_index)
	{
		uint num;
		for (num = 0u; cell_index >= level_offset[num + 1]; num++)
		{
		}
		return num;
	}

	public uint get_level_index(uint cell_index, uint level)
	{
		if (sub_level != 0)
		{
			return cell_index - (sub_level_index << (int)(level * 2)) - level_offset[sub_level + level];
		}
		return cell_index - level_offset[level];
	}

	public uint get_level_index(uint cell_index)
	{
		return get_level_index(cell_index, levels);
	}

	public uint get_cell_index(uint level_index, uint level)
	{
		if (sub_level != 0)
		{
			return level_index + (sub_level_index << (int)(level * 2)) + level_offset[sub_level + level];
		}
		return level_index + level_offset[level];
	}

	public uint get_cell_index(uint level_index)
	{
		return get_cell_index(level_index, levels);
	}

	public uint get_max_level_index(uint level)
	{
		return (uint)((1 << (int)level) * (1 << (int)level));
	}

	public uint get_max_level_index()
	{
		return get_max_level_index(levels);
	}

	public uint get_max_cell_index(uint level)
	{
		return level_offset[level + 1] - 1;
	}

	public uint get_max_cell_index()
	{
		return get_max_cell_index(levels);
	}

	public uint[] raster_occupancy(does_cell_exist_proc does_cell_exist, uint level)
	{
		int num = 1 << (int)level;
		uint num2 = (uint)(num * num + 31) / 32u;
		uint[] array;
		try
		{
			array = new uint[num2];
		}
		catch
		{
			return null;
		}
		raster_occupancy(does_cell_exist, array, 0u, 0u, 0u, 0u, level);
		return array;
	}

	public uint[] raster_occupancy(does_cell_exist_proc does_cell_exist)
	{
		return raster_occupancy(does_cell_exist, levels);
	}

	public uint intersect_rectangle(double r_min_x, double r_min_y, double r_max_x, double r_max_y, uint level)
	{
		if (current_cells == null)
		{
			current_cells = new List<int>();
		}
		else
		{
			current_cells.Clear();
		}
		if (r_max_x <= (double)min_x || !(r_min_x <= (double)max_x) || r_max_y <= (double)min_y || !(r_min_y <= (double)max_y))
		{
			return 0u;
		}
		if (adaptive != null)
		{
			intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, min_x, max_x, min_y, max_y, 0u, 0u);
		}
		else
		{
			intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, min_x, max_x, min_y, max_y, level, 0u);
		}
		return (uint)current_cells.Count;
	}

	public uint intersect_tile(float ll_x, float ll_y, float size, uint level)
	{
		if (current_cells == null)
		{
			current_cells = new List<int>();
		}
		else
		{
			current_cells.Clear();
		}
		float num = ll_x + size;
		float num2 = ll_y + size;
		if (num <= min_x || !(ll_x <= max_x) || num2 <= min_y || !(ll_y <= max_y))
		{
			return 0u;
		}
		if (adaptive != null)
		{
			intersect_tile_with_cells_adaptive(ll_x, ll_y, num, num2, min_x, max_x, min_y, max_y, 0u, 0u);
		}
		else
		{
			intersect_tile_with_cells(ll_x, ll_y, num, num2, min_x, max_x, min_y, max_y, level, 0u);
		}
		return (uint)current_cells.Count;
	}

	public uint intersect_circle(double center_x, double center_y, double radius, uint level)
	{
		if (current_cells == null)
		{
			current_cells = new List<int>();
		}
		else
		{
			current_cells.Clear();
		}
		double num = center_x - radius;
		double num2 = center_y - radius;
		double num3 = center_x + radius;
		double num4 = center_y + radius;
		if (num3 <= (double)min_x || !(num <= (double)max_x) || num4 <= (double)min_y || !(num2 <= (double)max_y))
		{
			return 0u;
		}
		if (adaptive != null)
		{
			intersect_circle_with_cells_adaptive(center_x, center_y, radius, num, num2, num3, num4, min_x, max_x, min_y, max_y, 0u, 0u);
		}
		else
		{
			intersect_circle_with_cells(center_x, center_y, radius, num, num2, num3, num4, min_x, max_x, min_y, max_y, level, 0u);
		}
		return (uint)current_cells.Count;
	}

	private void intersect_rectangle_with_cells(double r_min_x, double r_min_y, double r_max_x, double r_max_y, float cell_min_x, float cell_max_x, float cell_min_y, float cell_max_y, uint level, uint level_index)
	{
		if (level != 0)
		{
			level--;
			level_index <<= 2;
			float num = (cell_min_x + cell_max_x) / 2f;
			float num2 = (cell_min_y + cell_max_y) / 2f;
			if (r_max_x <= (double)num)
			{
				if (r_max_y <= (double)num2)
				{
					intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, cell_min_y, num2, level, level_index);
					return;
				}
				if (!(r_min_y < (double)num2))
				{
					intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
					return;
				}
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
			}
			else if (!(r_min_x < (double)num))
			{
				if (r_max_y <= (double)num2)
				{
					intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
					return;
				}
				if (!(r_min_y < (double)num2))
				{
					intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
					return;
				}
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
			else if (r_max_y <= (double)num2)
			{
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
			}
			else if (!(r_min_y < (double)num2))
			{
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
			else
			{
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
				intersect_rectangle_with_cells(r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
		}
		else
		{
			current_cells.Add((int)level_index);
		}
	}

	private void intersect_rectangle_with_cells_adaptive(double r_min_x, double r_min_y, double r_max_x, double r_max_y, float cell_min_x, float cell_max_x, float cell_min_y, float cell_max_y, uint level, uint level_index)
	{
		uint num = get_cell_index(level_index, level);
		uint num2 = num / 32;
		uint num3 = (uint)(1 << (int)(num % 32));
		if (level < levels && (adaptive[num2] & num3) != 0)
		{
			level++;
			level_index <<= 2;
			float num4 = (cell_min_x + cell_max_x) / 2f;
			float num5 = (cell_min_y + cell_max_y) / 2f;
			if (r_max_x <= (double)num4)
			{
				if (r_max_y <= (double)num5)
				{
					intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
					return;
				}
				if (!(r_min_y < (double)num5))
				{
					intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
					return;
				}
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
			}
			else if (!(r_min_x < (double)num4))
			{
				if (r_max_y <= (double)num5)
				{
					intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
					return;
				}
				if (!(r_min_y < (double)num5))
				{
					intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
					return;
				}
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
			else if (r_max_y <= (double)num5)
			{
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
			}
			else if (!(r_min_y < (double)num5))
			{
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
			else
			{
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
				intersect_rectangle_with_cells_adaptive(r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
		}
		else
		{
			current_cells.Add((int)num);
		}
	}

	private void intersect_tile_with_cells(float ll_x, float ll_y, float ur_x, float ur_y, float cell_min_x, float cell_max_x, float cell_min_y, float cell_max_y, uint level, uint level_index)
	{
		if (level != 0)
		{
			level--;
			level_index <<= 2;
			float num = (cell_min_x + cell_max_x) / 2f;
			float num2 = (cell_min_y + cell_max_y) / 2f;
			if (ur_x <= num)
			{
				if (ur_y <= num2)
				{
					intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, cell_min_x, num, cell_min_y, num2, level, level_index);
					return;
				}
				if (!(ll_y < num2))
				{
					intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
					return;
				}
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
			}
			else if (!(ll_x < num))
			{
				if (ur_y <= num2)
				{
					intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
					return;
				}
				if (!(ll_y < num2))
				{
					intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
					return;
				}
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
			else if (ur_y <= num2)
			{
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
			}
			else if (!(ll_y < num2))
			{
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
			else
			{
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
				intersect_tile_with_cells(ll_x, ll_y, ur_x, ur_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
		}
		else
		{
			current_cells.Add((int)level_index);
		}
	}

	private void intersect_tile_with_cells_adaptive(float ll_x, float ll_y, float ur_x, float ur_y, float cell_min_x, float cell_max_x, float cell_min_y, float cell_max_y, uint level, uint level_index)
	{
		uint num = get_cell_index(level_index, level);
		uint num2 = num / 32;
		uint num3 = (uint)(1 << (int)(num % 32));
		if (level < levels && (adaptive[num2] & num3) != 0)
		{
			level++;
			level_index <<= 2;
			float num4 = (cell_min_x + cell_max_x) / 2f;
			float num5 = (cell_min_y + cell_max_y) / 2f;
			if (ur_x <= num4)
			{
				if (ur_y <= num5)
				{
					intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
					return;
				}
				if (!(ll_y < num5))
				{
					intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
					return;
				}
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
			}
			else if (!(ll_x < num4))
			{
				if (ur_y <= num5)
				{
					intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
					return;
				}
				if (!(ll_y < num5))
				{
					intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
					return;
				}
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
			else if (ur_y <= num5)
			{
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
			}
			else if (!(ll_y < num5))
			{
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
			else
			{
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
				intersect_tile_with_cells_adaptive(ll_x, ll_y, ur_x, ur_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
		}
		else
		{
			current_cells.Add((int)num);
		}
	}

	private void intersect_circle_with_cells(double center_x, double center_y, double radius, double r_min_x, double r_min_y, double r_max_x, double r_max_y, float cell_min_x, float cell_max_x, float cell_min_y, float cell_max_y, uint level, uint level_index)
	{
		if (level != 0)
		{
			level--;
			level_index <<= 2;
			float num = (cell_min_x + cell_max_x) / 2f;
			float num2 = (cell_min_y + cell_max_y) / 2f;
			if (r_max_x <= (double)num)
			{
				if (r_max_y <= (double)num2)
				{
					intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, cell_min_y, num2, level, level_index);
					return;
				}
				if (!(r_min_y < (double)num2))
				{
					intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
					return;
				}
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
			}
			else if (!(r_min_x < (double)num))
			{
				if (r_max_y <= (double)num2)
				{
					intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
					return;
				}
				if (!(r_min_y < (double)num2))
				{
					intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
					return;
				}
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
			else if (r_max_y <= (double)num2)
			{
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
			}
			else if (!(r_min_y < (double)num2))
			{
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
			else
			{
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, cell_min_y, num2, level, level_index);
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, cell_min_y, num2, level, level_index | 1);
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num, num2, cell_max_y, level, level_index | 2);
				intersect_circle_with_cells(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num, cell_max_x, num2, cell_max_y, level, level_index | 3);
			}
		}
		else if (intersect_circle_with_rectangle(center_x, center_y, radius, cell_min_x, cell_max_x, cell_min_y, cell_max_y))
		{
			current_cells.Add((int)level_index);
		}
	}

	private void intersect_circle_with_cells_adaptive(double center_x, double center_y, double radius, double r_min_x, double r_min_y, double r_max_x, double r_max_y, float cell_min_x, float cell_max_x, float cell_min_y, float cell_max_y, uint level, uint level_index)
	{
		uint num = get_cell_index(level_index, level);
		uint num2 = num / 32;
		uint num3 = (uint)(1 << (int)(num % 32));
		if (level < levels && (adaptive[num2] & num3) != 0)
		{
			level++;
			level_index <<= 2;
			float num4 = (cell_min_x + cell_max_x) / 2f;
			float num5 = (cell_min_y + cell_max_y) / 2f;
			if (r_max_x <= (double)num4)
			{
				if (r_max_y <= (double)num5)
				{
					intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
					return;
				}
				if (!(r_min_y < (double)num5))
				{
					intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
					return;
				}
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
			}
			else if (!(r_min_x < (double)num4))
			{
				if (r_max_y <= (double)num5)
				{
					intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
					return;
				}
				if (!(r_min_y < (double)num5))
				{
					intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
					return;
				}
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
			else if (r_max_y <= (double)num5)
			{
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
			}
			else if (!(r_min_y < (double)num5))
			{
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
			else
			{
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, cell_min_y, num5, level, level_index);
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, cell_min_y, num5, level, level_index | 1);
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, cell_min_x, num4, num5, cell_max_y, level, level_index | 2);
				intersect_circle_with_cells_adaptive(center_x, center_y, radius, r_min_x, r_min_y, r_max_x, r_max_y, num4, cell_max_x, num5, cell_max_y, level, level_index | 3);
			}
		}
		else if (intersect_circle_with_rectangle(center_x, center_y, radius, cell_min_x, cell_max_x, cell_min_y, cell_max_y))
		{
			current_cells.Add((int)num);
		}
	}

	private bool intersect_circle_with_rectangle(double center_x, double center_y, double radius, float r_min_x, float r_max_x, float r_min_y, float r_max_y)
	{
		double num = radius * radius;
		if ((double)r_max_x < center_x)
		{
			double num2 = center_x - (double)r_max_x;
			if ((double)r_max_y < center_y)
			{
				double num3 = center_y - (double)r_max_y;
				return num2 * num2 + num3 * num3 < num;
			}
			if ((double)r_min_y > center_y)
			{
				double num4 = 0.0 - center_y + (double)r_min_y;
				return num2 * num2 + num4 * num4 < num;
			}
			return num2 < radius;
		}
		if ((double)r_min_x > center_x)
		{
			double num5 = 0.0 - center_x + (double)r_min_x;
			if ((double)r_max_y < center_y)
			{
				double num6 = center_y - (double)r_max_y;
				return num5 * num5 + num6 * num6 < num;
			}
			if ((double)r_min_y > center_y)
			{
				double num7 = 0.0 - center_y + (double)r_min_y;
				return num5 * num5 + num7 * num7 < num;
			}
			return num5 < radius;
		}
		if ((double)r_max_y < center_y)
		{
			return center_y - (double)r_max_y < radius;
		}
		if ((double)r_min_y > center_y)
		{
			return 0.0 - center_y + (double)r_min_y < radius;
		}
		return true;
	}

	private void raster_occupancy(does_cell_exist_proc does_cell_exist, uint[] data, uint min_x, uint min_y, uint level_index, uint level, uint stop_level)
	{
		uint num = get_cell_index(level_index, level);
		uint num2 = num / 32;
		uint num3 = (uint)(1 << (int)(num % 32));
		if ((adaptive[num2] & num3) != 0)
		{
			if (level < stop_level)
			{
				level_index <<= 2;
				level++;
				uint num4 = (uint)(1 << (int)(stop_level - level));
				raster_occupancy(does_cell_exist, data, min_x, min_y, level_index, level, stop_level);
				raster_occupancy(does_cell_exist, data, min_x + num4, min_y, level_index + 1, level, stop_level);
				raster_occupancy(does_cell_exist, data, min_x, min_y + num4, level_index + 2, level, stop_level);
				raster_occupancy(does_cell_exist, data, min_x + num4, min_y + num4, level_index + 3, level, stop_level);
				return;
			}
			uint num5 = (uint)(1 << (int)stop_level);
			uint num6 = (uint)(1 << (int)(stop_level - level));
			uint num7 = min_y + num6;
			for (uint num8 = min_y; num8 < num7; num8++)
			{
				uint num9 = num8 * num5 + min_x;
				for (uint num10 = 0u; num10 < num6; num10++)
				{
					data[num9 / 32] |= (uint)(1 << (int)(num9 % 32));
					num9++;
				}
			}
		}
		else
		{
			if (!does_cell_exist((int)num))
			{
				return;
			}
			uint num11 = (uint)(1 << (int)stop_level);
			uint num12 = (uint)(1 << (int)(stop_level - level));
			uint num13 = min_y + num12;
			for (uint num14 = min_y; num14 < num13; num14++)
			{
				uint num15 = num14 * num11 + min_x;
				for (uint num16 = 0u; num16 < num12; num16++)
				{
					data[num15 / 32] |= (uint)(1 << (int)(num15 % 32));
					num15++;
				}
			}
		}
	}
}
internal struct LASquantizer
{
	public double x_scale_factor;

	public double y_scale_factor;

	public double z_scale_factor;

	public double x_offset;

	public double y_offset;

	public double z_offset;

	public double get_x(int X)
	{
		return x_scale_factor * (double)X + x_offset;
	}

	public double get_y(int Y)
	{
		return y_scale_factor * (double)Y + y_offset;
	}

	public double get_z(int Z)
	{
		return z_scale_factor * (double)Z + z_offset;
	}

	public int get_X(double x)
	{
		if (x >= x_offset)
		{
			return (int)((x - x_offset) / x_scale_factor + 0.5);
		}
		return (int)((x - x_offset) / x_scale_factor - 0.5);
	}

	public int get_Y(double y)
	{
		if (y >= y_offset)
		{
			return (int)((y - y_offset) / y_scale_factor + 0.5);
		}
		return (int)((y - y_offset) / y_scale_factor - 0.5);
	}

	public int get_Z(double z)
	{
		if (z >= z_offset)
		{
			return (int)((z - z_offset) / z_scale_factor + 0.5);
		}
		return (int)((z - z_offset) / z_scale_factor - 0.5);
	}

	private LASquantizer(double factor = 0.01)
	{
		x_scale_factor = factor;
		y_scale_factor = factor;
		z_scale_factor = factor;
		x_offset = 0.0;
		y_offset = 0.0;
		z_offset = 0.0;
	}
}
public abstract class LASreadItem
{
	public abstract void read(laszip_point item, ref uint context);
}
internal abstract class LASreadItemCompressed : LASreadItem
{
	public virtual bool chunk_sizes()
	{
		return false;
	}

	public abstract bool init(laszip_point item, ref uint context);
}
internal class LASreadItemCompressed_BYTE14_v3 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private MemoryStream[] instream_Bytes;

	private ArithmeticDecoder[] dec_Bytes;

	private readonly int[] num_bytes_Bytes;

	private readonly bool[] changed_Bytes;

	private readonly bool[] requested_Bytes;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextBYTE14[] contexts = new LAScontextBYTE14[4]
	{
		new LAScontextBYTE14(),
		new LAScontextBYTE14(),
		new LAScontextBYTE14(),
		new LAScontextBYTE14()
	};

	private uint number;

	public LASreadItemCompressed_BYTE14_v3(ArithmeticDecoder dec, uint number, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		this.number = number;
		instream_Bytes = null;
		dec_Bytes = null;
		num_bytes_Bytes = new int[number];
		changed_Bytes = new bool[number];
		requested_Bytes = new bool[number];
		for (uint num = 0u; num < number; num++)
		{
			num_bytes_Bytes[num] = 0;
			changed_Bytes[num] = false;
			requested_Bytes[num] = decompress_selective.HasFlag((LASZIP_DECOMPRESS_SELECTIVE)(65536 << (int)num));
		}
		bytes = null;
		num_bytes_allocated = 0;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_bytes = null;
		}
		current_context = 0u;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		for (uint num = 0u; num < number; num++)
		{
			if (!byteStreamIn.get32bits(out num_bytes_Bytes[num]))
			{
				throw new EndOfStreamException();
			}
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_Bytes == null)
		{
			instream_Bytes = new MemoryStream[number];
			dec_Bytes = new ArithmeticDecoder[number];
			for (uint num = 0u; num < number; num++)
			{
				dec_Bytes[num] = new ArithmeticDecoder();
			}
		}
		int num2 = 0;
		for (uint num3 = 0u; num3 < number; num3++)
		{
			if (requested_Bytes[num3])
			{
				num2 += num_bytes_Bytes[num3];
			}
		}
		if (num2 > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num2];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num2;
		}
		num2 = 0;
		for (uint num4 = 0u; num4 < number; num4++)
		{
			if (requested_Bytes[num4])
			{
				if (num_bytes_Bytes[num4] != 0)
				{
					if (!byteStreamIn.getBytes(bytes, num2, num_bytes_Bytes[num4]))
					{
						throw new EndOfStreamException();
					}
					instream_Bytes[num4] = new MemoryStream(bytes, num2, num_bytes_Bytes[num4]);
					dec_Bytes[num4].init(instream_Bytes[num4]);
					num2 += num_bytes_Bytes[num4];
					changed_Bytes[num4] = true;
				}
				else
				{
					dec_Bytes[num4].init(null, really_init: false);
					changed_Bytes[num4] = false;
				}
			}
			else
			{
				if (num_bytes_Bytes[num4] != 0)
				{
					byteStreamIn.Seek(num_bytes_Bytes[num4], SeekOrigin.Current);
				}
				changed_Bytes[num4] = false;
			}
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndDecompressors(current_context, item.extra_bytes);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		byte[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndDecompressors(current_context, last_item);
				last_item = contexts[current_context].last_item;
			}
		}
		for (uint num = 0u; num < number; num++)
		{
			if (changed_Bytes[num])
			{
				int n = (int)(last_item[num] + dec_Bytes[num].decodeSymbol(contexts[current_context].m_bytes[num]));
				item.extra_bytes[num] = (byte)MyDefs.U8_FOLD(n);
				last_item[num] = item.extra_bytes[num];
			}
			else
			{
				item.extra_bytes[num] = last_item[num];
			}
		}
	}

	private bool createAndInitModelsAndDecompressors(uint context, byte[] item)
	{
		if (contexts[context].m_bytes == null)
		{
			contexts[context].m_bytes = new ArithmeticModel[number];
			for (uint num = 0u; num < number; num++)
			{
				contexts[context].m_bytes[num] = dec_Bytes[num].createSymbolModel(256u);
				dec_Bytes[num].initSymbolModel(contexts[context].m_bytes[num]);
			}
			contexts[context].last_item = new byte[number];
		}
		for (uint num2 = 0u; num2 < number; num2++)
		{
			dec_Bytes[num2].initSymbolModel(contexts[context].m_bytes[num2]);
		}
		item.CopyTo(contexts[context].last_item, 0);
		contexts[context].unused = false;
		return true;
	}
}
internal class LASreadItemCompressed_BYTE14_v4 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private MemoryStream[] instream_Bytes;

	private ArithmeticDecoder[] dec_Bytes;

	private readonly int[] num_bytes_Bytes;

	private readonly bool[] changed_Bytes;

	private readonly bool[] requested_Bytes;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextBYTE14[] contexts = new LAScontextBYTE14[4]
	{
		new LAScontextBYTE14(),
		new LAScontextBYTE14(),
		new LAScontextBYTE14(),
		new LAScontextBYTE14()
	};

	private uint number;

	public LASreadItemCompressed_BYTE14_v4(ArithmeticDecoder dec, uint number, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		this.number = number;
		instream_Bytes = null;
		dec_Bytes = null;
		num_bytes_Bytes = new int[number];
		changed_Bytes = new bool[number];
		requested_Bytes = new bool[number];
		for (uint num = 0u; num < number; num++)
		{
			num_bytes_Bytes[num] = 0;
			changed_Bytes[num] = false;
			requested_Bytes[num] = decompress_selective.HasFlag((LASZIP_DECOMPRESS_SELECTIVE)(65536 << (int)num));
		}
		bytes = null;
		num_bytes_allocated = 0;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_bytes = null;
		}
		current_context = 0u;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		for (uint num = 0u; num < number; num++)
		{
			if (!byteStreamIn.get32bits(out num_bytes_Bytes[num]))
			{
				throw new EndOfStreamException();
			}
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_Bytes == null)
		{
			instream_Bytes = new MemoryStream[number];
			dec_Bytes = new ArithmeticDecoder[number];
			for (uint num = 0u; num < number; num++)
			{
				dec_Bytes[num] = new ArithmeticDecoder();
			}
		}
		int num2 = 0;
		for (uint num3 = 0u; num3 < number; num3++)
		{
			if (requested_Bytes[num3])
			{
				num2 += num_bytes_Bytes[num3];
			}
		}
		if (num2 > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num2];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num2;
		}
		num2 = 0;
		for (uint num4 = 0u; num4 < number; num4++)
		{
			if (requested_Bytes[num4])
			{
				if (num_bytes_Bytes[num4] != 0)
				{
					if (!byteStreamIn.getBytes(bytes, num2, num_bytes_Bytes[num4]))
					{
						throw new EndOfStreamException();
					}
					instream_Bytes[num4] = new MemoryStream(bytes, num2, num_bytes_Bytes[num4]);
					dec_Bytes[num4].init(instream_Bytes[num4]);
					num2 += num_bytes_Bytes[num4];
					changed_Bytes[num4] = true;
				}
				else
				{
					dec_Bytes[num4].init(null, really_init: false);
					changed_Bytes[num4] = false;
				}
			}
			else
			{
				if (num_bytes_Bytes[num4] != 0)
				{
					byteStreamIn.Seek(num_bytes_Bytes[num4], SeekOrigin.Current);
				}
				changed_Bytes[num4] = false;
			}
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndDecompressors(current_context, item.extra_bytes);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		byte[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndDecompressors(current_context, last_item);
			}
			last_item = contexts[current_context].last_item;
		}
		for (uint num = 0u; num < number; num++)
		{
			if (changed_Bytes[num])
			{
				int n = (int)(last_item[num] + dec_Bytes[num].decodeSymbol(contexts[current_context].m_bytes[num]));
				item.extra_bytes[num] = (byte)MyDefs.U8_FOLD(n);
				last_item[num] = item.extra_bytes[num];
			}
			else
			{
				item.extra_bytes[num] = last_item[num];
			}
		}
	}

	private bool createAndInitModelsAndDecompressors(uint context, byte[] item)
	{
		if (contexts[context].m_bytes == null)
		{
			contexts[context].m_bytes = new ArithmeticModel[number];
			for (uint num = 0u; num < number; num++)
			{
				contexts[context].m_bytes[num] = dec_Bytes[num].createSymbolModel(256u);
				dec_Bytes[num].initSymbolModel(contexts[context].m_bytes[num]);
			}
			contexts[context].last_item = new byte[number];
		}
		for (uint num2 = 0u; num2 < number; num2++)
		{
			dec_Bytes[num2].initSymbolModel(contexts[context].m_bytes[num2]);
		}
		item.CopyTo(contexts[context].last_item, 0);
		contexts[context].unused = false;
		return true;
	}
}
internal class LASreadItemCompressed_BYTE_v1 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private uint number;

	private readonly byte[] last_item;

	private IntegerCompressor ic_byte;

	public LASreadItemCompressed_BYTE_v1(ArithmeticDecoder dec, uint number)
	{
		this.dec = dec;
		this.number = number;
		ic_byte = new IntegerCompressor(dec, 8u, number);
		last_item = new byte[number];
	}

	public override bool init(laszip_point item, ref uint context)
	{
		ic_byte.initDecompressor();
		Buffer.BlockCopy(item.extra_bytes, 0, last_item, 0, (int)number);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		for (uint num = 0u; num < number; num++)
		{
			last_item[num] = (item.extra_bytes[num] = (byte)ic_byte.decompress(last_item[num], num));
		}
	}
}
internal class LASreadItemCompressed_BYTE_v2 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private uint number;

	private readonly byte[] last_item;

	private readonly ArithmeticModel[] m_byte;

	public LASreadItemCompressed_BYTE_v2(ArithmeticDecoder dec, uint number)
	{
		this.dec = dec;
		this.number = number;
		m_byte = new ArithmeticModel[number];
		for (uint num = 0u; num < number; num++)
		{
			m_byte[num] = dec.createSymbolModel(256u);
		}
		last_item = new byte[number];
	}

	public override bool init(laszip_point item, ref uint context)
	{
		for (uint num = 0u; num < number; num++)
		{
			dec.initSymbolModel(m_byte[num]);
		}
		Buffer.BlockCopy(item.extra_bytes, 0, last_item, 0, (int)number);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		for (uint num = 0u; num < number; num++)
		{
			int n = (int)(last_item[num] + dec.decodeSymbol(m_byte[num]));
			item.extra_bytes[num] = (byte)MyDefs.U8_FOLD(n);
		}
		Buffer.BlockCopy(item.extra_bytes, 0, last_item, 0, (int)number);
	}
}
internal class LASreadItemCompressed_GPSTIME11_v1 : LASreadItemCompressed
{
	private const int LASZIP_GPSTIME_MULTIMAX = 512;

	private ArithmeticDecoder dec;

	private U64I64F64 last_gpstime;

	private ArithmeticModel m_gpstime_multi;

	private ArithmeticModel m_gpstime_0diff;

	private IntegerCompressor ic_gpstime;

	private int multi_extreme_counter;

	private int last_gpstime_diff;

	public LASreadItemCompressed_GPSTIME11_v1(ArithmeticDecoder dec)
	{
		this.dec = dec;
		m_gpstime_multi = dec.createSymbolModel(512u);
		m_gpstime_0diff = dec.createSymbolModel(3u);
		ic_gpstime = new IntegerCompressor(dec, 32u, 6u);
	}

	public override bool init(laszip_point item, ref uint context)
	{
		last_gpstime_diff = 0;
		multi_extreme_counter = 0;
		dec.initSymbolModel(m_gpstime_multi);
		dec.initSymbolModel(m_gpstime_0diff);
		ic_gpstime.initDecompressor();
		last_gpstime.f64 = item.gps_time;
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		if (last_gpstime_diff == 0)
		{
			switch ((int)dec.decodeSymbol(m_gpstime_0diff))
			{
			case 1:
				last_gpstime_diff = ic_gpstime.decompress(0);
				last_gpstime.i64 += last_gpstime_diff;
				break;
			case 2:
				last_gpstime.u64 = dec.readInt64();
				break;
			}
		}
		else
		{
			int num = (int)dec.decodeSymbol(m_gpstime_multi);
			if (num < 510)
			{
				int num2;
				if (num == 1)
				{
					num2 = (last_gpstime_diff = ic_gpstime.decompress(last_gpstime_diff, 1u));
					multi_extreme_counter = 0;
				}
				else if (num == 0)
				{
					num2 = ic_gpstime.decompress(last_gpstime_diff / 4, 2u);
					multi_extreme_counter++;
					if (multi_extreme_counter > 3)
					{
						last_gpstime_diff = num2;
						multi_extreme_counter = 0;
					}
				}
				else if (num < 10)
				{
					num2 = ic_gpstime.decompress(num * last_gpstime_diff, 3u);
				}
				else if (num < 50)
				{
					num2 = ic_gpstime.decompress(num * last_gpstime_diff, 4u);
				}
				else
				{
					num2 = ic_gpstime.decompress(num * last_gpstime_diff, 5u);
					if (num == 509)
					{
						multi_extreme_counter++;
						if (multi_extreme_counter > 3)
						{
							last_gpstime_diff = num2;
							multi_extreme_counter = 0;
						}
					}
				}
				last_gpstime.i64 += num2;
			}
			else if (num < 511)
			{
				last_gpstime.u64 = dec.readInt64();
			}
		}
		item.gps_time = last_gpstime.f64;
	}
}
internal class LASreadItemCompressed_GPSTIME11_v2 : LASreadItemCompressed
{
	private const int LASZIP_GPSTIME_MULTI = 500;

	private const int LASZIP_GPSTIME_MULTI_MINUS = -10;

	private const int LASZIP_GPSTIME_MULTI_UNCHANGED = 511;

	private const int LASZIP_GPSTIME_MULTI_CODE_FULL = 512;

	private const int LASZIP_GPSTIME_MULTI_TOTAL = 516;

	private ArithmeticDecoder dec;

	private uint last;

	private uint next;

	private readonly U64I64F64[] last_gpstime = new U64I64F64[4];

	private readonly int[] last_gpstime_diff = new int[4];

	private readonly int[] multi_extreme_counter = new int[4];

	private ArithmeticModel m_gpstime_multi;

	private ArithmeticModel m_gpstime_0diff;

	private IntegerCompressor ic_gpstime;

	public LASreadItemCompressed_GPSTIME11_v2(ArithmeticDecoder dec)
	{
		this.dec = dec;
		m_gpstime_multi = dec.createSymbolModel(516u);
		m_gpstime_0diff = dec.createSymbolModel(6u);
		ic_gpstime = new IntegerCompressor(dec, 32u, 9u);
	}

	public override bool init(laszip_point item, ref uint context)
	{
		last = 0u;
		next = 0u;
		last_gpstime_diff[0] = 0;
		last_gpstime_diff[1] = 0;
		last_gpstime_diff[2] = 0;
		last_gpstime_diff[3] = 0;
		multi_extreme_counter[0] = 0;
		multi_extreme_counter[1] = 0;
		multi_extreme_counter[2] = 0;
		multi_extreme_counter[3] = 0;
		dec.initSymbolModel(m_gpstime_multi);
		dec.initSymbolModel(m_gpstime_0diff);
		ic_gpstime.initDecompressor();
		last_gpstime[0].f64 = item.gps_time;
		last_gpstime[1].u64 = 0uL;
		last_gpstime[2].u64 = 0uL;
		last_gpstime[3].u64 = 0uL;
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		if (last_gpstime_diff[last] == 0)
		{
			int num = (int)dec.decodeSymbol(m_gpstime_0diff);
			if (num == 1)
			{
				last_gpstime_diff[last] = ic_gpstime.decompress(0);
				last_gpstime[last].i64 += last_gpstime_diff[last];
				multi_extreme_counter[last] = 0;
			}
			else if (num == 2)
			{
				next = (next + 1) & 3;
				last_gpstime[next].u64 = (ulong)ic_gpstime.decompress((int)(last_gpstime[last].u64 >> 32), 8u);
				last_gpstime[next].u64 = last_gpstime[next].u64 << 32;
				last_gpstime[next].u64 |= dec.readInt();
				last = next;
				last_gpstime_diff[last] = 0;
				multi_extreme_counter[last] = 0;
			}
			else if (num > 2)
			{
				last = (uint)((int)(last + num - 2) & 3);
				read(item, ref context);
			}
		}
		else
		{
			int num2 = (int)dec.decodeSymbol(m_gpstime_multi);
			if (num2 == 1)
			{
				last_gpstime[last].i64 += ic_gpstime.decompress(last_gpstime_diff[last], 1u);
				multi_extreme_counter[last] = 0;
			}
			else if (num2 < 511)
			{
				int num3;
				if (num2 == 0)
				{
					num3 = ic_gpstime.decompress(0, 7u);
					multi_extreme_counter[last]++;
					if (multi_extreme_counter[last] > 3)
					{
						last_gpstime_diff[last] = num3;
						multi_extreme_counter[last] = 0;
					}
				}
				else if (num2 < 500)
				{
					num3 = ((num2 >= 10) ? ic_gpstime.decompress(num2 * last_gpstime_diff[last], 3u) : ic_gpstime.decompress(num2 * last_gpstime_diff[last], 2u));
				}
				else if (num2 == 500)
				{
					num3 = ic_gpstime.decompress(500 * last_gpstime_diff[last], 4u);
					multi_extreme_counter[last]++;
					if (multi_extreme_counter[last] > 3)
					{
						last_gpstime_diff[last] = num3;
						multi_extreme_counter[last] = 0;
					}
				}
				else
				{
					num2 = 500 - num2;
					if (num2 > -10)
					{
						num3 = ic_gpstime.decompress(num2 * last_gpstime_diff[last], 5u);
					}
					else
					{
						num3 = ic_gpstime.decompress(-10 * last_gpstime_diff[last], 6u);
						multi_extreme_counter[last]++;
						if (multi_extreme_counter[last] > 3)
						{
							last_gpstime_diff[last] = num3;
							multi_extreme_counter[last] = 0;
						}
					}
				}
				last_gpstime[last].i64 += num3;
			}
			else if (num2 == 512)
			{
				next = (next + 1) & 3;
				last_gpstime[next].u64 = (ulong)ic_gpstime.decompress((int)(last_gpstime[last].u64 >> 32), 8u);
				last_gpstime[next].u64 = last_gpstime[next].u64 << 32;
				last_gpstime[next].u64 |= dec.readInt();
				last = next;
				last_gpstime_diff[last] = 0;
				multi_extreme_counter[last] = 0;
			}
			else if (num2 >= 512)
			{
				last = (uint)((int)(last + num2 - 512) & 3);
				read(item, ref context);
			}
		}
		item.gps_time = last_gpstime[last].f64;
	}
}
internal class LASreadItemCompressed_POINT10_v1 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private LASpoint10 last;

	private readonly int[] last_x_diff = new int[3];

	private readonly int[] last_y_diff = new int[3];

	private int last_incr;

	private IntegerCompressor ic_dx;

	private IntegerCompressor ic_dy;

	private IntegerCompressor ic_z;

	private IntegerCompressor ic_intensity;

	private IntegerCompressor ic_scan_angle_rank;

	private IntegerCompressor ic_point_source_ID;

	private ArithmeticModel m_changed_values;

	private readonly ArithmeticModel[] m_bit_byte = new ArithmeticModel[256];

	private readonly ArithmeticModel[] m_classification = new ArithmeticModel[256];

	private readonly ArithmeticModel[] m_user_data = new ArithmeticModel[256];

	public LASreadItemCompressed_POINT10_v1(ArithmeticDecoder dec)
	{
		this.dec = dec;
		ic_dx = new IntegerCompressor(dec, 32u);
		ic_dy = new IntegerCompressor(dec, 32u, 20u);
		ic_z = new IntegerCompressor(dec, 32u, 20u);
		ic_intensity = new IntegerCompressor(dec);
		ic_scan_angle_rank = new IntegerCompressor(dec, 8u, 2u);
		ic_point_source_ID = new IntegerCompressor(dec);
		m_changed_values = dec.createSymbolModel(64u);
		for (int i = 0; i < 256; i++)
		{
			m_bit_byte[i] = null;
			m_classification[i] = null;
			m_user_data[i] = null;
		}
	}

	public override bool init(laszip_point item, ref uint context)
	{
		last_x_diff[0] = (last_x_diff[1] = (last_x_diff[2] = 0));
		last_y_diff[0] = (last_y_diff[1] = (last_y_diff[2] = 0));
		last_incr = 0;
		ic_dx.initDecompressor();
		ic_dy.initDecompressor();
		ic_z.initDecompressor();
		ic_intensity.initDecompressor();
		ic_scan_angle_rank.initDecompressor();
		ic_point_source_ID.initDecompressor();
		dec.initSymbolModel(m_changed_values);
		for (int i = 0; i < 256; i++)
		{
			if (m_bit_byte[i] != null)
			{
				dec.initSymbolModel(m_bit_byte[i]);
			}
			if (m_classification[i] != null)
			{
				dec.initSymbolModel(m_classification[i]);
			}
			if (m_user_data[i] != null)
			{
				dec.initSymbolModel(m_user_data[i]);
			}
		}
		last.X = item.X;
		last.Y = item.Y;
		last.Z = item.Z;
		last.intensity = item.intensity;
		last.flags = item.flags;
		last.classification_and_classification_flags = item.classification_and_classification_flags;
		last.scan_angle_rank = item.scan_angle_rank;
		last.user_data = item.user_data;
		last.point_source_ID = item.point_source_ID;
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		int pred = ((last_x_diff[0] < last_x_diff[1]) ? ((last_x_diff[1] < last_x_diff[2]) ? last_x_diff[1] : ((last_x_diff[0] >= last_x_diff[2]) ? last_x_diff[0] : last_x_diff[2])) : ((last_x_diff[0] < last_x_diff[2]) ? last_x_diff[0] : ((last_x_diff[1] >= last_x_diff[2]) ? last_x_diff[1] : last_x_diff[2])));
		int pred2 = ((last_y_diff[0] < last_y_diff[1]) ? ((last_y_diff[1] < last_y_diff[2]) ? last_y_diff[1] : ((last_y_diff[0] >= last_y_diff[2]) ? last_y_diff[0] : last_y_diff[2])) : ((last_y_diff[0] < last_y_diff[2]) ? last_y_diff[0] : ((last_y_diff[1] >= last_y_diff[2]) ? last_y_diff[1] : last_y_diff[2])));
		int num = ic_dx.decompress(pred);
		last.X += num;
		uint k = ic_dx.getK();
		int num2 = ic_dy.decompress(pred2, (k < 19) ? k : 19u);
		last.Y += num2;
		k = (k + ic_dy.getK()) / 2;
		last.Z = ic_z.decompress(last.Z, (k < 19) ? k : 19u);
		uint num3 = dec.decodeSymbol(m_changed_values);
		if (num3 != 0)
		{
			if ((num3 & 0x20) != 0)
			{
				last.intensity = (ushort)ic_intensity.decompress(last.intensity);
			}
			if ((num3 & 0x10) != 0)
			{
				if (m_bit_byte[last.flags] == null)
				{
					m_bit_byte[last.flags] = dec.createSymbolModel(256u);
					dec.initSymbolModel(m_bit_byte[last.flags]);
				}
				last.flags = (byte)dec.decodeSymbol(m_bit_byte[last.flags]);
			}
			if ((num3 & 8) != 0)
			{
				if (m_classification[last.classification_and_classification_flags] == null)
				{
					m_classification[last.classification_and_classification_flags] = dec.createSymbolModel(256u);
					dec.initSymbolModel(m_classification[last.classification_and_classification_flags]);
				}
				last.classification_and_classification_flags = (byte)dec.decodeSymbol(m_classification[last.classification_and_classification_flags]);
			}
			if ((num3 & 4) != 0)
			{
				last.scan_angle_rank = (sbyte)(byte)ic_scan_angle_rank.decompress((byte)last.scan_angle_rank, (k < 3) ? 1u : 0u);
			}
			if ((num3 & 2) != 0)
			{
				if (m_user_data[last.user_data] == null)
				{
					m_user_data[last.user_data] = dec.createSymbolModel(256u);
					dec.initSymbolModel(m_user_data[last.user_data]);
				}
				last.user_data = (byte)dec.decodeSymbol(m_user_data[last.user_data]);
			}
			if ((num3 & 1) != 0)
			{
				last.point_source_ID = (ushort)ic_point_source_ID.decompress(last.point_source_ID);
			}
		}
		last_x_diff[last_incr] = num;
		last_y_diff[last_incr] = num2;
		last_incr++;
		if (last_incr > 2)
		{
			last_incr = 0;
		}
		item.X = last.X;
		item.Y = last.Y;
		item.Z = last.Z;
		item.intensity = last.intensity;
		item.flags = last.flags;
		item.classification_and_classification_flags = last.classification_and_classification_flags;
		item.scan_angle_rank = last.scan_angle_rank;
		item.user_data = last.user_data;
		item.point_source_ID = last.point_source_ID;
	}
}
internal class LASreadItemCompressed_POINT10_v2 : LASreadItemCompressed
{
	private readonly ArithmeticDecoder dec;

	private LASpoint10 last;

	private readonly ushort[] last_intensity = new ushort[16];

	private readonly StreamingMedian5[] last_x_diff_median5 = new StreamingMedian5[16];

	private readonly StreamingMedian5[] last_y_diff_median5 = new StreamingMedian5[16];

	private readonly int[] last_height = new int[8];

	private readonly IntegerCompressor ic_dx;

	private readonly IntegerCompressor ic_dy;

	private readonly IntegerCompressor ic_z;

	private readonly IntegerCompressor ic_intensity;

	private readonly IntegerCompressor ic_point_source_ID;

	private readonly ArithmeticModel m_changed_values;

	private readonly ArithmeticModel[] m_scan_angle_rank = new ArithmeticModel[2];

	private readonly ArithmeticModel[] m_bit_byte = new ArithmeticModel[256];

	private readonly ArithmeticModel[] m_classification = new ArithmeticModel[256];

	private readonly ArithmeticModel[] m_user_data = new ArithmeticModel[256];

	public LASreadItemCompressed_POINT10_v2(ArithmeticDecoder dec)
	{
		this.dec = dec;
		ic_dx = new IntegerCompressor(dec, 32u, 2u);
		ic_dy = new IntegerCompressor(dec, 32u, 22u);
		ic_z = new IntegerCompressor(dec, 32u, 20u);
		ic_intensity = new IntegerCompressor(dec, 16u, 4u);
		m_scan_angle_rank[0] = dec.createSymbolModel(256u);
		m_scan_angle_rank[1] = dec.createSymbolModel(256u);
		ic_point_source_ID = new IntegerCompressor(dec);
		m_changed_values = dec.createSymbolModel(64u);
		for (int i = 0; i < 256; i++)
		{
			m_bit_byte[i] = null;
			m_classification[i] = null;
			m_user_data[i] = null;
		}
	}

	public override bool init(laszip_point item, ref uint context)
	{
		for (int i = 0; i < 16; i++)
		{
			last_x_diff_median5[i].init();
			last_y_diff_median5[i].init();
			last_intensity[i] = 0;
			last_height[i / 2] = 0;
		}
		ic_dx.initDecompressor();
		ic_dy.initDecompressor();
		ic_z.initDecompressor();
		ic_intensity.initDecompressor();
		dec.initSymbolModel(m_scan_angle_rank[0]);
		dec.initSymbolModel(m_scan_angle_rank[1]);
		ic_point_source_ID.initDecompressor();
		dec.initSymbolModel(m_changed_values);
		for (int j = 0; j < 256; j++)
		{
			if (m_bit_byte[j] != null)
			{
				dec.initSymbolModel(m_bit_byte[j]);
			}
			if (m_classification[j] != null)
			{
				dec.initSymbolModel(m_classification[j]);
			}
			if (m_user_data[j] != null)
			{
				dec.initSymbolModel(m_user_data[j]);
			}
		}
		last.X = item.X;
		last.Y = item.Y;
		last.Z = item.Z;
		last.intensity = 0;
		last.flags = item.flags;
		last.classification_and_classification_flags = item.classification_and_classification_flags;
		last.scan_angle_rank = item.scan_angle_rank;
		last.user_data = item.user_data;
		last.point_source_ID = item.point_source_ID;
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		uint num = dec.decodeSymbol(m_changed_values);
		byte b2;
		byte b3;
		byte b4;
		if (num != 0)
		{
			if ((num & 0x20) != 0)
			{
				if (m_bit_byte[last.flags] == null)
				{
					m_bit_byte[last.flags] = dec.createSymbolModel(256u);
					dec.initSymbolModel(m_bit_byte[last.flags]);
				}
				last.flags = (byte)dec.decodeSymbol(m_bit_byte[last.flags]);
			}
			byte b = (byte)(last.flags & 7);
			b2 = (byte)((last.flags >> 3) & 7);
			b3 = Laszip_Common_v2.number_return_map[b2, b];
			b4 = Laszip_Common_v2.number_return_level[b2, b];
			if ((num & 0x10) != 0)
			{
				last.intensity = (ushort)ic_intensity.decompress(last_intensity[b3], (uint)((b3 < 3) ? b3 : 3));
				last_intensity[b3] = last.intensity;
			}
			else
			{
				last.intensity = last_intensity[b3];
			}
			if ((num & 8) != 0)
			{
				if (m_classification[last.classification_and_classification_flags] == null)
				{
					m_classification[last.classification_and_classification_flags] = dec.createSymbolModel(256u);
					dec.initSymbolModel(m_classification[last.classification_and_classification_flags]);
				}
				last.classification_and_classification_flags = (byte)dec.decodeSymbol(m_classification[last.classification_and_classification_flags]);
			}
			if ((num & 4) != 0)
			{
				int num2 = (int)dec.decodeSymbol(m_scan_angle_rank[((last.flags & 0x40) != 0) ? 1u : 0u]);
				last.scan_angle_rank = (sbyte)((num2 + (byte)last.scan_angle_rank) % 256);
			}
			if ((num & 2) != 0)
			{
				if (m_user_data[last.user_data] == null)
				{
					m_user_data[last.user_data] = dec.createSymbolModel(256u);
					dec.initSymbolModel(m_user_data[last.user_data]);
				}
				last.user_data = (byte)dec.decodeSymbol(m_user_data[last.user_data]);
			}
			if ((num & 1) != 0)
			{
				last.point_source_ID = (ushort)ic_point_source_ID.decompress(last.point_source_ID);
			}
		}
		else
		{
			byte b = (byte)(last.flags & 7);
			b2 = (byte)((last.flags >> 3) & 7);
			b3 = Laszip_Common_v2.number_return_map[b2, b];
			b4 = Laszip_Common_v2.number_return_level[b2, b];
		}
		int pred = last_x_diff_median5[b3].get();
		int num3 = ic_dx.decompress(pred, (b2 == 1) ? 1u : 0u);
		last.X += num3;
		last_x_diff_median5[b3].add(num3);
		pred = last_y_diff_median5[b3].get();
		uint k = ic_dx.getK();
		num3 = ic_dy.decompress(pred, ((b2 == 1) ? 1u : 0u) + ((k < 20) ? (k & 0xFE) : 20));
		last.Y += num3;
		last_y_diff_median5[b3].add(num3);
		k = (ic_dx.getK() + ic_dy.getK()) / 2;
		last.Z = ic_z.decompress(last_height[b4], ((b2 == 1) ? 1u : 0u) + ((k < 18) ? (k & 0xFE) : 18));
		last_height[b4] = last.Z;
		item.X = last.X;
		item.Y = last.Y;
		item.Z = last.Z;
		item.intensity = last.intensity;
		item.flags = last.flags;
		item.classification_and_classification_flags = last.classification_and_classification_flags;
		item.scan_angle_rank = last.scan_angle_rank;
		item.user_data = last.user_data;
		item.point_source_ID = last.point_source_ID;
	}
}
internal class LASreadItemCompressed_POINT14_v3 : LASreadItemCompressed
{
	private const int LASZIP_GPSTIME_MULTI = 500;

	private const int LASZIP_GPSTIME_MULTI_MINUS = -10;

	private const int LASZIP_GPSTIME_MULTI_CODE_FULL = 511;

	private const int LASZIP_GPSTIME_MULTI_TOTAL = 515;

	private ArithmeticDecoder dec;

	private MemoryStream instream_channel_returns_XY;

	private MemoryStream instream_Z;

	private MemoryStream instream_classification;

	private MemoryStream instream_flags;

	private MemoryStream instream_intensity;

	private MemoryStream instream_scan_angle;

	private MemoryStream instream_user_data;

	private MemoryStream instream_point_source;

	private MemoryStream instream_gps_time;

	private ArithmeticDecoder dec_channel_returns_XY;

	private ArithmeticDecoder dec_Z;

	private ArithmeticDecoder dec_classification;

	private ArithmeticDecoder dec_flags;

	private ArithmeticDecoder dec_intensity;

	private ArithmeticDecoder dec_scan_angle;

	private ArithmeticDecoder dec_user_data;

	private ArithmeticDecoder dec_point_source;

	private ArithmeticDecoder dec_gps_time;

	private bool changed_Z;

	private bool changed_classification;

	private bool changed_flags;

	private bool changed_intensity;

	private bool changed_scan_angle;

	private bool changed_user_data;

	private bool changed_point_source;

	private bool changed_gps_time;

	private int num_bytes_channel_returns_XY;

	private int num_bytes_Z;

	private int num_bytes_classification;

	private int num_bytes_flags;

	private int num_bytes_intensity;

	private int num_bytes_scan_angle;

	private int num_bytes_user_data;

	private int num_bytes_point_source;

	private int num_bytes_gps_time;

	private bool requested_Z;

	private bool requested_classification;

	private bool requested_flags;

	private bool requested_intensity;

	private bool requested_scan_angle;

	private bool requested_user_data;

	private bool requested_point_source;

	private bool requested_gps_time;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextPOINT14[] contexts = new LAScontextPOINT14[4]
	{
		new LAScontextPOINT14(),
		new LAScontextPOINT14(),
		new LAScontextPOINT14(),
		new LAScontextPOINT14()
	};

	public LASreadItemCompressed_POINT14_v3(ArithmeticDecoder dec, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		instream_channel_returns_XY = null;
		instream_Z = null;
		instream_classification = null;
		instream_flags = null;
		instream_intensity = null;
		instream_scan_angle = null;
		instream_user_data = null;
		instream_point_source = null;
		instream_gps_time = null;
		dec_channel_returns_XY = null;
		dec_Z = null;
		dec_classification = null;
		dec_flags = null;
		dec_intensity = null;
		dec_scan_angle = null;
		dec_user_data = null;
		dec_point_source = null;
		dec_gps_time = null;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_changed_values[0] = null;
		}
		current_context = 0u;
		num_bytes_channel_returns_XY = 0;
		num_bytes_Z = 0;
		num_bytes_classification = 0;
		num_bytes_flags = 0;
		num_bytes_intensity = 0;
		num_bytes_scan_angle = 0;
		num_bytes_user_data = 0;
		num_bytes_point_source = 0;
		num_bytes_gps_time = 0;
		changed_Z = false;
		changed_classification = false;
		changed_flags = false;
		changed_intensity = false;
		changed_scan_angle = false;
		changed_user_data = false;
		changed_point_source = false;
		changed_gps_time = false;
		requested_Z = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.Z);
		requested_classification = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.CLASSIFICATION);
		requested_flags = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.FLAGS);
		requested_intensity = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.INTENSITY);
		requested_scan_angle = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.SCAN_ANGLE);
		requested_user_data = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.USER_DATA);
		requested_point_source = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.POINT_SOURCE);
		requested_gps_time = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.GPS_TIME);
		bytes = null;
		num_bytes_allocated = 0;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (!byteStreamIn.get32bits(out num_bytes_channel_returns_XY))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_Z))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_classification))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_flags))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_intensity))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_scan_angle))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_user_data))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_point_source))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_gps_time))
		{
			throw new EndOfStreamException();
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_channel_returns_XY == null)
		{
			dec_channel_returns_XY = new ArithmeticDecoder();
			dec_Z = new ArithmeticDecoder();
			dec_classification = new ArithmeticDecoder();
			dec_flags = new ArithmeticDecoder();
			dec_intensity = new ArithmeticDecoder();
			dec_scan_angle = new ArithmeticDecoder();
			dec_user_data = new ArithmeticDecoder();
			dec_point_source = new ArithmeticDecoder();
			dec_gps_time = new ArithmeticDecoder();
		}
		int num = num_bytes_channel_returns_XY;
		if (requested_Z)
		{
			num += num_bytes_Z;
		}
		if (requested_classification)
		{
			num += num_bytes_classification;
		}
		if (requested_flags)
		{
			num += num_bytes_flags;
		}
		if (requested_intensity)
		{
			num += num_bytes_intensity;
		}
		if (requested_scan_angle)
		{
			num += num_bytes_scan_angle;
		}
		if (requested_user_data)
		{
			num += num_bytes_user_data;
		}
		if (requested_point_source)
		{
			num += num_bytes_point_source;
		}
		if (requested_gps_time)
		{
			num += num_bytes_gps_time;
		}
		if (num > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num;
		}
		num = 0;
		if (!byteStreamIn.getBytes(bytes, 0, num_bytes_channel_returns_XY))
		{
			throw new EndOfStreamException();
		}
		instream_channel_returns_XY = new MemoryStream(bytes, 0, num_bytes_channel_returns_XY);
		dec_channel_returns_XY.init(instream_channel_returns_XY);
		num += num_bytes_channel_returns_XY;
		if (requested_Z)
		{
			if (num_bytes_Z != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_Z))
				{
					throw new EndOfStreamException();
				}
				instream_Z = new MemoryStream(bytes, num, num_bytes_Z);
				dec_Z.init(instream_Z);
				num += num_bytes_Z;
				changed_Z = true;
			}
			else
			{
				instream_Z = new MemoryStream(0);
				changed_Z = false;
			}
		}
		else
		{
			if (num_bytes_Z != 0)
			{
				byteStreamIn.Seek(num_bytes_Z, SeekOrigin.Current);
			}
			changed_Z = false;
		}
		if (requested_classification)
		{
			if (num_bytes_classification != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_classification))
				{
					throw new EndOfStreamException();
				}
				instream_classification = new MemoryStream(bytes, num, num_bytes_classification);
				dec_classification.init(instream_classification);
				num += num_bytes_classification;
				changed_classification = true;
			}
			else
			{
				instream_classification = new MemoryStream(0);
				changed_classification = false;
			}
		}
		else
		{
			if (num_bytes_classification != 0)
			{
				byteStreamIn.Seek(num_bytes_classification, SeekOrigin.Current);
			}
			changed_classification = false;
		}
		if (requested_flags)
		{
			if (num_bytes_flags != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_flags))
				{
					throw new EndOfStreamException();
				}
				instream_flags = new MemoryStream(bytes, num, num_bytes_flags);
				dec_flags.init(instream_flags);
				num += num_bytes_flags;
				changed_flags = true;
			}
			else
			{
				instream_flags = new MemoryStream(0);
				changed_flags = false;
			}
		}
		else
		{
			if (num_bytes_flags != 0)
			{
				byteStreamIn.Seek(num_bytes_flags, SeekOrigin.Current);
			}
			changed_flags = false;
		}
		if (requested_intensity)
		{
			if (num_bytes_intensity != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_intensity))
				{
					throw new EndOfStreamException();
				}
				instream_intensity = new MemoryStream(bytes, num, num_bytes_intensity);
				dec_intensity.init(instream_intensity);
				num += num_bytes_intensity;
				changed_intensity = true;
			}
			else
			{
				instream_intensity = new MemoryStream(0);
				changed_intensity = false;
			}
		}
		else
		{
			if (num_bytes_intensity != 0)
			{
				byteStreamIn.Seek(num_bytes_intensity, SeekOrigin.Current);
			}
			changed_intensity = false;
		}
		if (requested_scan_angle)
		{
			if (num_bytes_scan_angle != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_scan_angle))
				{
					throw new EndOfStreamException();
				}
				instream_scan_angle = new MemoryStream(bytes, num, num_bytes_scan_angle);
				dec_scan_angle.init(instream_scan_angle);
				num += num_bytes_scan_angle;
				changed_scan_angle = true;
			}
			else
			{
				instream_scan_angle = new MemoryStream(0);
				changed_scan_angle = false;
			}
		}
		else
		{
			if (num_bytes_scan_angle != 0)
			{
				byteStreamIn.Seek(num_bytes_scan_angle, SeekOrigin.Current);
			}
			changed_scan_angle = false;
		}
		if (requested_user_data)
		{
			if (num_bytes_user_data != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_user_data))
				{
					throw new EndOfStreamException();
				}
				instream_user_data = new MemoryStream(bytes, num, num_bytes_user_data);
				dec_user_data.init(instream_user_data);
				num += num_bytes_user_data;
				changed_user_data = true;
			}
			else
			{
				instream_user_data = new MemoryStream(0);
				changed_user_data = false;
			}
		}
		else
		{
			if (num_bytes_user_data != 0)
			{
				byteStreamIn.Seek(num_bytes_user_data, SeekOrigin.Current);
			}
			changed_user_data = false;
		}
		if (requested_point_source)
		{
			if (num_bytes_point_source != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_point_source))
				{
					throw new EndOfStreamException();
				}
				instream_point_source = new MemoryStream(bytes, num, num_bytes_point_source);
				dec_point_source.init(instream_point_source);
				num += num_bytes_point_source;
				changed_point_source = true;
			}
			else
			{
				instream_point_source = new MemoryStream(0);
				changed_point_source = false;
			}
		}
		else
		{
			if (num_bytes_point_source != 0)
			{
				byteStreamIn.Seek(num_bytes_point_source, SeekOrigin.Current);
			}
			changed_point_source = false;
		}
		if (requested_gps_time)
		{
			if (num_bytes_gps_time != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_gps_time))
				{
					throw new EndOfStreamException();
				}
				instream_gps_time = new MemoryStream(bytes, num, num_bytes_gps_time);
				dec_gps_time.init(instream_gps_time);
				num += num_bytes_gps_time;
				changed_gps_time = true;
			}
			else
			{
				instream_gps_time = new MemoryStream(0);
				changed_gps_time = false;
			}
		}
		else
		{
			if (num_bytes_gps_time != 0)
			{
				byteStreamIn.Seek(num_bytes_gps_time, SeekOrigin.Current);
			}
			changed_gps_time = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = item.extended_scanner_channel;
		context = current_context;
		createAndInitModelsAndDecompressors(current_context, item);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		laszip_point last_item = contexts[current_context].last_item;
		int num = ((last_item.extended_return_number == 1) ? 1 : 0);
		num += ((last_item.extended_return_number >= last_item.extended_number_of_returns) ? 2 : 0);
		num += (contexts[current_context].last_item_gps_time_change ? 4 : 0);
		int num2 = (int)dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_changed_values[num]);
		if ((num2 & 0x40) != 0)
		{
			uint num3 = dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_scanner_channel);
			uint num4 = (current_context + num3 + 1) % 4;
			if (contexts[num4].unused)
			{
				createAndInitModelsAndDecompressors(num4, contexts[current_context].last_item);
			}
			current_context = num4;
			context = current_context;
			last_item = contexts[current_context].last_item;
			last_item.extended_scanner_channel = (byte)num4;
		}
		bool flag = (num2 & 0x20) != 0;
		bool flag2 = (num2 & 0x10) != 0;
		bool flag3 = (num2 & 8) != 0;
		uint extended_number_of_returns = last_item.extended_number_of_returns;
		uint extended_return_number = last_item.extended_return_number;
		uint num5;
		if ((num2 & 4) != 0)
		{
			if (contexts[current_context].m_number_of_returns[extended_number_of_returns] == null)
			{
				contexts[current_context].m_number_of_returns[extended_number_of_returns] = dec_channel_returns_XY.createSymbolModel(16u);
				dec_channel_returns_XY.initSymbolModel(contexts[current_context].m_number_of_returns[extended_number_of_returns]);
			}
			num5 = dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_number_of_returns[extended_number_of_returns]);
			last_item.extended_number_of_returns = (byte)num5;
		}
		else
		{
			num5 = extended_number_of_returns;
		}
		uint num6;
		if ((num2 & 3) == 0)
		{
			num6 = extended_return_number;
		}
		else if ((num2 & 3) == 1)
		{
			num6 = (extended_return_number + 1) % 16;
			last_item.extended_return_number = (byte)num6;
		}
		else if ((num2 & 3) == 2)
		{
			num6 = (extended_return_number + 15) % 16;
			last_item.extended_return_number = (byte)num6;
		}
		else
		{
			if (flag2)
			{
				if (contexts[current_context].m_return_number[extended_return_number] == null)
				{
					contexts[current_context].m_return_number[extended_return_number] = dec_channel_returns_XY.createSymbolModel(16u);
					dec_channel_returns_XY.initSymbolModel(contexts[current_context].m_return_number[extended_return_number]);
				}
				num6 = dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_return_number[extended_return_number]);
			}
			else
			{
				int num7 = (int)dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_return_number_gps_same);
				num6 = (uint)((extended_return_number + (num7 + 2)) % 16);
			}
			last_item.extended_return_number = (byte)num6;
		}
		if (num5 > 7)
		{
			if (num6 > 6)
			{
				if (num6 >= num5)
				{
					last_item.return_number = 7;
				}
				else
				{
					last_item.return_number = 6;
				}
			}
			else
			{
				last_item.return_number = (byte)num6;
			}
			last_item.number_of_returns = 7;
		}
		else
		{
			last_item.return_number = (byte)num6;
			last_item.number_of_returns = (byte)num5;
		}
		uint num8 = Laszip_Common_v3.number_return_map_6ctx[num5, num6];
		uint num9 = Laszip_Common_v3.number_return_level_8ctx[num5, num6];
		int num10 = ((num6 == 1) ? 2 : 0);
		num10 += ((num6 >= num5) ? 1 : 0);
		int pred = contexts[current_context].last_X_diff_median5[(num8 << 1) | (flag2 ? 1u : 0u)].get();
		int num11 = contexts[current_context].ic_dX.decompress(pred, (num5 == 1) ? 1u : 0u);
		last_item.X += num11;
		contexts[current_context].last_X_diff_median5[(num8 << 1) | (flag2 ? 1u : 0u)].add(num11);
		pred = contexts[current_context].last_Y_diff_median5[(num8 << 1) | (flag2 ? 1u : 0u)].get();
		uint k = contexts[current_context].ic_dX.getK();
		num11 = contexts[current_context].ic_dY.decompress(pred, ((num5 == 1) ? 1u : 0u) + ((k < 20) ? (k & 0xFE) : 20));
		last_item.Y += num11;
		contexts[current_context].last_Y_diff_median5[(num8 << 1) | (flag2 ? 1u : 0u)].add(num11);
		if (changed_Z)
		{
			k = (contexts[current_context].ic_dX.getK() + contexts[current_context].ic_dY.getK()) / 2;
			last_item.Z = contexts[current_context].ic_Z.decompress(contexts[current_context].last_Z[num9], ((num5 == 1) ? 1u : 0u) + ((k < 18) ? (k & 0xFE) : 18));
			contexts[current_context].last_Z[num9] = last_item.Z;
		}
		if (changed_classification)
		{
			uint num12 = (uint)((last_item.extended_classification & 0x1F) << 1) + ((num10 == 3) ? 1u : 0u);
			if (contexts[current_context].m_classification[num12] == null)
			{
				contexts[current_context].m_classification[num12] = dec_classification.createSymbolModel(256u);
				dec_classification.initSymbolModel(contexts[current_context].m_classification[num12]);
			}
			last_item.extended_classification = (byte)dec_classification.decodeSymbol(contexts[current_context].m_classification[num12]);
			if (last_item.extended_classification < 32)
			{
				last_item.classification = last_item.extended_classification;
			}
		}
		if (changed_flags)
		{
			int num13 = (last_item.edge_of_flight_line << 5) | (last_item.scan_direction_flag << 4) | last_item.extended_classification_flags;
			if (contexts[current_context].m_flags[num13] == null)
			{
				contexts[current_context].m_flags[num13] = dec_flags.createSymbolModel(64u);
				dec_flags.initSymbolModel(contexts[current_context].m_flags[num13]);
			}
			uint num14 = dec_flags.decodeSymbol(contexts[current_context].m_flags[num13]);
			last_item.edge_of_flight_line = (((num14 & 0x20) != 0) ? ((byte)1) : ((byte)0));
			last_item.scan_direction_flag = (((num14 & 0x10) != 0) ? ((byte)1) : ((byte)0));
			last_item.extended_classification_flags = (byte)(num14 & 0xF);
			last_item.classification_and_classification_flags = (byte)((uint)(last_item.classification_and_classification_flags & 0x1F) | ((num14 & 7) << 5));
		}
		if (changed_intensity)
		{
			ushort num15 = (ushort)contexts[current_context].ic_intensity.decompress(contexts[current_context].last_intensity[(uint)(num10 << 1) | (flag2 ? 1u : 0u)], (uint)num10);
			contexts[current_context].last_intensity[(uint)(num10 << 1) | (flag2 ? 1u : 0u)] = num15;
			last_item.intensity = num15;
		}
		if (changed_scan_angle && flag3)
		{
			last_item.extended_scan_angle = (short)contexts[current_context].ic_scan_angle.decompress(last_item.extended_scan_angle, flag2 ? 1u : 0u);
			last_item.scan_angle_rank = MyDefs.I8_CLAMP(MyDefs.I16_QUANTIZE(0.006f * (float)last_item.extended_scan_angle));
		}
		if (changed_user_data)
		{
			if (contexts[current_context].m_user_data[last_item.user_data / 4] == null)
			{
				contexts[current_context].m_user_data[last_item.user_data / 4] = dec_user_data.createSymbolModel(256u);
				dec_user_data.initSymbolModel(contexts[current_context].m_user_data[last_item.user_data / 4]);
			}
			last_item.user_data = (byte)dec_user_data.decodeSymbol(contexts[current_context].m_user_data[last_item.user_data / 4]);
		}
		if (changed_point_source && flag)
		{
			last_item.point_source_ID = (ushort)contexts[current_context].ic_point_source_ID.decompress(last_item.point_source_ID);
		}
		if (changed_gps_time && flag2)
		{
			read_gps_time();
			last_item.gps_time = contexts[current_context].last_gpstime[contexts[current_context].last].f64;
		}
		item.X = last_item.X;
		item.Y = last_item.Y;
		item.Z = last_item.Z;
		item.intensity = last_item.intensity;
		item.flags = last_item.flags;
		item.classification_and_classification_flags = last_item.classification_and_classification_flags;
		item.scan_angle_rank = last_item.scan_angle_rank;
		item.user_data = last_item.user_data;
		item.point_source_ID = last_item.point_source_ID;
		item.extended_scan_angle = last_item.extended_scan_angle;
		item.extended_flags = last_item.extended_flags;
		item.extended_classification = last_item.extended_classification;
		item.extended_returns = last_item.extended_returns;
		item.gps_time = last_item.gps_time;
		contexts[current_context].last_item_gps_time_change = flag2;
	}

	private bool createAndInitModelsAndDecompressors(uint context, laszip_point item)
	{
		if (contexts[context].m_changed_values[0] == null)
		{
			contexts[context].m_changed_values[0] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[1] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[2] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[3] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[4] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[5] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[6] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[7] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_scanner_channel = dec_channel_returns_XY.createSymbolModel(3u);
			for (int i = 0; i < 16; i++)
			{
				contexts[context].m_number_of_returns[i] = null;
				contexts[context].m_return_number[i] = null;
			}
			contexts[context].m_return_number_gps_same = dec_channel_returns_XY.createSymbolModel(13u);
			contexts[context].ic_dX = new IntegerCompressor(dec_channel_returns_XY, 32u, 2u);
			contexts[context].ic_dY = new IntegerCompressor(dec_channel_returns_XY, 32u, 22u);
			contexts[context].ic_Z = new IntegerCompressor(dec_Z, 32u, 20u);
			for (int j = 0; j < 64; j++)
			{
				contexts[context].m_classification[j] = null;
				contexts[context].m_flags[j] = null;
				contexts[context].m_user_data[j] = null;
			}
			contexts[context].ic_intensity = new IntegerCompressor(dec_intensity, 16u, 4u);
			contexts[context].ic_scan_angle = new IntegerCompressor(dec_scan_angle, 16u, 2u);
			contexts[context].ic_point_source_ID = new IntegerCompressor(dec_point_source);
			contexts[context].m_gpstime_multi = dec_gps_time.createSymbolModel(515u);
			contexts[context].m_gpstime_0diff = dec_gps_time.createSymbolModel(5u);
			contexts[context].ic_gpstime = new IntegerCompressor(dec_gps_time, 32u, 9u);
		}
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[0]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[1]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[2]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[3]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[4]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[5]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[6]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[7]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_scanner_channel);
		for (int k = 0; k < 16; k++)
		{
			if (contexts[context].m_number_of_returns[k] != null)
			{
				dec_channel_returns_XY.initSymbolModel(contexts[context].m_number_of_returns[k]);
			}
			if (contexts[context].m_return_number[k] != null)
			{
				dec_channel_returns_XY.initSymbolModel(contexts[context].m_return_number[k]);
			}
		}
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_return_number_gps_same);
		contexts[context].ic_dX.initDecompressor();
		contexts[context].ic_dY.initDecompressor();
		for (int l = 0; l < 12; l++)
		{
			contexts[context].last_X_diff_median5[l].init();
			contexts[context].last_Y_diff_median5[l].init();
		}
		contexts[context].ic_Z.initDecompressor();
		for (int m = 0; m < 8; m++)
		{
			contexts[context].last_Z[m] = item.Z;
		}
		for (int n = 0; n < 64; n++)
		{
			if (contexts[context].m_classification[n] != null)
			{
				dec_classification.initSymbolModel(contexts[context].m_classification[n]);
			}
			if (contexts[context].m_flags[n] != null)
			{
				dec_flags.initSymbolModel(contexts[context].m_flags[n]);
			}
			if (contexts[context].m_user_data[n] != null)
			{
				dec_user_data.initSymbolModel(contexts[context].m_user_data[n]);
			}
		}
		contexts[context].ic_intensity.initDecompressor();
		for (int num = 0; num < 8; num++)
		{
			contexts[context].last_intensity[num] = item.intensity;
		}
		contexts[context].ic_scan_angle.initDecompressor();
		contexts[context].ic_point_source_ID.initDecompressor();
		dec_gps_time.initSymbolModel(contexts[context].m_gpstime_multi);
		dec_gps_time.initSymbolModel(contexts[context].m_gpstime_0diff);
		contexts[context].ic_gpstime.initDecompressor();
		contexts[context].last = 0u;
		contexts[context].next = 0u;
		contexts[context].last_gpstime_diff[0] = 0;
		contexts[context].last_gpstime_diff[1] = 0;
		contexts[context].last_gpstime_diff[2] = 0;
		contexts[context].last_gpstime_diff[3] = 0;
		contexts[context].multi_extreme_counter[0] = 0;
		contexts[context].multi_extreme_counter[1] = 0;
		contexts[context].multi_extreme_counter[2] = 0;
		contexts[context].multi_extreme_counter[3] = 0;
		contexts[context].last_gpstime[0].f64 = item.gps_time;
		contexts[context].last_gpstime[1].u64 = 0uL;
		contexts[context].last_gpstime[2].u64 = 0uL;
		contexts[context].last_gpstime[3].u64 = 0uL;
		laszip_point last_item = contexts[context].last_item;
		last_item.X = item.X;
		last_item.Y = item.Y;
		last_item.Z = item.Z;
		last_item.intensity = item.intensity;
		last_item.flags = item.flags;
		last_item.classification_and_classification_flags = item.classification_and_classification_flags;
		last_item.scan_angle_rank = item.scan_angle_rank;
		last_item.user_data = item.user_data;
		last_item.point_source_ID = item.point_source_ID;
		last_item.extended_scan_angle = item.extended_scan_angle;
		last_item.extended_flags = item.extended_flags;
		last_item.extended_classification = item.extended_classification;
		last_item.extended_returns = item.extended_returns;
		last_item.gps_time = item.gps_time;
		contexts[context].last_item_gps_time_change = false;
		contexts[context].unused = false;
		return true;
	}

	private void read_gps_time()
	{
		int num;
		if (contexts[current_context].last_gpstime_diff[contexts[current_context].last] == 0)
		{
			num = (int)dec_gps_time.decodeSymbol(contexts[current_context].m_gpstime_0diff);
			switch (num)
			{
			case 0:
				contexts[current_context].last_gpstime_diff[contexts[current_context].last] = contexts[current_context].ic_gpstime.decompress(0);
				contexts[current_context].last_gpstime[contexts[current_context].last].i64 += contexts[current_context].last_gpstime_diff[contexts[current_context].last];
				contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				break;
			case 1:
				contexts[current_context].next = (contexts[current_context].next + 1) & 3;
				contexts[current_context].last_gpstime[contexts[current_context].next].u64 = (ulong)contexts[current_context].ic_gpstime.decompress((int)(contexts[current_context].last_gpstime[contexts[current_context].last].u64 >> 32), 8u);
				contexts[current_context].last_gpstime[contexts[current_context].next].u64 = contexts[current_context].last_gpstime[contexts[current_context].next].u64 << 32;
				contexts[current_context].last_gpstime[contexts[current_context].next].u64 |= dec_gps_time.readInt();
				contexts[current_context].last = contexts[current_context].next;
				contexts[current_context].last_gpstime_diff[contexts[current_context].last] = 0;
				contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				break;
			default:
				contexts[current_context].last = (uint)((int)(contexts[current_context].last + num - 1) & 3);
				read_gps_time();
				break;
			}
			return;
		}
		num = (int)dec_gps_time.decodeSymbol(contexts[current_context].m_gpstime_multi);
		if (num == 1)
		{
			contexts[current_context].last_gpstime[contexts[current_context].last].i64 += contexts[current_context].ic_gpstime.decompress(contexts[current_context].last_gpstime_diff[contexts[current_context].last], 1u);
			contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
		}
		else if (num < 511)
		{
			int num2;
			if (num == 0)
			{
				num2 = contexts[current_context].ic_gpstime.decompress(0, 7u);
				contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
				if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
				{
					contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num2;
					contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				}
			}
			else if (num < 500)
			{
				num2 = ((num >= 10) ? contexts[current_context].ic_gpstime.decompress(num * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 3u) : contexts[current_context].ic_gpstime.decompress(num * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 2u));
			}
			else if (num == 500)
			{
				num2 = contexts[current_context].ic_gpstime.decompress(500 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 4u);
				contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
				if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
				{
					contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num2;
					contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				}
			}
			else
			{
				num = 500 - num;
				if (num > -10)
				{
					num2 = contexts[current_context].ic_gpstime.decompress(num * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 5u);
				}
				else
				{
					num2 = contexts[current_context].ic_gpstime.decompress(-10 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 6u);
					contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
					if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
					{
						contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num2;
						contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
					}
				}
			}
			contexts[current_context].last_gpstime[contexts[current_context].last].i64 += num2;
		}
		else if (num == 511)
		{
			contexts[current_context].next = (contexts[current_context].next + 1) & 3;
			contexts[current_context].last_gpstime[contexts[current_context].next].u64 = (ulong)contexts[current_context].ic_gpstime.decompress((int)(contexts[current_context].last_gpstime[contexts[current_context].last].u64 >> 32), 8u);
			contexts[current_context].last_gpstime[contexts[current_context].next].u64 = contexts[current_context].last_gpstime[contexts[current_context].next].u64 << 32;
			contexts[current_context].last_gpstime[contexts[current_context].next].u64 |= dec_gps_time.readInt();
			contexts[current_context].last = contexts[current_context].next;
			contexts[current_context].last_gpstime_diff[contexts[current_context].last] = 0;
			contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
		}
		else if (num >= 511)
		{
			contexts[current_context].last = (uint)((int)(contexts[current_context].last + num - 511) & 3);
			read_gps_time();
		}
	}
}
internal class LASreadItemCompressed_POINT14_v4 : LASreadItemCompressed
{
	private const int LASZIP_GPSTIME_MULTI = 500;

	private const int LASZIP_GPSTIME_MULTI_MINUS = -10;

	private const int LASZIP_GPSTIME_MULTI_CODE_FULL = 511;

	private const int LASZIP_GPSTIME_MULTI_TOTAL = 515;

	private ArithmeticDecoder dec;

	private MemoryStream instream_channel_returns_XY;

	private MemoryStream instream_Z;

	private MemoryStream instream_classification;

	private MemoryStream instream_flags;

	private MemoryStream instream_intensity;

	private MemoryStream instream_scan_angle;

	private MemoryStream instream_user_data;

	private MemoryStream instream_point_source;

	private MemoryStream instream_gps_time;

	private ArithmeticDecoder dec_channel_returns_XY;

	private ArithmeticDecoder dec_Z;

	private ArithmeticDecoder dec_classification;

	private ArithmeticDecoder dec_flags;

	private ArithmeticDecoder dec_intensity;

	private ArithmeticDecoder dec_scan_angle;

	private ArithmeticDecoder dec_user_data;

	private ArithmeticDecoder dec_point_source;

	private ArithmeticDecoder dec_gps_time;

	private bool changed_Z;

	private bool changed_classification;

	private bool changed_flags;

	private bool changed_intensity;

	private bool changed_scan_angle;

	private bool changed_user_data;

	private bool changed_point_source;

	private bool changed_gps_time;

	private int num_bytes_channel_returns_XY;

	private int num_bytes_Z;

	private int num_bytes_classification;

	private int num_bytes_flags;

	private int num_bytes_intensity;

	private int num_bytes_scan_angle;

	private int num_bytes_user_data;

	private int num_bytes_point_source;

	private int num_bytes_gps_time;

	private bool requested_Z;

	private bool requested_classification;

	private bool requested_flags;

	private bool requested_intensity;

	private bool requested_scan_angle;

	private bool requested_user_data;

	private bool requested_point_source;

	private bool requested_gps_time;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextPOINT14[] contexts = new LAScontextPOINT14[4]
	{
		new LAScontextPOINT14(),
		new LAScontextPOINT14(),
		new LAScontextPOINT14(),
		new LAScontextPOINT14()
	};

	public LASreadItemCompressed_POINT14_v4(ArithmeticDecoder dec, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		instream_channel_returns_XY = null;
		instream_Z = null;
		instream_classification = null;
		instream_flags = null;
		instream_intensity = null;
		instream_scan_angle = null;
		instream_user_data = null;
		instream_point_source = null;
		instream_gps_time = null;
		dec_channel_returns_XY = null;
		dec_Z = null;
		dec_classification = null;
		dec_flags = null;
		dec_intensity = null;
		dec_scan_angle = null;
		dec_user_data = null;
		dec_point_source = null;
		dec_gps_time = null;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_changed_values[0] = null;
		}
		current_context = 0u;
		num_bytes_channel_returns_XY = 0;
		num_bytes_Z = 0;
		num_bytes_classification = 0;
		num_bytes_flags = 0;
		num_bytes_intensity = 0;
		num_bytes_scan_angle = 0;
		num_bytes_user_data = 0;
		num_bytes_point_source = 0;
		num_bytes_gps_time = 0;
		changed_Z = false;
		changed_classification = false;
		changed_flags = false;
		changed_intensity = false;
		changed_scan_angle = false;
		changed_user_data = false;
		changed_point_source = false;
		changed_gps_time = false;
		requested_Z = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.Z);
		requested_classification = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.CLASSIFICATION);
		requested_flags = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.FLAGS);
		requested_intensity = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.INTENSITY);
		requested_scan_angle = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.SCAN_ANGLE);
		requested_user_data = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.USER_DATA);
		requested_point_source = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.POINT_SOURCE);
		requested_gps_time = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.GPS_TIME);
		bytes = null;
		num_bytes_allocated = 0;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (!byteStreamIn.get32bits(out num_bytes_channel_returns_XY))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_Z))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_classification))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_flags))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_intensity))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_scan_angle))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_user_data))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_point_source))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_gps_time))
		{
			throw new EndOfStreamException();
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_channel_returns_XY == null)
		{
			dec_channel_returns_XY = new ArithmeticDecoder();
			dec_Z = new ArithmeticDecoder();
			dec_classification = new ArithmeticDecoder();
			dec_flags = new ArithmeticDecoder();
			dec_intensity = new ArithmeticDecoder();
			dec_scan_angle = new ArithmeticDecoder();
			dec_user_data = new ArithmeticDecoder();
			dec_point_source = new ArithmeticDecoder();
			dec_gps_time = new ArithmeticDecoder();
		}
		int num = num_bytes_channel_returns_XY;
		if (requested_Z)
		{
			num += num_bytes_Z;
		}
		if (requested_classification)
		{
			num += num_bytes_classification;
		}
		if (requested_flags)
		{
			num += num_bytes_flags;
		}
		if (requested_intensity)
		{
			num += num_bytes_intensity;
		}
		if (requested_scan_angle)
		{
			num += num_bytes_scan_angle;
		}
		if (requested_user_data)
		{
			num += num_bytes_user_data;
		}
		if (requested_point_source)
		{
			num += num_bytes_point_source;
		}
		if (requested_gps_time)
		{
			num += num_bytes_gps_time;
		}
		if (num > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num;
		}
		num = 0;
		if (!byteStreamIn.getBytes(bytes, 0, num_bytes_channel_returns_XY))
		{
			throw new EndOfStreamException();
		}
		instream_channel_returns_XY = new MemoryStream(bytes, 0, num_bytes_channel_returns_XY);
		dec_channel_returns_XY.init(instream_channel_returns_XY);
		num += num_bytes_channel_returns_XY;
		if (requested_Z)
		{
			if (num_bytes_Z != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_Z))
				{
					throw new EndOfStreamException();
				}
				instream_Z = new MemoryStream(bytes, num, num_bytes_Z);
				dec_Z.init(instream_Z);
				num += num_bytes_Z;
				changed_Z = true;
			}
			else
			{
				instream_Z = new MemoryStream(0);
				changed_Z = false;
			}
		}
		else
		{
			if (num_bytes_Z != 0)
			{
				byteStreamIn.Seek(num_bytes_Z, SeekOrigin.Current);
			}
			changed_Z = false;
		}
		if (requested_classification)
		{
			if (num_bytes_classification != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_classification))
				{
					throw new EndOfStreamException();
				}
				instream_classification = new MemoryStream(bytes, num, num_bytes_classification);
				dec_classification.init(instream_classification);
				num += num_bytes_classification;
				changed_classification = true;
			}
			else
			{
				instream_classification = new MemoryStream(0);
				changed_classification = false;
			}
		}
		else
		{
			if (num_bytes_classification != 0)
			{
				byteStreamIn.Seek(num_bytes_classification, SeekOrigin.Current);
			}
			changed_classification = false;
		}
		if (requested_flags)
		{
			if (num_bytes_flags != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_flags))
				{
					throw new EndOfStreamException();
				}
				instream_flags = new MemoryStream(bytes, num, num_bytes_flags);
				dec_flags.init(instream_flags);
				num += num_bytes_flags;
				changed_flags = true;
			}
			else
			{
				instream_flags = new MemoryStream(0);
				changed_flags = false;
			}
		}
		else
		{
			if (num_bytes_flags != 0)
			{
				byteStreamIn.Seek(num_bytes_flags, SeekOrigin.Current);
			}
			changed_flags = false;
		}
		if (requested_intensity)
		{
			if (num_bytes_intensity != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_intensity))
				{
					throw new EndOfStreamException();
				}
				instream_intensity = new MemoryStream(bytes, num, num_bytes_intensity);
				dec_intensity.init(instream_intensity);
				num += num_bytes_intensity;
				changed_intensity = true;
			}
			else
			{
				instream_intensity = new MemoryStream(0);
				changed_intensity = false;
			}
		}
		else
		{
			if (num_bytes_intensity != 0)
			{
				byteStreamIn.Seek(num_bytes_intensity, SeekOrigin.Current);
			}
			changed_intensity = false;
		}
		if (requested_scan_angle)
		{
			if (num_bytes_scan_angle != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_scan_angle))
				{
					throw new EndOfStreamException();
				}
				instream_scan_angle = new MemoryStream(bytes, num, num_bytes_scan_angle);
				dec_scan_angle.init(instream_scan_angle);
				num += num_bytes_scan_angle;
				changed_scan_angle = true;
			}
			else
			{
				instream_scan_angle = new MemoryStream(0);
				changed_scan_angle = false;
			}
		}
		else
		{
			if (num_bytes_scan_angle != 0)
			{
				byteStreamIn.Seek(num_bytes_scan_angle, SeekOrigin.Current);
			}
			changed_scan_angle = false;
		}
		if (requested_user_data)
		{
			if (num_bytes_user_data != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_user_data))
				{
					throw new EndOfStreamException();
				}
				instream_user_data = new MemoryStream(bytes, num, num_bytes_user_data);
				dec_user_data.init(instream_user_data);
				num += num_bytes_user_data;
				changed_user_data = true;
			}
			else
			{
				instream_user_data = new MemoryStream(0);
				changed_user_data = false;
			}
		}
		else
		{
			if (num_bytes_user_data != 0)
			{
				byteStreamIn.Seek(num_bytes_user_data, SeekOrigin.Current);
			}
			changed_user_data = false;
		}
		if (requested_point_source)
		{
			if (num_bytes_point_source != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_point_source))
				{
					throw new EndOfStreamException();
				}
				instream_point_source = new MemoryStream(bytes, num, num_bytes_point_source);
				dec_point_source.init(instream_point_source);
				num += num_bytes_point_source;
				changed_point_source = true;
			}
			else
			{
				instream_point_source = new MemoryStream(0);
				changed_point_source = false;
			}
		}
		else
		{
			if (num_bytes_point_source != 0)
			{
				byteStreamIn.Seek(num_bytes_point_source, SeekOrigin.Current);
			}
			changed_point_source = false;
		}
		if (requested_gps_time)
		{
			if (num_bytes_gps_time != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_gps_time))
				{
					throw new EndOfStreamException();
				}
				instream_gps_time = new MemoryStream(bytes, num, num_bytes_gps_time);
				dec_gps_time.init(instream_gps_time);
				num += num_bytes_gps_time;
				changed_gps_time = true;
			}
			else
			{
				instream_gps_time = new MemoryStream(0);
				changed_gps_time = false;
			}
		}
		else
		{
			if (num_bytes_gps_time != 0)
			{
				byteStreamIn.Seek(num_bytes_gps_time, SeekOrigin.Current);
			}
			changed_gps_time = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = item.extended_scanner_channel;
		context = current_context;
		createAndInitModelsAndDecompressors(current_context, item);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		laszip_point last_item = contexts[current_context].last_item;
		int num = ((last_item.extended_return_number == 1) ? 1 : 0);
		num += ((last_item.extended_return_number >= last_item.extended_number_of_returns) ? 2 : 0);
		num += (contexts[current_context].last_item_gps_time_change ? 4 : 0);
		int num2 = (int)dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_changed_values[num]);
		if ((num2 & 0x40) != 0)
		{
			uint num3 = dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_scanner_channel);
			uint num4 = (current_context + num3 + 1) % 4;
			if (contexts[num4].unused)
			{
				createAndInitModelsAndDecompressors(num4, contexts[current_context].last_item);
			}
			current_context = num4;
			last_item = contexts[current_context].last_item;
			last_item.extended_scanner_channel = (byte)num4;
		}
		context = current_context;
		bool flag = (num2 & 0x20) != 0;
		bool flag2 = (num2 & 0x10) != 0;
		bool flag3 = (num2 & 8) != 0;
		uint extended_number_of_returns = last_item.extended_number_of_returns;
		uint extended_return_number = last_item.extended_return_number;
		uint num5;
		if ((num2 & 4) != 0)
		{
			if (contexts[current_context].m_number_of_returns[extended_number_of_returns] == null)
			{
				contexts[current_context].m_number_of_returns[extended_number_of_returns] = dec_channel_returns_XY.createSymbolModel(16u);
				dec_channel_returns_XY.initSymbolModel(contexts[current_context].m_number_of_returns[extended_number_of_returns]);
			}
			num5 = dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_number_of_returns[extended_number_of_returns]);
			last_item.extended_number_of_returns = (byte)num5;
		}
		else
		{
			num5 = extended_number_of_returns;
		}
		uint num6;
		if ((num2 & 3) == 0)
		{
			num6 = extended_return_number;
		}
		else if ((num2 & 3) == 1)
		{
			num6 = (extended_return_number + 1) % 16;
			last_item.extended_return_number = (byte)num6;
		}
		else if ((num2 & 3) == 2)
		{
			num6 = (extended_return_number + 15) % 16;
			last_item.extended_return_number = (byte)num6;
		}
		else
		{
			if (flag2)
			{
				if (contexts[current_context].m_return_number[extended_return_number] == null)
				{
					contexts[current_context].m_return_number[extended_return_number] = dec_channel_returns_XY.createSymbolModel(16u);
					dec_channel_returns_XY.initSymbolModel(contexts[current_context].m_return_number[extended_return_number]);
				}
				num6 = dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_return_number[extended_return_number]);
			}
			else
			{
				int num7 = (int)dec_channel_returns_XY.decodeSymbol(contexts[current_context].m_return_number_gps_same);
				num6 = (uint)((extended_return_number + (num7 + 2)) % 16);
			}
			last_item.extended_return_number = (byte)num6;
		}
		if (num5 > 7)
		{
			if (num6 > 6)
			{
				if (num6 >= num5)
				{
					last_item.return_number = 7;
				}
				else
				{
					last_item.return_number = 6;
				}
			}
			else
			{
				last_item.return_number = (byte)num6;
			}
			last_item.number_of_returns = 7;
		}
		else
		{
			last_item.return_number = (byte)num6;
			last_item.number_of_returns = (byte)num5;
		}
		uint num8 = Laszip_Common_v3.number_return_map_6ctx[num5, num6];
		uint num9 = Laszip_Common_v3.number_return_level_8ctx[num5, num6];
		int num10 = ((num6 == 1) ? 2 : 0);
		num10 += ((num6 >= num5) ? 1 : 0);
		int pred = contexts[current_context].last_X_diff_median5[(num8 << 1) | (flag2 ? 1u : 0u)].get();
		int num11 = contexts[current_context].ic_dX.decompress(pred, (num5 == 1) ? 1u : 0u);
		last_item.X += num11;
		contexts[current_context].last_X_diff_median5[(num8 << 1) | (flag2 ? 1u : 0u)].add(num11);
		pred = contexts[current_context].last_Y_diff_median5[(num8 << 1) | (flag2 ? 1u : 0u)].get();
		uint k = contexts[current_context].ic_dX.getK();
		num11 = contexts[current_context].ic_dY.decompress(pred, ((num5 == 1) ? 1u : 0u) + ((k < 20) ? (k & 0xFE) : 20));
		last_item.Y += num11;
		contexts[current_context].last_Y_diff_median5[(num8 << 1) | (flag2 ? 1u : 0u)].add(num11);
		if (changed_Z)
		{
			k = (contexts[current_context].ic_dX.getK() + contexts[current_context].ic_dY.getK()) / 2;
			last_item.Z = contexts[current_context].ic_Z.decompress(contexts[current_context].last_Z[num9], ((num5 == 1) ? 1u : 0u) + ((k < 18) ? (k & 0xFE) : 18));
			contexts[current_context].last_Z[num9] = last_item.Z;
		}
		if (changed_classification)
		{
			uint num12 = (uint)((last_item.extended_classification & 0x1F) << 1) + ((num10 == 3) ? 1u : 0u);
			if (contexts[current_context].m_classification[num12] == null)
			{
				contexts[current_context].m_classification[num12] = dec_classification.createSymbolModel(256u);
				dec_classification.initSymbolModel(contexts[current_context].m_classification[num12]);
			}
			last_item.extended_classification = (byte)dec_classification.decodeSymbol(contexts[current_context].m_classification[num12]);
			if (last_item.extended_classification < 32)
			{
				last_item.classification = last_item.extended_classification;
			}
		}
		if (changed_flags)
		{
			int num13 = (last_item.edge_of_flight_line << 5) | (last_item.scan_direction_flag << 4) | last_item.extended_classification_flags;
			if (contexts[current_context].m_flags[num13] == null)
			{
				contexts[current_context].m_flags[num13] = dec_flags.createSymbolModel(64u);
				dec_flags.initSymbolModel(contexts[current_context].m_flags[num13]);
			}
			uint num14 = dec_flags.decodeSymbol(contexts[current_context].m_flags[num13]);
			last_item.edge_of_flight_line = (((num14 & 0x20) != 0) ? ((byte)1) : ((byte)0));
			last_item.scan_direction_flag = (((num14 & 0x10) != 0) ? ((byte)1) : ((byte)0));
			last_item.extended_classification_flags = (byte)(num14 & 0xF);
			last_item.classification_and_classification_flags = (byte)((uint)(last_item.classification_and_classification_flags & 0x1F) | ((num14 & 7) << 5));
		}
		if (changed_intensity)
		{
			ushort num15 = (ushort)contexts[current_context].ic_intensity.decompress(contexts[current_context].last_intensity[(uint)(num10 << 1) | (flag2 ? 1u : 0u)], (uint)num10);
			contexts[current_context].last_intensity[(uint)(num10 << 1) | (flag2 ? 1u : 0u)] = num15;
			last_item.intensity = num15;
		}
		if (changed_scan_angle && flag3)
		{
			last_item.extended_scan_angle = (short)contexts[current_context].ic_scan_angle.decompress(last_item.extended_scan_angle, flag2 ? 1u : 0u);
			last_item.scan_angle_rank = MyDefs.I8_CLAMP(MyDefs.I16_QUANTIZE(0.006f * (float)last_item.extended_scan_angle));
		}
		if (changed_user_data)
		{
			if (contexts[current_context].m_user_data[last_item.user_data / 4] == null)
			{
				contexts[current_context].m_user_data[last_item.user_data / 4] = dec_user_data.createSymbolModel(256u);
				dec_user_data.initSymbolModel(contexts[current_context].m_user_data[last_item.user_data / 4]);
			}
			last_item.user_data = (byte)dec_user_data.decodeSymbol(contexts[current_context].m_user_data[last_item.user_data / 4]);
		}
		if (changed_point_source && flag)
		{
			last_item.point_source_ID = (ushort)contexts[current_context].ic_point_source_ID.decompress(last_item.point_source_ID);
		}
		if (changed_gps_time && flag2)
		{
			read_gps_time();
			last_item.gps_time = contexts[current_context].last_gpstime[contexts[current_context].last].f64;
		}
		item.X = last_item.X;
		item.Y = last_item.Y;
		item.Z = last_item.Z;
		item.intensity = last_item.intensity;
		item.flags = last_item.flags;
		item.classification_and_classification_flags = last_item.classification_and_classification_flags;
		item.scan_angle_rank = last_item.scan_angle_rank;
		item.user_data = last_item.user_data;
		item.point_source_ID = last_item.point_source_ID;
		item.extended_scan_angle = last_item.extended_scan_angle;
		item.extended_flags = last_item.extended_flags;
		item.extended_classification = last_item.extended_classification;
		item.extended_returns = last_item.extended_returns;
		item.gps_time = last_item.gps_time;
		contexts[current_context].last_item_gps_time_change = flag2;
	}

	private bool createAndInitModelsAndDecompressors(uint context, laszip_point item)
	{
		if (contexts[context].m_changed_values[0] == null)
		{
			contexts[context].m_changed_values[0] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[1] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[2] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[3] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[4] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[5] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[6] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[7] = dec_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_scanner_channel = dec_channel_returns_XY.createSymbolModel(3u);
			for (int i = 0; i < 16; i++)
			{
				contexts[context].m_number_of_returns[i] = null;
				contexts[context].m_return_number[i] = null;
			}
			contexts[context].m_return_number_gps_same = dec_channel_returns_XY.createSymbolModel(13u);
			contexts[context].ic_dX = new IntegerCompressor(dec_channel_returns_XY, 32u, 2u);
			contexts[context].ic_dY = new IntegerCompressor(dec_channel_returns_XY, 32u, 22u);
			contexts[context].ic_Z = new IntegerCompressor(dec_Z, 32u, 20u);
			for (int j = 0; j < 64; j++)
			{
				contexts[context].m_classification[j] = null;
				contexts[context].m_flags[j] = null;
				contexts[context].m_user_data[j] = null;
			}
			contexts[context].ic_intensity = new IntegerCompressor(dec_intensity, 16u, 4u);
			contexts[context].ic_scan_angle = new IntegerCompressor(dec_scan_angle, 16u, 2u);
			contexts[context].ic_point_source_ID = new IntegerCompressor(dec_point_source);
			contexts[context].m_gpstime_multi = dec_gps_time.createSymbolModel(515u);
			contexts[context].m_gpstime_0diff = dec_gps_time.createSymbolModel(5u);
			contexts[context].ic_gpstime = new IntegerCompressor(dec_gps_time, 32u, 9u);
		}
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[0]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[1]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[2]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[3]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[4]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[5]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[6]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[7]);
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_scanner_channel);
		for (int k = 0; k < 16; k++)
		{
			if (contexts[context].m_number_of_returns[k] != null)
			{
				dec_channel_returns_XY.initSymbolModel(contexts[context].m_number_of_returns[k]);
			}
			if (contexts[context].m_return_number[k] != null)
			{
				dec_channel_returns_XY.initSymbolModel(contexts[context].m_return_number[k]);
			}
		}
		dec_channel_returns_XY.initSymbolModel(contexts[context].m_return_number_gps_same);
		contexts[context].ic_dX.initDecompressor();
		contexts[context].ic_dY.initDecompressor();
		for (int l = 0; l < 12; l++)
		{
			contexts[context].last_X_diff_median5[l].init();
			contexts[context].last_Y_diff_median5[l].init();
		}
		contexts[context].ic_Z.initDecompressor();
		for (int m = 0; m < 8; m++)
		{
			contexts[context].last_Z[m] = item.Z;
		}
		for (int n = 0; n < 64; n++)
		{
			if (contexts[context].m_classification[n] != null)
			{
				dec_classification.initSymbolModel(contexts[context].m_classification[n]);
			}
			if (contexts[context].m_flags[n] != null)
			{
				dec_flags.initSymbolModel(contexts[context].m_flags[n]);
			}
			if (contexts[context].m_user_data[n] != null)
			{
				dec_user_data.initSymbolModel(contexts[context].m_user_data[n]);
			}
		}
		contexts[context].ic_intensity.initDecompressor();
		for (int num = 0; num < 8; num++)
		{
			contexts[context].last_intensity[num] = item.intensity;
		}
		contexts[context].ic_scan_angle.initDecompressor();
		contexts[context].ic_point_source_ID.initDecompressor();
		dec_gps_time.initSymbolModel(contexts[context].m_gpstime_multi);
		dec_gps_time.initSymbolModel(contexts[context].m_gpstime_0diff);
		contexts[context].ic_gpstime.initDecompressor();
		contexts[context].last = 0u;
		contexts[context].next = 0u;
		contexts[context].last_gpstime_diff[0] = 0;
		contexts[context].last_gpstime_diff[1] = 0;
		contexts[context].last_gpstime_diff[2] = 0;
		contexts[context].last_gpstime_diff[3] = 0;
		contexts[context].multi_extreme_counter[0] = 0;
		contexts[context].multi_extreme_counter[1] = 0;
		contexts[context].multi_extreme_counter[2] = 0;
		contexts[context].multi_extreme_counter[3] = 0;
		contexts[context].last_gpstime[0].f64 = item.gps_time;
		contexts[context].last_gpstime[1].u64 = 0uL;
		contexts[context].last_gpstime[2].u64 = 0uL;
		contexts[context].last_gpstime[3].u64 = 0uL;
		laszip_point last_item = contexts[context].last_item;
		last_item.X = item.X;
		last_item.Y = item.Y;
		last_item.Z = item.Z;
		last_item.intensity = item.intensity;
		last_item.flags = item.flags;
		last_item.classification_and_classification_flags = item.classification_and_classification_flags;
		last_item.scan_angle_rank = item.scan_angle_rank;
		last_item.user_data = item.user_data;
		last_item.point_source_ID = item.point_source_ID;
		last_item.extended_scan_angle = item.extended_scan_angle;
		last_item.extended_flags = item.extended_flags;
		last_item.extended_classification = item.extended_classification;
		last_item.extended_returns = item.extended_returns;
		last_item.gps_time = item.gps_time;
		contexts[context].last_item_gps_time_change = false;
		contexts[context].unused = false;
		return true;
	}

	private void read_gps_time()
	{
		int num;
		if (contexts[current_context].last_gpstime_diff[contexts[current_context].last] == 0)
		{
			num = (int)dec_gps_time.decodeSymbol(contexts[current_context].m_gpstime_0diff);
			switch (num)
			{
			case 0:
				contexts[current_context].last_gpstime_diff[contexts[current_context].last] = contexts[current_context].ic_gpstime.decompress(0);
				contexts[current_context].last_gpstime[contexts[current_context].last].i64 += contexts[current_context].last_gpstime_diff[contexts[current_context].last];
				contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				break;
			case 1:
				contexts[current_context].next = (contexts[current_context].next + 1) & 3;
				contexts[current_context].last_gpstime[contexts[current_context].next].u64 = (ulong)contexts[current_context].ic_gpstime.decompress((int)(contexts[current_context].last_gpstime[contexts[current_context].last].u64 >> 32), 8u);
				contexts[current_context].last_gpstime[contexts[current_context].next].u64 = contexts[current_context].last_gpstime[contexts[current_context].next].u64 << 32;
				contexts[current_context].last_gpstime[contexts[current_context].next].u64 |= dec_gps_time.readInt();
				contexts[current_context].last = contexts[current_context].next;
				contexts[current_context].last_gpstime_diff[contexts[current_context].last] = 0;
				contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				break;
			default:
				contexts[current_context].last = (uint)((int)(contexts[current_context].last + num - 1) & 3);
				read_gps_time();
				break;
			}
			return;
		}
		num = (int)dec_gps_time.decodeSymbol(contexts[current_context].m_gpstime_multi);
		if (num == 1)
		{
			contexts[current_context].last_gpstime[contexts[current_context].last].i64 += contexts[current_context].ic_gpstime.decompress(contexts[current_context].last_gpstime_diff[contexts[current_context].last], 1u);
			contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
		}
		else if (num < 511)
		{
			int num2;
			if (num == 0)
			{
				num2 = contexts[current_context].ic_gpstime.decompress(0, 7u);
				contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
				if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
				{
					contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num2;
					contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				}
			}
			else if (num < 500)
			{
				num2 = ((num >= 10) ? contexts[current_context].ic_gpstime.decompress(num * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 3u) : contexts[current_context].ic_gpstime.decompress(num * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 2u));
			}
			else if (num == 500)
			{
				num2 = contexts[current_context].ic_gpstime.decompress(500 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 4u);
				contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
				if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
				{
					contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num2;
					contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				}
			}
			else
			{
				num = 500 - num;
				if (num > -10)
				{
					num2 = contexts[current_context].ic_gpstime.decompress(num * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 5u);
				}
				else
				{
					num2 = contexts[current_context].ic_gpstime.decompress(-10 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], 6u);
					contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
					if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
					{
						contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num2;
						contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
					}
				}
			}
			contexts[current_context].last_gpstime[contexts[current_context].last].i64 += num2;
		}
		else if (num == 511)
		{
			contexts[current_context].next = (contexts[current_context].next + 1) & 3;
			contexts[current_context].last_gpstime[contexts[current_context].next].u64 = (ulong)contexts[current_context].ic_gpstime.decompress((int)(contexts[current_context].last_gpstime[contexts[current_context].last].u64 >> 32), 8u);
			contexts[current_context].last_gpstime[contexts[current_context].next].u64 = contexts[current_context].last_gpstime[contexts[current_context].next].u64 << 32;
			contexts[current_context].last_gpstime[contexts[current_context].next].u64 |= dec_gps_time.readInt();
			contexts[current_context].last = contexts[current_context].next;
			contexts[current_context].last_gpstime_diff[contexts[current_context].last] = 0;
			contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
		}
		else if (num >= 511)
		{
			contexts[current_context].last = (uint)((int)(contexts[current_context].last + num - 511) & 3);
			read_gps_time();
		}
	}
}
internal class LASreadItemCompressed_RGB12_v1 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private ushort last_r;

	private ushort last_g;

	private ushort last_b;

	private ArithmeticModel m_byte_used;

	private IntegerCompressor ic_rgb;

	public LASreadItemCompressed_RGB12_v1(ArithmeticDecoder dec)
	{
		this.dec = dec;
		m_byte_used = dec.createSymbolModel(64u);
		ic_rgb = new IntegerCompressor(dec, 8u, 6u);
	}

	public override bool init(laszip_point item, ref uint context)
	{
		dec.initSymbolModel(m_byte_used);
		ic_rgb.initDecompressor();
		last_r = item.rgb[0];
		last_g = item.rgb[1];
		last_b = item.rgb[2];
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		uint num = dec.decodeSymbol(m_byte_used);
		ushort[] rgb = item.rgb;
		if ((num & 1) != 0)
		{
			rgb[0] = (ushort)ic_rgb.decompress(last_r & 0xFF);
		}
		else
		{
			rgb[0] = (ushort)(last_r & 0xFF);
		}
		if ((num & 2) != 0)
		{
			rgb[0] |= (ushort)((ushort)ic_rgb.decompress(last_r >> 8, 1u) << 8);
		}
		else
		{
			rgb[0] |= (ushort)(last_r & 0xFF00);
		}
		if ((num & 4) != 0)
		{
			rgb[1] = (ushort)ic_rgb.decompress(last_g & 0xFF, 2u);
		}
		else
		{
			rgb[1] = (ushort)(last_g & 0xFF);
		}
		if ((num & 8) != 0)
		{
			rgb[1] |= (ushort)((ushort)ic_rgb.decompress(last_g >> 8, 3u) << 8);
		}
		else
		{
			rgb[1] |= (ushort)(last_g & 0xFF00);
		}
		if ((num & 0x10) != 0)
		{
			rgb[2] = (ushort)ic_rgb.decompress(last_b & 0xFF, 4u);
		}
		else
		{
			rgb[2] = (ushort)(last_b & 0xFF);
		}
		if ((num & 0x20) != 0)
		{
			rgb[2] |= (ushort)((ushort)ic_rgb.decompress(last_b >> 8, 5u) << 8);
		}
		else
		{
			rgb[2] |= (ushort)(last_b & 0xFF00);
		}
		last_r = rgb[0];
		last_g = rgb[1];
		last_b = rgb[2];
	}
}
internal class LASreadItemCompressed_RGB12_v2 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private readonly ushort[] last_item = new ushort[3];

	private ArithmeticModel m_byte_used;

	private ArithmeticModel m_rgb_diff_0;

	private ArithmeticModel m_rgb_diff_1;

	private ArithmeticModel m_rgb_diff_2;

	private ArithmeticModel m_rgb_diff_3;

	private ArithmeticModel m_rgb_diff_4;

	private ArithmeticModel m_rgb_diff_5;

	public LASreadItemCompressed_RGB12_v2(ArithmeticDecoder dec)
	{
		this.dec = dec;
		m_byte_used = dec.createSymbolModel(128u);
		m_rgb_diff_0 = dec.createSymbolModel(256u);
		m_rgb_diff_1 = dec.createSymbolModel(256u);
		m_rgb_diff_2 = dec.createSymbolModel(256u);
		m_rgb_diff_3 = dec.createSymbolModel(256u);
		m_rgb_diff_4 = dec.createSymbolModel(256u);
		m_rgb_diff_5 = dec.createSymbolModel(256u);
	}

	public override bool init(laszip_point item, ref uint context)
	{
		dec.initSymbolModel(m_byte_used);
		dec.initSymbolModel(m_rgb_diff_0);
		dec.initSymbolModel(m_rgb_diff_1);
		dec.initSymbolModel(m_rgb_diff_2);
		dec.initSymbolModel(m_rgb_diff_3);
		dec.initSymbolModel(m_rgb_diff_4);
		dec.initSymbolModel(m_rgb_diff_5);
		last_item[0] = item.rgb[0];
		last_item[1] = item.rgb[1];
		last_item[2] = item.rgb[2];
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		int num = 0;
		uint num2 = dec.decodeSymbol(m_byte_used);
		if ((num2 & 1) != 0)
		{
			int num3 = (int)dec.decodeSymbol(m_rgb_diff_0);
			item.rgb[0] = (ushort)MyDefs.U8_FOLD(num3 + (last_item[0] & 0xFF));
		}
		else
		{
			item.rgb[0] = (ushort)(last_item[0] & 0xFF);
		}
		if ((num2 & 2) != 0)
		{
			int num3 = (int)dec.decodeSymbol(m_rgb_diff_1);
			item.rgb[0] |= (ushort)(MyDefs.U8_FOLD(num3 + (last_item[0] >> 8)) << 8);
		}
		else
		{
			item.rgb[0] |= (ushort)(last_item[0] & 0xFF00);
		}
		if ((num2 & 0x40) != 0)
		{
			num = (item.rgb[0] & 0xFF) - (last_item[0] & 0xFF);
			if ((num2 & 4) != 0)
			{
				int num3 = (int)dec.decodeSymbol(m_rgb_diff_2);
				item.rgb[1] = (ushort)MyDefs.U8_FOLD(num3 + MyDefs.U8_CLAMP(num + (last_item[1] & 0xFF)));
			}
			else
			{
				item.rgb[1] = (ushort)(last_item[1] & 0xFF);
			}
			if ((num2 & 0x10) != 0)
			{
				int num3 = (int)dec.decodeSymbol(m_rgb_diff_4);
				num = (num + ((item.rgb[1] & 0xFF) - (last_item[1] & 0xFF))) / 2;
				item.rgb[2] = (ushort)MyDefs.U8_FOLD(num3 + MyDefs.U8_CLAMP(num + (last_item[2] & 0xFF)));
			}
			else
			{
				item.rgb[2] = (ushort)(last_item[2] & 0xFF);
			}
			num = (item.rgb[0] >> 8) - (last_item[0] >> 8);
			if ((num2 & 8) != 0)
			{
				int num3 = (int)dec.decodeSymbol(m_rgb_diff_3);
				item.rgb[1] |= (ushort)(MyDefs.U8_FOLD(num3 + MyDefs.U8_CLAMP(num + (last_item[1] >> 8))) << 8);
			}
			else
			{
				item.rgb[1] |= (ushort)(last_item[1] & 0xFF00);
			}
			if ((num2 & 0x20) != 0)
			{
				int num3 = (int)dec.decodeSymbol(m_rgb_diff_5);
				num = (num + ((item.rgb[1] >> 8) - (last_item[1] >> 8))) / 2;
				item.rgb[2] |= (ushort)(MyDefs.U8_FOLD(num3 + MyDefs.U8_CLAMP(num + (last_item[2] >> 8))) << 8);
			}
			else
			{
				item.rgb[2] |= (ushort)(last_item[2] & 0xFF00);
			}
		}
		else
		{
			item.rgb[1] = item.rgb[0];
			item.rgb[2] = item.rgb[0];
		}
		last_item[0] = item.rgb[0];
		last_item[1] = item.rgb[1];
		last_item[2] = item.rgb[2];
	}
}
internal class LASreadItemCompressed_RGB14_v3 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private MemoryStream instream_RGB;

	private ArithmeticDecoder dec_RGB;

	private bool changed_RGB;

	private int num_bytes_RGB;

	private bool requested_RGB;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextRGB14[] contexts = new LAScontextRGB14[4]
	{
		new LAScontextRGB14(),
		new LAScontextRGB14(),
		new LAScontextRGB14(),
		new LAScontextRGB14()
	};

	public LASreadItemCompressed_RGB14_v3(ArithmeticDecoder dec, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		instream_RGB = null;
		dec_RGB = null;
		num_bytes_RGB = 0;
		changed_RGB = false;
		requested_RGB = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.RGB);
		bytes = null;
		num_bytes_allocated = 0;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_byte_used = null;
		}
		current_context = 0u;
	}

	public override bool chunk_sizes()
	{
		if (!dec.getByteStreamIn().get32bits(out num_bytes_RGB))
		{
			throw new EndOfStreamException();
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_RGB == null)
		{
			dec_RGB = new ArithmeticDecoder();
		}
		if (num_bytes_RGB > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num_bytes_RGB];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num_bytes_RGB;
		}
		if (requested_RGB)
		{
			if (num_bytes_RGB != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num_bytes_RGB))
				{
					throw new EndOfStreamException();
				}
				instream_RGB = new MemoryStream(bytes, 0, num_bytes_RGB);
				dec_RGB.init(instream_RGB);
				changed_RGB = true;
			}
			else
			{
				instream_RGB = new MemoryStream(0);
				changed_RGB = false;
			}
		}
		else
		{
			if (num_bytes_RGB != 0)
			{
				byteStreamIn.Seek(num_bytes_RGB, SeekOrigin.Current);
			}
			changed_RGB = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndDecompressors(current_context, item.rgb);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		ushort[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndDecompressors(current_context, last_item);
				last_item = contexts[current_context].last_item;
			}
		}
		if (changed_RGB)
		{
			uint num = dec_RGB.decodeSymbol(contexts[current_context].m_byte_used);
			if ((num & 1) != 0)
			{
				byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_0);
				item.rgb[0] = (ushort)MyDefs.U8_FOLD(b + (last_item[0] & 0xFF));
			}
			else
			{
				item.rgb[0] = (ushort)(last_item[0] & 0xFF);
			}
			if ((num & 2) != 0)
			{
				byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_1);
				item.rgb[0] |= (ushort)(MyDefs.U8_FOLD(b + (last_item[0] >> 8)) << 8);
			}
			else
			{
				item.rgb[0] |= (ushort)(last_item[0] & 0xFF00);
			}
			if ((num & 0x40) != 0)
			{
				int num2 = (item.rgb[0] & 0xFF) - (last_item[0] & 0xFF);
				if ((num & 4) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_2);
					item.rgb[1] = (ushort)MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[1] & 0xFF)));
				}
				else
				{
					item.rgb[1] = (ushort)(last_item[1] & 0xFF);
				}
				if ((num & 0x10) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_4);
					num2 = (num2 + ((item.rgb[1] & 0xFF) - (last_item[1] & 0xFF))) / 2;
					item.rgb[2] = (ushort)MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[2] & 0xFF)));
				}
				else
				{
					item.rgb[2] = (ushort)(last_item[2] & 0xFF);
				}
				num2 = (item.rgb[0] >> 8) - (last_item[0] >> 8);
				if ((num & 8) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_3);
					item.rgb[1] |= (ushort)(MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[1] >> 8))) << 8);
				}
				else
				{
					item.rgb[1] |= (ushort)(last_item[1] & 0xFF00);
				}
				if ((num & 0x20) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_5);
					num2 = (num2 + ((item.rgb[1] >> 8) - (last_item[1] >> 8))) / 2;
					item.rgb[2] |= (ushort)(MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[2] >> 8))) << 8);
				}
				else
				{
					item.rgb[2] |= (ushort)(last_item[2] & 0xFF00);
				}
			}
			else
			{
				item.rgb[1] = item.rgb[0];
				item.rgb[2] = item.rgb[0];
			}
			last_item[0] = item.rgb[0];
			last_item[1] = item.rgb[1];
			last_item[2] = item.rgb[2];
		}
		else
		{
			item.rgb[0] = last_item[0];
			item.rgb[1] = last_item[1];
			item.rgb[2] = last_item[2];
		}
	}

	private bool createAndInitModelsAndDecompressors(uint context, ushort[] item)
	{
		if (contexts[context].m_byte_used == null)
		{
			contexts[context].m_byte_used = dec_RGB.createSymbolModel(128u);
			contexts[context].m_rgb_diff_0 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_1 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_2 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_3 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_4 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_5 = dec_RGB.createSymbolModel(256u);
		}
		dec_RGB.initSymbolModel(contexts[context].m_byte_used);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_0);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_1);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_2);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_3);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_4);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_5);
		contexts[context].last_item[0] = item[0];
		contexts[context].last_item[1] = item[1];
		contexts[context].last_item[2] = item[2];
		contexts[context].unused = false;
		return true;
	}
}
internal class LASreadItemCompressed_RGB14_v4 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private MemoryStream instream_RGB;

	private ArithmeticDecoder dec_RGB;

	private bool changed_RGB;

	private int num_bytes_RGB;

	private bool requested_RGB;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextRGB14[] contexts = new LAScontextRGB14[4]
	{
		new LAScontextRGB14(),
		new LAScontextRGB14(),
		new LAScontextRGB14(),
		new LAScontextRGB14()
	};

	public LASreadItemCompressed_RGB14_v4(ArithmeticDecoder dec, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		instream_RGB = null;
		dec_RGB = null;
		num_bytes_RGB = 0;
		changed_RGB = false;
		requested_RGB = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.RGB);
		bytes = null;
		num_bytes_allocated = 0;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_byte_used = null;
		}
		current_context = 0u;
	}

	public override bool chunk_sizes()
	{
		if (!dec.getByteStreamIn().get32bits(out num_bytes_RGB))
		{
			throw new EndOfStreamException();
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_RGB == null)
		{
			dec_RGB = new ArithmeticDecoder();
		}
		if (num_bytes_RGB > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num_bytes_RGB];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num_bytes_RGB;
		}
		if (requested_RGB)
		{
			if (num_bytes_RGB != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num_bytes_RGB))
				{
					throw new EndOfStreamException();
				}
				instream_RGB = new MemoryStream(bytes, 0, num_bytes_RGB);
				dec_RGB.init(instream_RGB);
				changed_RGB = true;
			}
			else
			{
				instream_RGB = new MemoryStream(0);
				changed_RGB = false;
			}
		}
		else
		{
			if (num_bytes_RGB != 0)
			{
				byteStreamIn.Seek(num_bytes_RGB, SeekOrigin.Current);
			}
			changed_RGB = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndDecompressors(current_context, item.rgb);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		ushort[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndDecompressors(current_context, last_item);
			}
			last_item = contexts[current_context].last_item;
		}
		if (changed_RGB)
		{
			uint num = dec_RGB.decodeSymbol(contexts[current_context].m_byte_used);
			if ((num & 1) != 0)
			{
				byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_0);
				item.rgb[0] = (ushort)MyDefs.U8_FOLD(b + (last_item[0] & 0xFF));
			}
			else
			{
				item.rgb[0] = (ushort)(last_item[0] & 0xFF);
			}
			if ((num & 2) != 0)
			{
				byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_1);
				item.rgb[0] |= (ushort)(MyDefs.U8_FOLD(b + (last_item[0] >> 8)) << 8);
			}
			else
			{
				item.rgb[0] |= (ushort)(last_item[0] & 0xFF00);
			}
			if ((num & 0x40) != 0)
			{
				int num2 = (item.rgb[0] & 0xFF) - (last_item[0] & 0xFF);
				if ((num & 4) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_2);
					item.rgb[1] = (ushort)MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[1] & 0xFF)));
				}
				else
				{
					item.rgb[1] = (ushort)(last_item[1] & 0xFF);
				}
				if ((num & 0x10) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_4);
					num2 = (num2 + ((item.rgb[1] & 0xFF) - (last_item[1] & 0xFF))) / 2;
					item.rgb[2] = (ushort)MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[2] & 0xFF)));
				}
				else
				{
					item.rgb[2] = (ushort)(last_item[2] & 0xFF);
				}
				num2 = (item.rgb[0] >> 8) - (last_item[0] >> 8);
				if ((num & 8) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_3);
					item.rgb[1] |= (ushort)(MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[1] >> 8))) << 8);
				}
				else
				{
					item.rgb[1] |= (ushort)(last_item[1] & 0xFF00);
				}
				if ((num & 0x20) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_5);
					num2 = (num2 + ((item.rgb[1] >> 8) - (last_item[1] >> 8))) / 2;
					item.rgb[2] |= (ushort)(MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[2] >> 8))) << 8);
				}
				else
				{
					item.rgb[2] |= (ushort)(last_item[2] & 0xFF00);
				}
			}
			else
			{
				item.rgb[1] = item.rgb[0];
				item.rgb[2] = item.rgb[0];
			}
			last_item[0] = item.rgb[0];
			last_item[1] = item.rgb[1];
			last_item[2] = item.rgb[2];
		}
		else
		{
			item.rgb[0] = last_item[0];
			item.rgb[1] = last_item[1];
			item.rgb[2] = last_item[2];
		}
	}

	private bool createAndInitModelsAndDecompressors(uint context, ushort[] item)
	{
		if (contexts[context].m_byte_used == null)
		{
			contexts[context].m_byte_used = dec_RGB.createSymbolModel(128u);
			contexts[context].m_rgb_diff_0 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_1 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_2 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_3 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_4 = dec_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_5 = dec_RGB.createSymbolModel(256u);
		}
		dec_RGB.initSymbolModel(contexts[context].m_byte_used);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_0);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_1);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_2);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_3);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_4);
		dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_5);
		contexts[context].last_item[0] = item[0];
		contexts[context].last_item[1] = item[1];
		contexts[context].last_item[2] = item[2];
		contexts[context].unused = false;
		return true;
	}
}
internal class LASreadItemCompressed_RGBNIR14_v3 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private MemoryStream instream_RGB;

	private MemoryStream instream_NIR;

	private ArithmeticDecoder dec_RGB;

	private ArithmeticDecoder dec_NIR;

	private bool changed_RGB;

	private bool changed_NIR;

	private int num_bytes_RGB;

	private int num_bytes_NIR;

	private bool requested_RGB;

	private bool requested_NIR;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextRGBNIR14[] contexts = new LAScontextRGBNIR14[4]
	{
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14()
	};

	public LASreadItemCompressed_RGBNIR14_v3(ArithmeticDecoder dec, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		instream_RGB = null;
		instream_NIR = null;
		dec_RGB = null;
		dec_NIR = null;
		num_bytes_RGB = 0;
		num_bytes_NIR = 0;
		changed_RGB = false;
		changed_NIR = false;
		requested_RGB = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.RGB);
		requested_NIR = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.NIR);
		bytes = null;
		num_bytes_allocated = 0;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_rgb_bytes_used = null;
			contexts[i].m_nir_bytes_used = null;
		}
		current_context = 0u;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (!byteStreamIn.get32bits(out num_bytes_RGB))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_NIR))
		{
			throw new EndOfStreamException();
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_RGB == null)
		{
			dec_RGB = new ArithmeticDecoder();
			dec_NIR = new ArithmeticDecoder();
		}
		int num = 0;
		if (requested_RGB)
		{
			num += num_bytes_RGB;
		}
		if (requested_NIR)
		{
			num += num_bytes_NIR;
		}
		if (num > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num;
		}
		num = 0;
		if (requested_RGB)
		{
			if (num_bytes_RGB != 0)
			{
				if (!byteStreamIn.getBytes(bytes, 0, num_bytes_RGB))
				{
					throw new EndOfStreamException();
				}
				instream_RGB = new MemoryStream(bytes, num, num_bytes_RGB);
				dec_RGB.init(instream_RGB);
				changed_RGB = true;
				num += num_bytes_RGB;
			}
			else
			{
				instream_RGB = new MemoryStream(0);
				changed_RGB = false;
			}
		}
		else
		{
			if (num_bytes_RGB != 0)
			{
				byteStreamIn.Seek(num_bytes_RGB, SeekOrigin.Current);
			}
			changed_RGB = false;
		}
		if (requested_NIR)
		{
			if (num_bytes_NIR != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_NIR))
				{
					throw new EndOfStreamException();
				}
				instream_NIR = new MemoryStream(bytes, num, num_bytes_RGB);
				dec_NIR.init(instream_NIR);
				changed_NIR = true;
			}
			else
			{
				instream_NIR = new MemoryStream(0);
				changed_NIR = false;
			}
		}
		else
		{
			if (num_bytes_NIR != 0)
			{
				byteStreamIn.Seek(num_bytes_NIR, SeekOrigin.Current);
			}
			changed_NIR = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndDecompressors(current_context, item.rgb);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		ushort[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndDecompressors(current_context, last_item);
				last_item = contexts[current_context].last_item;
			}
		}
		if (changed_RGB)
		{
			uint num = dec_RGB.decodeSymbol(contexts[current_context].m_rgb_bytes_used);
			if ((num & 1) != 0)
			{
				byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_0);
				item.rgb[0] = (ushort)MyDefs.U8_FOLD(b + (last_item[0] & 0xFF));
			}
			else
			{
				item.rgb[0] = (ushort)(last_item[0] & 0xFF);
			}
			if ((num & 2) != 0)
			{
				byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_1);
				item.rgb[0] |= (ushort)(MyDefs.U8_FOLD(b + (last_item[0] >> 8)) << 8);
			}
			else
			{
				item.rgb[0] |= (ushort)(last_item[0] & 0xFF00);
			}
			if ((num & 0x40) != 0)
			{
				int num2 = (item.rgb[0] & 0xFF) - (last_item[0] & 0xFF);
				if ((num & 4) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_2);
					item.rgb[1] = (ushort)MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[1] & 0xFF)));
				}
				else
				{
					item.rgb[1] = (ushort)(last_item[1] & 0xFF);
				}
				if ((num & 0x10) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_4);
					num2 = (num2 + ((item.rgb[1] & 0xFF) - (last_item[1] & 0xFF))) / 2;
					item.rgb[2] = (ushort)MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[2] & 0xFF)));
				}
				else
				{
					item.rgb[2] = (ushort)(last_item[2] & 0xFF);
				}
				num2 = (item.rgb[0] >> 8) - (last_item[0] >> 8);
				if ((num & 8) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_3);
					item.rgb[1] |= (ushort)(MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[1] >> 8))) << 8);
				}
				else
				{
					item.rgb[1] |= (ushort)(last_item[1] & 0xFF00);
				}
				if ((num & 0x20) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_5);
					num2 = (num2 + ((item.rgb[1] >> 8) - (last_item[1] >> 8))) / 2;
					item.rgb[2] |= (ushort)(MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[2] >> 8))) << 8);
				}
				else
				{
					item.rgb[2] |= (ushort)(last_item[2] & 0xFF00);
				}
			}
			else
			{
				item.rgb[1] = item.rgb[0];
				item.rgb[2] = item.rgb[0];
			}
			last_item[0] = item.rgb[0];
			last_item[1] = item.rgb[1];
			last_item[2] = item.rgb[2];
		}
		else
		{
			item.rgb[0] = last_item[0];
			item.rgb[1] = last_item[1];
			item.rgb[2] = last_item[2];
		}
		if (changed_NIR)
		{
			uint num3 = dec_NIR.decodeSymbol(contexts[current_context].m_nir_bytes_used);
			if ((num3 & 1) != 0)
			{
				byte b2 = (byte)dec_NIR.decodeSymbol(contexts[current_context].m_nir_diff_0);
				item.rgb[3] = (ushort)MyDefs.U8_FOLD(b2 + (last_item[3] & 0xFF));
			}
			else
			{
				item.rgb[3] = (ushort)(last_item[3] & 0xFF);
			}
			if ((num3 & 2) != 0)
			{
				byte b2 = (byte)dec_NIR.decodeSymbol(contexts[current_context].m_nir_diff_1);
				item.rgb[3] |= (ushort)(MyDefs.U8_FOLD(b2 + (last_item[3] >> 8)) << 8);
			}
			else
			{
				item.rgb[3] |= (ushort)(last_item[3] & 0xFF00);
			}
			last_item[3] = item.rgb[3];
		}
		else
		{
			item.rgb[3] = last_item[3];
		}
	}

	private bool createAndInitModelsAndDecompressors(uint context, ushort[] item)
	{
		if (requested_RGB)
		{
			if (contexts[context].m_rgb_bytes_used == null)
			{
				contexts[context].m_rgb_bytes_used = dec_RGB.createSymbolModel(128u);
				contexts[context].m_rgb_diff_0 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_1 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_2 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_3 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_4 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_5 = dec_RGB.createSymbolModel(256u);
			}
			dec_RGB.initSymbolModel(contexts[context].m_rgb_bytes_used);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_0);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_1);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_2);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_3);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_4);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_5);
		}
		if (requested_NIR)
		{
			if (contexts[context].m_nir_bytes_used == null)
			{
				contexts[context].m_nir_bytes_used = dec_NIR.createSymbolModel(4u);
				contexts[context].m_nir_diff_0 = dec_NIR.createSymbolModel(256u);
				contexts[context].m_nir_diff_1 = dec_NIR.createSymbolModel(256u);
			}
			dec_NIR.initSymbolModel(contexts[context].m_nir_bytes_used);
			dec_NIR.initSymbolModel(contexts[context].m_nir_diff_0);
			dec_NIR.initSymbolModel(contexts[context].m_nir_diff_1);
		}
		contexts[context].last_item[0] = item[0];
		contexts[context].last_item[1] = item[1];
		contexts[context].last_item[2] = item[2];
		contexts[context].last_item[3] = item[3];
		contexts[context].unused = false;
		return true;
	}
}
internal class LASreadItemCompressed_RGBNIR14_v4 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private MemoryStream instream_RGB;

	private MemoryStream instream_NIR;

	private ArithmeticDecoder dec_RGB;

	private ArithmeticDecoder dec_NIR;

	private bool changed_RGB;

	private bool changed_NIR;

	private int num_bytes_RGB;

	private int num_bytes_NIR;

	private bool requested_RGB;

	private bool requested_NIR;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextRGBNIR14[] contexts = new LAScontextRGBNIR14[4]
	{
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14()
	};

	public LASreadItemCompressed_RGBNIR14_v4(ArithmeticDecoder dec, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		instream_RGB = null;
		instream_NIR = null;
		dec_RGB = null;
		dec_NIR = null;
		num_bytes_RGB = 0;
		num_bytes_NIR = 0;
		changed_RGB = false;
		changed_NIR = false;
		requested_RGB = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.RGB);
		requested_NIR = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.NIR);
		bytes = null;
		num_bytes_allocated = 0;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_rgb_bytes_used = null;
			contexts[i].m_nir_bytes_used = null;
		}
		current_context = 0u;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (!byteStreamIn.get32bits(out num_bytes_RGB))
		{
			throw new EndOfStreamException();
		}
		if (!byteStreamIn.get32bits(out num_bytes_NIR))
		{
			throw new EndOfStreamException();
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_RGB == null)
		{
			dec_RGB = new ArithmeticDecoder();
			dec_NIR = new ArithmeticDecoder();
		}
		int num = 0;
		if (requested_RGB)
		{
			num += num_bytes_RGB;
		}
		if (requested_NIR)
		{
			num += num_bytes_NIR;
		}
		if (num > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num;
		}
		num = 0;
		if (requested_RGB)
		{
			if (num_bytes_RGB != 0)
			{
				if (!byteStreamIn.getBytes(bytes, 0, num_bytes_RGB))
				{
					throw new EndOfStreamException();
				}
				instream_RGB = new MemoryStream(bytes, num, num_bytes_RGB);
				dec_RGB.init(instream_RGB);
				changed_RGB = true;
				num += num_bytes_RGB;
			}
			else
			{
				instream_RGB = new MemoryStream(0);
				changed_RGB = false;
			}
		}
		else
		{
			if (num_bytes_RGB != 0)
			{
				byteStreamIn.Seek(num_bytes_RGB, SeekOrigin.Current);
			}
			changed_RGB = false;
		}
		if (requested_NIR)
		{
			if (num_bytes_NIR != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num, num_bytes_NIR))
				{
					throw new EndOfStreamException();
				}
				instream_NIR = new MemoryStream(bytes, num, num_bytes_RGB);
				dec_NIR.init(instream_NIR);
				changed_NIR = true;
			}
			else
			{
				instream_NIR = new MemoryStream(0);
				changed_NIR = false;
			}
		}
		else
		{
			if (num_bytes_NIR != 0)
			{
				byteStreamIn.Seek(num_bytes_NIR, SeekOrigin.Current);
			}
			changed_NIR = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndDecompressors(current_context, item.rgb);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		ushort[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndDecompressors(current_context, last_item);
			}
			last_item = contexts[current_context].last_item;
		}
		if (changed_RGB)
		{
			uint num = dec_RGB.decodeSymbol(contexts[current_context].m_rgb_bytes_used);
			if ((num & 1) != 0)
			{
				byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_0);
				item.rgb[0] = (ushort)MyDefs.U8_FOLD(b + (last_item[0] & 0xFF));
			}
			else
			{
				item.rgb[0] = (ushort)(last_item[0] & 0xFF);
			}
			if ((num & 2) != 0)
			{
				byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_1);
				item.rgb[0] |= (ushort)(MyDefs.U8_FOLD(b + (last_item[0] >> 8)) << 8);
			}
			else
			{
				item.rgb[0] |= (ushort)(last_item[0] & 0xFF00);
			}
			if ((num & 0x40) != 0)
			{
				int num2 = (item.rgb[0] & 0xFF) - (last_item[0] & 0xFF);
				if ((num & 4) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_2);
					item.rgb[1] = (ushort)MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[1] & 0xFF)));
				}
				else
				{
					item.rgb[1] = (ushort)(last_item[1] & 0xFF);
				}
				if ((num & 0x10) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_4);
					num2 = (num2 + ((item.rgb[1] & 0xFF) - (last_item[1] & 0xFF))) / 2;
					item.rgb[2] = (ushort)MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[2] & 0xFF)));
				}
				else
				{
					item.rgb[2] = (ushort)(last_item[2] & 0xFF);
				}
				num2 = (item.rgb[0] >> 8) - (last_item[0] >> 8);
				if ((num & 8) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_3);
					item.rgb[1] |= (ushort)(MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[1] >> 8))) << 8);
				}
				else
				{
					item.rgb[1] |= (ushort)(last_item[1] & 0xFF00);
				}
				if ((num & 0x20) != 0)
				{
					byte b = (byte)dec_RGB.decodeSymbol(contexts[current_context].m_rgb_diff_5);
					num2 = (num2 + ((item.rgb[1] >> 8) - (last_item[1] >> 8))) / 2;
					item.rgb[2] |= (ushort)(MyDefs.U8_FOLD(b + MyDefs.U8_CLAMP(num2 + (last_item[2] >> 8))) << 8);
				}
				else
				{
					item.rgb[2] |= (ushort)(last_item[2] & 0xFF00);
				}
			}
			else
			{
				item.rgb[1] = item.rgb[0];
				item.rgb[2] = item.rgb[0];
			}
			last_item[0] = item.rgb[0];
			last_item[1] = item.rgb[1];
			last_item[2] = item.rgb[2];
		}
		else
		{
			item.rgb[0] = last_item[0];
			item.rgb[1] = last_item[1];
			item.rgb[2] = last_item[2];
		}
		if (changed_NIR)
		{
			uint num3 = dec_NIR.decodeSymbol(contexts[current_context].m_nir_bytes_used);
			if ((num3 & 1) != 0)
			{
				byte b2 = (byte)dec_NIR.decodeSymbol(contexts[current_context].m_nir_diff_0);
				item.rgb[3] = (ushort)MyDefs.U8_FOLD(b2 + (last_item[3] & 0xFF));
			}
			else
			{
				item.rgb[3] = (ushort)(last_item[3] & 0xFF);
			}
			if ((num3 & 2) != 0)
			{
				byte b2 = (byte)dec_NIR.decodeSymbol(contexts[current_context].m_nir_diff_1);
				item.rgb[3] |= (ushort)(MyDefs.U8_FOLD(b2 + (last_item[3] >> 8)) << 8);
			}
			else
			{
				item.rgb[3] |= (ushort)(last_item[3] & 0xFF00);
			}
			contexts[current_context].last_item[3] = item.rgb[3];
		}
		else
		{
			item.rgb[3] = contexts[current_context].last_item[3];
		}
	}

	private bool createAndInitModelsAndDecompressors(uint context, ushort[] item)
	{
		if (requested_RGB)
		{
			if (contexts[context].m_rgb_bytes_used == null)
			{
				contexts[context].m_rgb_bytes_used = dec_RGB.createSymbolModel(128u);
				contexts[context].m_rgb_diff_0 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_1 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_2 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_3 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_4 = dec_RGB.createSymbolModel(256u);
				contexts[context].m_rgb_diff_5 = dec_RGB.createSymbolModel(256u);
			}
			dec_RGB.initSymbolModel(contexts[context].m_rgb_bytes_used);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_0);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_1);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_2);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_3);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_4);
			dec_RGB.initSymbolModel(contexts[context].m_rgb_diff_5);
		}
		if (requested_NIR)
		{
			if (contexts[context].m_nir_bytes_used == null)
			{
				contexts[context].m_nir_bytes_used = dec_NIR.createSymbolModel(4u);
				contexts[context].m_nir_diff_0 = dec_NIR.createSymbolModel(256u);
				contexts[context].m_nir_diff_1 = dec_NIR.createSymbolModel(256u);
			}
			dec_NIR.initSymbolModel(contexts[context].m_nir_bytes_used);
			dec_NIR.initSymbolModel(contexts[context].m_nir_diff_0);
			dec_NIR.initSymbolModel(contexts[context].m_nir_diff_1);
		}
		contexts[context].last_item[0] = item[0];
		contexts[context].last_item[1] = item[1];
		contexts[context].last_item[2] = item[2];
		contexts[context].last_item[3] = item[3];
		contexts[context].unused = false;
		return true;
	}
}
internal class LASreadItemCompressed_WAVEPACKET13_v1 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private LASwavepacket13 last_item;

	private int last_diff_32;

	private uint sym_last_offset_diff;

	private ArithmeticModel m_packet_index;

	private readonly ArithmeticModel[] m_offset_diff = new ArithmeticModel[4];

	private IntegerCompressor ic_offset_diff;

	private IntegerCompressor ic_packet_size;

	private IntegerCompressor ic_return_point;

	private IntegerCompressor ic_xyz;

	public LASreadItemCompressed_WAVEPACKET13_v1(ArithmeticDecoder dec)
	{
		this.dec = dec;
		m_packet_index = dec.createSymbolModel(256u);
		m_offset_diff[0] = dec.createSymbolModel(4u);
		m_offset_diff[1] = dec.createSymbolModel(4u);
		m_offset_diff[2] = dec.createSymbolModel(4u);
		m_offset_diff[3] = dec.createSymbolModel(4u);
		ic_offset_diff = new IntegerCompressor(dec, 32u);
		ic_packet_size = new IntegerCompressor(dec, 32u);
		ic_return_point = new IntegerCompressor(dec, 32u);
		ic_xyz = new IntegerCompressor(dec, 32u, 3u);
	}

	public unsafe override bool init(laszip_point item, ref uint context)
	{
		last_diff_32 = 0;
		sym_last_offset_diff = 0u;
		dec.initSymbolModel(m_packet_index);
		dec.initSymbolModel(m_offset_diff[0]);
		dec.initSymbolModel(m_offset_diff[1]);
		dec.initSymbolModel(m_offset_diff[2]);
		dec.initSymbolModel(m_offset_diff[3]);
		ic_offset_diff.initDecompressor();
		ic_packet_size.initDecompressor();
		ic_return_point.initDecompressor();
		ic_xyz.initDecompressor();
		fixed (byte* wave_packet = item.wave_packet)
		{
			last_item = *(LASwavepacket13*)(wave_packet + 1);
		}
		return true;
	}

	public unsafe override void read(laszip_point item, ref uint context)
	{
		item.wave_packet[0] = (byte)dec.decodeSymbol(m_packet_index);
		fixed (byte* wave_packet = item.wave_packet)
		{
			LASwavepacket13* ptr = (LASwavepacket13*)(wave_packet + 1);
			sym_last_offset_diff = dec.decodeSymbol(m_offset_diff[sym_last_offset_diff]);
			if (sym_last_offset_diff == 0)
			{
				ptr->offset = last_item.offset;
			}
			else if (sym_last_offset_diff == 1)
			{
				ptr->offset = last_item.offset + last_item.packet_size;
			}
			else if (sym_last_offset_diff == 2)
			{
				last_diff_32 = ic_offset_diff.decompress(last_diff_32);
				ptr->offset = last_item.offset + (ulong)last_diff_32;
			}
			else
			{
				ptr->offset = dec.readInt64();
			}
			ptr->packet_size = (uint)ic_packet_size.decompress((int)last_item.packet_size);
			ptr->return_point.i32 = ic_return_point.decompress(last_item.return_point.i32);
			ptr->x.i32 = ic_xyz.decompress(last_item.x.i32);
			ptr->y.i32 = ic_xyz.decompress(last_item.y.i32, 1u);
			ptr->z.i32 = ic_xyz.decompress(last_item.z.i32, 2u);
			last_item = *ptr;
		}
	}
}
internal class LASreadItemCompressed_WAVEPACKET14_v3 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private MemoryStream instream_wavepacket;

	private ArithmeticDecoder dec_wavepacket;

	private bool changed_wavepacket;

	private int num_bytes_wavepacket;

	private bool requested_wavepacket;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextWAVEPACKET14[] contexts = new LAScontextWAVEPACKET14[4]
	{
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14()
	};

	public LASreadItemCompressed_WAVEPACKET14_v3(ArithmeticDecoder dec, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		instream_wavepacket = null;
		dec_wavepacket = null;
		num_bytes_wavepacket = 0;
		changed_wavepacket = false;
		requested_wavepacket = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.WAVEPACKET);
		bytes = null;
		num_bytes_allocated = 0;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_packet_index = null;
		}
		current_context = 0u;
	}

	public override bool chunk_sizes()
	{
		if (!dec.getByteStreamIn().get32bits(out num_bytes_wavepacket))
		{
			throw new EndOfStreamException();
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_wavepacket == null)
		{
			dec_wavepacket = new ArithmeticDecoder();
		}
		if (num_bytes_wavepacket > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num_bytes_wavepacket];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num_bytes_wavepacket;
		}
		if (requested_wavepacket)
		{
			if (num_bytes_wavepacket != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num_bytes_wavepacket))
				{
					throw new EndOfStreamException();
				}
				instream_wavepacket = new MemoryStream(bytes, 0, num_bytes_wavepacket);
				dec_wavepacket.init(instream_wavepacket);
				changed_wavepacket = true;
			}
			else
			{
				instream_wavepacket = new MemoryStream(0);
				changed_wavepacket = false;
			}
		}
		else
		{
			if (num_bytes_wavepacket != 0)
			{
				byteStreamIn.Seek(num_bytes_wavepacket, SeekOrigin.Current);
			}
			changed_wavepacket = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndDecompressors(current_context, item.wave_packet);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		byte[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndDecompressors(current_context, last_item);
				last_item = contexts[current_context].last_item;
			}
		}
		if (changed_wavepacket)
		{
			item.wave_packet[0] = (byte)dec_wavepacket.decodeSymbol(contexts[current_context].m_packet_index);
			LASwavepacket13 lASwavepacket = default(LASwavepacket13);
			LASwavepacket13 lASwavepacket2 = LASwavepacket13.unpack(last_item, 1);
			contexts[current_context].sym_last_offset_diff = dec_wavepacket.decodeSymbol(contexts[current_context].m_offset_diff[contexts[current_context].sym_last_offset_diff]);
			if (contexts[current_context].sym_last_offset_diff == 0)
			{
				lASwavepacket.offset = lASwavepacket2.offset;
			}
			else if (contexts[current_context].sym_last_offset_diff == 1)
			{
				lASwavepacket.offset = lASwavepacket2.offset + lASwavepacket2.packet_size;
			}
			else if (contexts[current_context].sym_last_offset_diff == 2)
			{
				contexts[current_context].last_diff_32 = contexts[current_context].ic_offset_diff.decompress(contexts[current_context].last_diff_32);
				lASwavepacket.offset = lASwavepacket2.offset + (ulong)contexts[current_context].last_diff_32;
			}
			else
			{
				lASwavepacket.offset = dec_wavepacket.readInt64();
			}
			lASwavepacket.packet_size = (uint)contexts[current_context].ic_packet_size.decompress((int)lASwavepacket2.packet_size);
			lASwavepacket.return_point.i32 = contexts[current_context].ic_return_point.decompress(lASwavepacket2.return_point.i32);
			lASwavepacket.x.i32 = contexts[current_context].ic_xyz.decompress(lASwavepacket2.x.i32);
			lASwavepacket.y.i32 = contexts[current_context].ic_xyz.decompress(lASwavepacket2.y.i32, 1u);
			lASwavepacket.z.i32 = contexts[current_context].ic_xyz.decompress(lASwavepacket2.z.i32, 2u);
			lASwavepacket.pack(item.wave_packet, 1);
			item.wave_packet.CopyTo(last_item, 0);
		}
	}

	private bool createAndInitModelsAndDecompressors(uint context, byte[] item)
	{
		if (requested_wavepacket)
		{
			if (contexts[context].m_packet_index == null)
			{
				contexts[context].m_packet_index = dec_wavepacket.createSymbolModel(256u);
				contexts[context].m_offset_diff[0] = dec_wavepacket.createSymbolModel(4u);
				contexts[context].m_offset_diff[1] = dec_wavepacket.createSymbolModel(4u);
				contexts[context].m_offset_diff[2] = dec_wavepacket.createSymbolModel(4u);
				contexts[context].m_offset_diff[3] = dec_wavepacket.createSymbolModel(4u);
				contexts[context].ic_offset_diff = new IntegerCompressor(dec_wavepacket, 32u);
				contexts[context].ic_packet_size = new IntegerCompressor(dec_wavepacket, 32u);
				contexts[context].ic_return_point = new IntegerCompressor(dec_wavepacket, 32u);
				contexts[context].ic_xyz = new IntegerCompressor(dec_wavepacket, 32u, 3u);
			}
			dec_wavepacket.initSymbolModel(contexts[context].m_packet_index);
			dec_wavepacket.initSymbolModel(contexts[context].m_offset_diff[0]);
			dec_wavepacket.initSymbolModel(contexts[context].m_offset_diff[1]);
			dec_wavepacket.initSymbolModel(contexts[context].m_offset_diff[2]);
			dec_wavepacket.initSymbolModel(contexts[context].m_offset_diff[3]);
			contexts[context].ic_offset_diff.initDecompressor();
			contexts[context].ic_packet_size.initDecompressor();
			contexts[context].ic_return_point.initDecompressor();
			contexts[context].ic_xyz.initDecompressor();
		}
		contexts[context].last_diff_32 = 0;
		contexts[context].sym_last_offset_diff = 0u;
		item.CopyTo(contexts[context].last_item, 0);
		contexts[context].unused = false;
		return true;
	}
}
internal class LASreadItemCompressed_WAVEPACKET14_v4 : LASreadItemCompressed
{
	private ArithmeticDecoder dec;

	private MemoryStream instream_wavepacket;

	private ArithmeticDecoder dec_wavepacket;

	private bool changed_wavepacket;

	private int num_bytes_wavepacket;

	private bool requested_wavepacket;

	private byte[] bytes;

	private int num_bytes_allocated;

	private uint current_context;

	private readonly LAScontextWAVEPACKET14[] contexts = new LAScontextWAVEPACKET14[4]
	{
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14()
	};

	public LASreadItemCompressed_WAVEPACKET14_v4(ArithmeticDecoder dec, LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		this.dec = dec;
		instream_wavepacket = null;
		dec_wavepacket = null;
		num_bytes_wavepacket = 0;
		changed_wavepacket = false;
		requested_wavepacket = decompress_selective.HasFlag(LASZIP_DECOMPRESS_SELECTIVE.WAVEPACKET);
		bytes = null;
		num_bytes_allocated = 0;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_packet_index = null;
		}
		current_context = 0u;
	}

	public override bool chunk_sizes()
	{
		if (!dec.getByteStreamIn().get32bits(out num_bytes_wavepacket))
		{
			throw new EndOfStreamException();
		}
		return true;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		Stream byteStreamIn = dec.getByteStreamIn();
		if (instream_wavepacket == null)
		{
			dec_wavepacket = new ArithmeticDecoder();
		}
		if (num_bytes_wavepacket > num_bytes_allocated)
		{
			try
			{
				bytes = new byte[num_bytes_wavepacket];
			}
			catch
			{
				return false;
			}
			num_bytes_allocated = num_bytes_wavepacket;
		}
		if (requested_wavepacket)
		{
			if (num_bytes_wavepacket != 0)
			{
				if (!byteStreamIn.getBytes(bytes, num_bytes_wavepacket))
				{
					throw new EndOfStreamException();
				}
				instream_wavepacket = new MemoryStream(bytes, 0, num_bytes_wavepacket);
				dec_wavepacket.init(instream_wavepacket);
				changed_wavepacket = true;
			}
			else
			{
				instream_wavepacket = new MemoryStream(0);
				changed_wavepacket = false;
			}
		}
		else
		{
			if (num_bytes_wavepacket != 0)
			{
				byteStreamIn.Seek(num_bytes_wavepacket, SeekOrigin.Current);
			}
			changed_wavepacket = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndDecompressors(current_context, item.wave_packet);
		return true;
	}

	public override void read(laszip_point item, ref uint context)
	{
		byte[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndDecompressors(current_context, last_item);
			}
			last_item = contexts[current_context].last_item;
		}
		if (changed_wavepacket)
		{
			item.wave_packet[0] = (byte)dec_wavepacket.decodeSymbol(contexts[current_context].m_packet_index);
			LASwavepacket13 lASwavepacket = default(LASwavepacket13);
			LASwavepacket13 lASwavepacket2 = LASwavepacket13.unpack(last_item, 1);
			contexts[current_context].sym_last_offset_diff = dec_wavepacket.decodeSymbol(contexts[current_context].m_offset_diff[contexts[current_context].sym_last_offset_diff]);
			if (contexts[current_context].sym_last_offset_diff == 0)
			{
				lASwavepacket.offset = lASwavepacket2.offset;
			}
			else if (contexts[current_context].sym_last_offset_diff == 1)
			{
				lASwavepacket.offset = lASwavepacket2.offset + lASwavepacket2.packet_size;
			}
			else if (contexts[current_context].sym_last_offset_diff == 2)
			{
				contexts[current_context].last_diff_32 = contexts[current_context].ic_offset_diff.decompress(contexts[current_context].last_diff_32);
				lASwavepacket.offset = lASwavepacket2.offset + (ulong)contexts[current_context].last_diff_32;
			}
			else
			{
				lASwavepacket.offset = dec_wavepacket.readInt64();
			}
			lASwavepacket.packet_size = (uint)contexts[current_context].ic_packet_size.decompress((int)lASwavepacket2.packet_size);
			lASwavepacket.return_point.i32 = contexts[current_context].ic_return_point.decompress(lASwavepacket2.return_point.i32);
			lASwavepacket.x.i32 = contexts[current_context].ic_xyz.decompress(lASwavepacket2.x.i32);
			lASwavepacket.y.i32 = contexts[current_context].ic_xyz.decompress(lASwavepacket2.y.i32, 1u);
			lASwavepacket.z.i32 = contexts[current_context].ic_xyz.decompress(lASwavepacket2.z.i32, 2u);
			lASwavepacket.pack(item.wave_packet, 1);
			item.wave_packet.CopyTo(last_item, 0);
		}
	}

	private bool createAndInitModelsAndDecompressors(uint context, byte[] item)
	{
		if (requested_wavepacket)
		{
			if (contexts[context].m_packet_index == null)
			{
				contexts[context].m_packet_index = dec_wavepacket.createSymbolModel(256u);
				contexts[context].m_offset_diff[0] = dec_wavepacket.createSymbolModel(4u);
				contexts[context].m_offset_diff[1] = dec_wavepacket.createSymbolModel(4u);
				contexts[context].m_offset_diff[2] = dec_wavepacket.createSymbolModel(4u);
				contexts[context].m_offset_diff[3] = dec_wavepacket.createSymbolModel(4u);
				contexts[context].ic_offset_diff = new IntegerCompressor(dec_wavepacket, 32u);
				contexts[context].ic_packet_size = new IntegerCompressor(dec_wavepacket, 32u);
				contexts[context].ic_return_point = new IntegerCompressor(dec_wavepacket, 32u);
				contexts[context].ic_xyz = new IntegerCompressor(dec_wavepacket, 32u, 3u);
			}
			dec_wavepacket.initSymbolModel(contexts[context].m_packet_index);
			dec_wavepacket.initSymbolModel(contexts[context].m_offset_diff[0]);
			dec_wavepacket.initSymbolModel(contexts[context].m_offset_diff[1]);
			dec_wavepacket.initSymbolModel(contexts[context].m_offset_diff[2]);
			dec_wavepacket.initSymbolModel(contexts[context].m_offset_diff[3]);
			contexts[context].ic_offset_diff.initDecompressor();
			contexts[context].ic_packet_size.initDecompressor();
			contexts[context].ic_return_point.initDecompressor();
			contexts[context].ic_xyz.initDecompressor();
		}
		contexts[context].last_diff_32 = 0;
		contexts[context].sym_last_offset_diff = 0u;
		item.CopyTo(contexts[context].last_item, 0);
		contexts[context].unused = false;
		return true;
	}
}
internal abstract class LASreadItemRaw : LASreadItem
{
	protected Stream instream;

	public bool init(Stream instream)
	{
		if (instream == null)
		{
			return false;
		}
		this.instream = instream;
		return true;
	}
}
internal class LASreadItemRaw_BYTE : LASreadItemRaw
{
	private uint number;

	public LASreadItemRaw_BYTE(uint number)
	{
		this.number = number;
	}

	public override void read(laszip_point item, ref uint context)
	{
		if (!instream.getBytes(item.extra_bytes, (int)number))
		{
			throw new EndOfStreamException();
		}
	}
}
internal class LASreadItemRaw_GPSTIME11 : LASreadItemRaw
{
	public override void read(laszip_point item, ref uint context)
	{
		if (!instream.get64bits(out item.gps_time))
		{
			throw new EndOfStreamException();
		}
	}
}
internal class LASreadItemRaw_POINT10 : LASreadItemRaw
{
	private readonly byte[] buffer = new byte[20];

	public unsafe override void read(laszip_point item, ref uint context)
	{
		if (!instream.getBytes(buffer, 20))
		{
			throw new EndOfStreamException();
		}
		fixed (byte* ptr = buffer)
		{
			LASpoint10* ptr2 = (LASpoint10*)ptr;
			item.X = ptr2->X;
			item.Y = ptr2->Y;
			item.Z = ptr2->Z;
			item.intensity = ptr2->intensity;
			item.flags = ptr2->flags;
			item.classification_and_classification_flags = ptr2->classification_and_classification_flags;
			item.scan_angle_rank = ptr2->scan_angle_rank;
			item.user_data = ptr2->user_data;
			item.point_source_ID = ptr2->point_source_ID;
		}
	}
}
internal class LASreadItemRaw_POINT14 : LASreadItemRaw
{
	private readonly byte[] buffer = new byte[30];

	public unsafe override void read(laszip_point item, ref uint context)
	{
		if (!instream.getBytes(buffer, 30))
		{
			throw new EndOfStreamException();
		}
		fixed (byte* ptr = buffer)
		{
			LASpoint14* ptr2 = (LASpoint14*)ptr;
			item.X = ptr2->X;
			item.Y = ptr2->Y;
			item.Z = ptr2->Z;
			item.intensity = ptr2->intensity;
			byte b = (byte)(ptr2->returns & 0xF);
			byte b2 = (byte)((ptr2->returns >> 4) & 0xF);
			if (b2 > 7)
			{
				if (b > 6)
				{
					if (b >= b2)
					{
						item.number_of_returns = 7;
					}
					else
					{
						item.number_of_returns = 6;
					}
				}
				else
				{
					item.return_number = b;
				}
				item.number_of_returns = 7;
			}
			else
			{
				item.return_number = b;
				item.number_of_returns = b2;
			}
			item.scan_direction_flag = (byte)((ptr2->flags >> 6) & 1);
			item.edge_of_flight_line = (byte)((ptr2->flags >> 7) & 1);
			item.classification_and_classification_flags = (byte)((ptr2->flags << 5) & 0xE0);
			if (ptr2->classification < 32)
			{
				item.classification_and_classification_flags |= ptr2->classification;
			}
			item.scan_angle_rank = MyDefs.I8_CLAMP(MyDefs.I16_QUANTIZE(0.006 * (double)ptr2->scan_angle));
			item.user_data = ptr2->user_data;
			item.point_source_ID = ptr2->point_source_ID;
			item.extended_scanner_channel = (byte)((ptr2->flags >> 4) & 3);
			item.extended_classification_flags = (byte)(ptr2->flags & 0xF);
			item.extended_classification = ptr2->classification;
			item.extended_return_number = b;
			item.extended_number_of_returns = b2;
			item.extended_scan_angle = ptr2->scan_angle;
			item.gps_time = ptr2->gps_time;
		}
	}
}
internal class LASreadItemRaw_RGB12 : LASreadItemRaw
{
	public override void read(laszip_point item, ref uint context)
	{
		if (!instream.get16bits(item.rgb, 3))
		{
			throw new EndOfStreamException();
		}
	}
}
internal class LASreadItemRaw_RGBNIR14 : LASreadItemRaw
{
	public override void read(laszip_point item, ref uint context)
	{
		if (!instream.get16bits(item.rgb, 4))
		{
			throw new EndOfStreamException();
		}
	}
}
internal class LASreadItemRaw_WAVEPACKET13 : LASreadItemRaw
{
	public override void read(laszip_point item, ref uint context)
	{
		if (!instream.getBytes(item.wave_packet, 29))
		{
			throw new EndOfStreamException();
		}
	}
}
internal class LASreadPoint
{
	private Stream instream;

	private uint num_readers;

	private LASreadItem[] readers;

	private LASreadItem[] readers_raw;

	private LASreadItem[] readers_compressed;

	private ArithmeticDecoder dec;

	private bool layered_las14_compression;

	private uint chunk_size;

	private uint chunk_count;

	private uint current_chunk;

	private uint number_chunks;

	private uint tabled_chunks;

	private List<long> chunk_starts;

	private uint[] chunk_totals;

	private LASZIP_DECOMPRESS_SELECTIVE decompress_selective;

	private long point_start;

	private uint point_size;

	private laszip_point seek_point = new laszip_point();

	private string last_error;

	private string last_warning;

	public LASreadPoint(LASZIP_DECOMPRESS_SELECTIVE decompress_selective = LASZIP_DECOMPRESS_SELECTIVE.ALL)
	{
		point_size = 0u;
		instream = null;
		num_readers = 0u;
		readers = null;
		readers_raw = null;
		readers_compressed = null;
		dec = null;
		layered_las14_compression = false;
		chunk_size = uint.MaxValue;
		chunk_count = 0u;
		current_chunk = 0u;
		number_chunks = 0u;
		tabled_chunks = 0u;
		chunk_totals = null;
		chunk_starts = null;
		this.decompress_selective = decompress_selective;
		point_start = 0L;
		last_error = null;
		last_warning = null;
	}

	public bool setup(uint num_items, LASitem[] items, LASzip laszip = null)
	{
		if (laszip != null)
		{
			if (num_items == 0)
			{
				return false;
			}
			if (items == null)
			{
				return false;
			}
			if (num_items != laszip.num_items)
			{
				return false;
			}
			if (items != laszip.items)
			{
				return false;
			}
		}
		if (dec != null)
		{
			dec = null;
			layered_las14_compression = false;
		}
		if (laszip != null && laszip.compressor != 0)
		{
			if (laszip.coder != 0)
			{
				return false;
			}
			dec = new ArithmeticDecoder();
			layered_las14_compression = laszip.compressor == 3;
		}
		readers = null;
		num_readers = num_items;
		chunk_size = uint.MaxValue;
		readers_raw = new LASreadItem[num_readers];
		for (int i = 0; i < num_readers; i++)
		{
			switch (items[i].type)
			{
			case LASitem.Type.POINT10:
				readers_raw[i] = new LASreadItemRaw_POINT10();
				break;
			case LASitem.Type.GPSTIME11:
				readers_raw[i] = new LASreadItemRaw_GPSTIME11();
				break;
			case LASitem.Type.RGB12:
			case LASitem.Type.RGB14:
				readers_raw[i] = new LASreadItemRaw_RGB12();
				break;
			case LASitem.Type.BYTE:
			case LASitem.Type.BYTE14:
				readers_raw[i] = new LASreadItemRaw_BYTE(items[i].size);
				break;
			case LASitem.Type.POINT14:
				readers_raw[i] = new LASreadItemRaw_POINT14();
				break;
			case LASitem.Type.RGBNIR14:
				readers_raw[i] = new LASreadItemRaw_RGBNIR14();
				break;
			case LASitem.Type.WAVEPACKET13:
			case LASitem.Type.WAVEPACKET14:
				readers_raw[i] = new LASreadItemRaw_WAVEPACKET13();
				break;
			default:
				return false;
			}
			point_size += items[i].size;
		}
		if (dec != null)
		{
			readers_compressed = new LASreadItem[num_readers];
			seek_point = new laszip_point();
			if (layered_las14_compression)
			{
				seek_point.extended_point_type = 1;
			}
			for (int j = 0; j < num_readers; j++)
			{
				switch (items[j].type)
				{
				case LASitem.Type.POINT10:
					if (items[j].version == 1)
					{
						readers_compressed[j] = new LASreadItemCompressed_POINT10_v1(dec);
						break;
					}
					if (items[j].version == 2)
					{
						readers_compressed[j] = new LASreadItemCompressed_POINT10_v2(dec);
						break;
					}
					return false;
				case LASitem.Type.GPSTIME11:
					if (items[j].version == 1)
					{
						readers_compressed[j] = new LASreadItemCompressed_GPSTIME11_v1(dec);
						break;
					}
					if (items[j].version == 2)
					{
						readers_compressed[j] = new LASreadItemCompressed_GPSTIME11_v2(dec);
						break;
					}
					return false;
				case LASitem.Type.RGB12:
					if (items[j].version == 1)
					{
						readers_compressed[j] = new LASreadItemCompressed_RGB12_v1(dec);
						break;
					}
					if (items[j].version == 2)
					{
						readers_compressed[j] = new LASreadItemCompressed_RGB12_v2(dec);
						break;
					}
					return false;
				case LASitem.Type.BYTE:
					seek_point.extra_bytes = new byte[items[j].size];
					seek_point.num_extra_bytes = items[j].size;
					if (items[j].version == 1)
					{
						readers_compressed[j] = new LASreadItemCompressed_BYTE_v1(dec, items[j].size);
						break;
					}
					if (items[j].version == 2)
					{
						readers_compressed[j] = new LASreadItemCompressed_BYTE_v2(dec, items[j].size);
						break;
					}
					return false;
				case LASitem.Type.POINT14:
					if (items[j].version == 3 || items[j].version == 2)
					{
						readers_compressed[j] = new LASreadItemCompressed_POINT14_v3(dec, decompress_selective);
						break;
					}
					if (items[j].version == 4)
					{
						readers_compressed[j] = new LASreadItemCompressed_POINT14_v4(dec, decompress_selective);
						break;
					}
					return false;
				case LASitem.Type.RGB14:
					if (items[j].version == 3 || items[j].version == 2)
					{
						readers_compressed[j] = new LASreadItemCompressed_RGB14_v3(dec, decompress_selective);
						break;
					}
					if (items[j].version == 4)
					{
						readers_compressed[j] = new LASreadItemCompressed_RGB14_v4(dec, decompress_selective);
						break;
					}
					return false;
				case LASitem.Type.RGBNIR14:
					if (items[j].version == 3 || items[j].version == 2)
					{
						readers_compressed[j] = new LASreadItemCompressed_RGBNIR14_v3(dec, decompress_selective);
						break;
					}
					if (items[j].version == 4)
					{
						readers_compressed[j] = new LASreadItemCompressed_RGBNIR14_v4(dec, decompress_selective);
						break;
					}
					return false;
				case LASitem.Type.BYTE14:
					seek_point.extra_bytes = new byte[items[j].size];
					seek_point.num_extra_bytes = items[j].size;
					if (items[j].version == 3 || items[j].version == 2)
					{
						readers_compressed[j] = new LASreadItemCompressed_BYTE14_v3(dec, items[j].size, decompress_selective);
						break;
					}
					if (items[j].version == 4)
					{
						readers_compressed[j] = new LASreadItemCompressed_BYTE14_v4(dec, items[j].size, decompress_selective);
						break;
					}
					return false;
				case LASitem.Type.WAVEPACKET13:
					if (items[j].version == 1)
					{
						readers_compressed[j] = new LASreadItemCompressed_WAVEPACKET13_v1(dec);
						break;
					}
					return false;
				case LASitem.Type.WAVEPACKET14:
					if (items[j].version == 3)
					{
						readers_compressed[j] = new LASreadItemCompressed_WAVEPACKET14_v3(dec, decompress_selective);
						break;
					}
					if (items[j].version == 4)
					{
						readers_compressed[j] = new LASreadItemCompressed_WAVEPACKET14_v4(dec, decompress_selective);
						break;
					}
					return false;
				default:
					return false;
				}
			}
			if (laszip.compressor != 1)
			{
				if (laszip.chunk_size != 0)
				{
					chunk_size = laszip.chunk_size;
				}
				number_chunks = uint.MaxValue;
			}
		}
		return true;
	}

	public bool init(Stream instream)
	{
		if (instream == null)
		{
			return false;
		}
		this.instream = instream;
		for (int i = 0; i < num_readers; i++)
		{
			((LASreadItemRaw)readers_raw[i]).init(instream);
		}
		if (dec != null)
		{
			chunk_count = chunk_size;
			point_start = 0L;
			readers = null;
		}
		else
		{
			point_start = instream.Position;
			readers = readers_raw;
		}
		return true;
	}

	public bool seek(uint current, uint target)
	{
		if (!instream.CanSeek)
		{
			return false;
		}
		uint num = 0u;
		if (dec != null)
		{
			if (point_start == 0L)
			{
				init_dec();
				chunk_count = 0u;
			}
			if (chunk_starts != null)
			{
				uint num2;
				if (chunk_totals != null)
				{
					num2 = search_chunk_table(target, 0u, number_chunks);
					chunk_size = chunk_totals[num2 + 1] - chunk_totals[num2];
					num = target - chunk_totals[num2];
				}
				else
				{
					num2 = target / chunk_size;
					num = target % chunk_size;
				}
				if (num2 >= tabled_chunks)
				{
					if (current_chunk < tabled_chunks - 1)
					{
						dec.done();
						current_chunk = tabled_chunks - 1;
						instream.Seek(chunk_starts[(int)current_chunk], SeekOrigin.Begin);
						init_dec();
						chunk_count = 0u;
					}
					num += chunk_size * (num2 - current_chunk) - chunk_count;
				}
				else if (current_chunk != num2 || current > target)
				{
					dec.done();
					current_chunk = num2;
					instream.Seek(chunk_starts[(int)current_chunk], SeekOrigin.Begin);
					init_dec();
					chunk_count = 0u;
				}
				else
				{
					num = target - current;
				}
			}
			else if (current > target)
			{
				dec.done();
				instream.Seek(point_start, SeekOrigin.Begin);
				init_dec();
				num = target;
			}
			else if (current < target)
			{
				num = target - current;
			}
			while (num != 0)
			{
				read(seek_point);
				num--;
			}
		}
		else if (current != target)
		{
			instream.Seek(point_start + (long)point_size * (long)target, SeekOrigin.Begin);
		}
		return true;
	}

	public bool read(laszip_point point)
	{
		uint context = 0u;
		try
		{
			if (dec != null)
			{
				if (chunk_count == chunk_size)
				{
					if (point_start != 0L)
					{
						dec.done();
						current_chunk++;
						if (current_chunk < tabled_chunks)
						{
							long position = instream.Position;
							if (chunk_starts[(int)current_chunk] != position)
							{
								current_chunk--;
								throw new Exception("4711");
							}
						}
					}
					init_dec();
					if (tabled_chunks == current_chunk)
					{
						if (tabled_chunks == 0 && chunk_starts == null)
						{
							chunk_starts = new List<long>();
						}
						chunk_starts.Add(point_start);
						number_chunks++;
						tabled_chunks++;
					}
					else if (chunk_totals != null)
					{
						chunk_size = chunk_totals[current_chunk + 1] - chunk_totals[current_chunk];
					}
					chunk_count = 0u;
				}
				chunk_count++;
				if (readers != null)
				{
					for (int i = 0; i < num_readers; i++)
					{
						readers[i].read(point, ref context);
					}
				}
				else
				{
					for (int j = 0; j < num_readers; j++)
					{
						readers_raw[j].read(point, ref context);
					}
					if (layered_las14_compression)
					{
						dec.init(instream, really_init: false);
						if (!instream.get32bits(out uint _))
						{
							throw new EndOfStreamException();
						}
						for (int k = 0; k < num_readers; k++)
						{
							((LASreadItemCompressed)readers_compressed[k]).chunk_sizes();
						}
						for (int l = 0; l < num_readers; l++)
						{
							((LASreadItemCompressed)readers_compressed[l]).init(point, ref context);
						}
					}
					else
					{
						for (int m = 0; m < num_readers; m++)
						{
							((LASreadItemCompressed)readers_compressed[m]).init(point, ref context);
						}
						dec.init(instream);
					}
					readers = readers_compressed;
				}
			}
			else
			{
				for (int n = 0; n < num_readers; n++)
				{
					readers[n].read(point, ref context);
				}
			}
		}
		catch (EndOfStreamException)
		{
			if (dec != null)
			{
				last_error = "end-of-file during chunk " + current_chunk;
			}
			else
			{
				last_error = "end-of-file";
			}
			return false;
		}
		catch
		{
			last_error = $"chunk {current_chunk} of {tabled_chunks} is corrupt";
			if (current_chunk + 1 < tabled_chunks)
			{
				instream.Seek(chunk_starts[(int)(current_chunk + 1)], SeekOrigin.Begin);
				chunk_count = chunk_size;
			}
			return false;
		}
		return true;
	}

	public bool check_end()
	{
		if (readers == readers_compressed && dec != null)
		{
			dec.done();
			current_chunk++;
			if (current_chunk < tabled_chunks)
			{
				long position = instream.Position;
				if (chunk_starts[(int)current_chunk] != position)
				{
					last_error = $"chunk with index {current_chunk} of {tabled_chunks} is corrupt";
					return false;
				}
			}
		}
		return true;
	}

	public bool done()
	{
		instream = null;
		return true;
	}

	public string error()
	{
		return last_error;
	}

	public string warning()
	{
		return last_warning;
	}

	private bool init_dec()
	{
		if (number_chunks == uint.MaxValue)
		{
			if (!read_chunk_table())
			{
				return false;
			}
			current_chunk = 0u;
			if (chunk_totals != null)
			{
				chunk_size = chunk_totals[1];
			}
		}
		point_start = instream.Position;
		readers = null;
		return true;
	}

	private bool read_chunk_table()
	{
		long val;
		try
		{
			if (!instream.get64bits(out val))
			{
				throw new EndOfStreamException();
			}
		}
		catch
		{
			return false;
		}
		long position = instream.Position;
		if (val + 8 == position)
		{
			if (chunk_size == uint.MaxValue)
			{
				return false;
			}
			number_chunks = 0u;
			chunk_starts = new List<long>();
			chunk_starts.Add(position);
			number_chunks++;
			tabled_chunks = 1u;
			return true;
		}
		if (!instream.CanSeek)
		{
			if (chunk_size == uint.MaxValue)
			{
				return false;
			}
			number_chunks = 4294967294u;
			tabled_chunks = 0u;
			return true;
		}
		if (val == -1)
		{
			if (instream.Seek(-8L, SeekOrigin.End) == 0L)
			{
				return false;
			}
			try
			{
				if (!instream.get64bits(out val))
				{
					throw new EndOfStreamException();
				}
			}
			catch
			{
				return false;
			}
		}
		try
		{
			instream.Seek(val, SeekOrigin.Begin);
			if (!instream.get32bits(out uint val2))
			{
				throw new EndOfStreamException();
			}
			if (val2 != 0)
			{
				throw new Exception();
			}
			if (!instream.get32bits(out number_chunks))
			{
				throw new EndOfStreamException();
			}
			chunk_totals = null;
			chunk_starts = null;
			if (chunk_size == uint.MaxValue)
			{
				chunk_totals = new uint[number_chunks + 1];
				chunk_totals[0] = 0u;
			}
			chunk_starts = new List<long>();
			chunk_starts.Add(position);
			tabled_chunks = 1u;
			if (number_chunks != 0)
			{
				dec.init(instream);
				IntegerCompressor integerCompressor = new IntegerCompressor(dec, 32u, 2u);
				integerCompressor.initDecompressor();
				for (int i = 1; i <= number_chunks; i++)
				{
					if (chunk_size == uint.MaxValue)
					{
						chunk_totals[i] = (uint)integerCompressor.decompress((int)((i > 1) ? chunk_totals[i - 1] : 0));
					}
					chunk_starts.Add(integerCompressor.decompress((int)((i > 1) ? chunk_starts[i - 1] : 0), 1u));
					tabled_chunks++;
				}
				dec.done();
				for (int j = 1; j <= number_chunks; j++)
				{
					if (chunk_size == uint.MaxValue)
					{
						chunk_totals[j] += chunk_totals[j - 1];
					}
					chunk_starts[j] += chunk_starts[j - 1];
					if (chunk_starts[j] <= chunk_starts[j - 1])
					{
						throw new Exception();
					}
				}
			}
		}
		catch
		{
			chunk_totals = null;
			if (chunk_size == uint.MaxValue)
			{
				return false;
			}
			if (number_chunks == uint.MaxValue)
			{
				number_chunks = 0u;
				chunk_starts = new List<long>();
				chunk_starts.Add(position);
				number_chunks++;
				tabled_chunks = 1u;
			}
			else
			{
				for (int k = 1; k < tabled_chunks; k++)
				{
					chunk_starts[k] += chunk_starts[k - 1];
				}
			}
			last_warning = "corrupt chunk table";
		}
		if (instream.Seek(position, SeekOrigin.Begin) == 0L)
		{
			return false;
		}
		return true;
	}

	private uint search_chunk_table(uint index, uint lower, uint upper)
	{
		if (lower + 1 == upper)
		{
			return lower;
		}
		uint num = (lower + upper) / 2;
		if (index >= chunk_totals[num])
		{
			return search_chunk_table(index, num, upper);
		}
		return search_chunk_table(index, lower, num);
	}
}
public abstract class LASwriteItem
{
	public abstract bool write(laszip_point item, ref uint context);
}
internal abstract class LASwriteItemCompressed : LASwriteItem
{
	public abstract bool init(laszip_point item, ref uint context);

	public virtual bool chunk_sizes()
	{
		return false;
	}

	public virtual bool chunk_bytes()
	{
		return false;
	}
}
internal class LASwriteItemCompressed_BYTE14_v4 : LASwriteItemCompressed
{
	private ArithmeticEncoder enc;

	private MemoryStream[] outstream_Bytes;

	private ArithmeticEncoder[] enc_Bytes;

	private uint[] num_bytes_Bytes;

	private bool[] changed_Bytes;

	private uint current_context;

	private readonly LAScontextBYTE14[] contexts = new LAScontextBYTE14[4]
	{
		new LAScontextBYTE14(),
		new LAScontextBYTE14(),
		new LAScontextBYTE14(),
		new LAScontextBYTE14()
	};

	private uint number;

	public LASwriteItemCompressed_BYTE14_v4(ArithmeticEncoder enc, uint number)
	{
		this.enc = enc;
		this.number = number;
		outstream_Bytes = null;
		enc_Bytes = null;
		num_bytes_Bytes = new uint[number];
		changed_Bytes = new bool[number];
		for (uint num = 0u; num < number; num++)
		{
			num_bytes_Bytes[num] = 0u;
			changed_Bytes[num] = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_bytes = null;
		}
		current_context = 0u;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		if (outstream_Bytes == null)
		{
			outstream_Bytes = new MemoryStream[number];
			for (uint num = 0u; num < number; num++)
			{
				outstream_Bytes[num] = new MemoryStream();
			}
			enc_Bytes = new ArithmeticEncoder[number];
			for (uint num2 = 0u; num2 < number; num2++)
			{
				enc_Bytes[num2] = new ArithmeticEncoder();
			}
		}
		else
		{
			for (uint num3 = 0u; num3 < number; num3++)
			{
				outstream_Bytes[num3].Seek(0L, SeekOrigin.Begin);
			}
		}
		for (uint num4 = 0u; num4 < number; num4++)
		{
			enc_Bytes[num4].init(outstream_Bytes[num4]);
		}
		for (uint num5 = 0u; num5 < number; num5++)
		{
			changed_Bytes[num5] = false;
		}
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndCompressors(current_context, item.extra_bytes);
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		byte[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndCompressors(current_context, last_item);
			}
			last_item = contexts[current_context].last_item;
		}
		for (uint num = 0u; num < number; num++)
		{
			int num2 = item.extra_bytes[num] - last_item[num];
			enc_Bytes[num].encodeSymbol(contexts[current_context].m_bytes[num], (uint)MyDefs.U8_FOLD(num2));
			if (num2 != 0)
			{
				changed_Bytes[num] = true;
				last_item[num] = item.extra_bytes[num];
			}
		}
		return true;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		for (uint num = 0u; num < number; num++)
		{
			enc_Bytes[num].done();
			uint num2 = 0u;
			if (changed_Bytes[num])
			{
				num2 = (uint)outstream_Bytes[num].Position;
				num_bytes_Bytes[num] += num2;
			}
			byteStreamOut.Write(BitConverter.GetBytes(num2), 0, 4);
		}
		return true;
	}

	public override bool chunk_bytes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		for (uint num = 0u; num < number; num++)
		{
			if (changed_Bytes[num])
			{
				byteStreamOut.Write(outstream_Bytes[num].GetBuffer(), 0, (int)outstream_Bytes[num].Position);
			}
		}
		return true;
	}

	private bool createAndInitModelsAndCompressors(uint context, byte[] item)
	{
		if (contexts[context].m_bytes == null)
		{
			contexts[context].m_bytes = new ArithmeticModel[number];
			for (uint num = 0u; num < number; num++)
			{
				contexts[context].m_bytes[num] = enc_Bytes[num].createSymbolModel(256u);
				enc_Bytes[num].initSymbolModel(contexts[context].m_bytes[num]);
			}
			contexts[context].last_item = new byte[number];
		}
		for (uint num2 = 0u; num2 < number; num2++)
		{
			enc_Bytes[num2].initSymbolModel(contexts[context].m_bytes[num2]);
		}
		Array.Copy(item, contexts[context].last_item, number);
		contexts[context].unused = false;
		return true;
	}
}
internal class LASwriteItemCompressed_BYTE_v2 : LASwriteItemCompressed
{
	private ArithmeticEncoder enc;

	private uint number;

	private readonly byte[] last_item;

	private readonly ArithmeticModel[] m_byte;

	public LASwriteItemCompressed_BYTE_v2(ArithmeticEncoder enc, uint number)
	{
		this.enc = enc;
		this.number = number;
		m_byte = new ArithmeticModel[number];
		for (uint num = 0u; num < number; num++)
		{
			m_byte[num] = enc.createSymbolModel(256u);
		}
		last_item = new byte[number];
	}

	public override bool init(laszip_point item, ref uint context)
	{
		for (uint num = 0u; num < number; num++)
		{
			enc.initSymbolModel(m_byte[num]);
		}
		Buffer.BlockCopy(item.extra_bytes, 0, last_item, 0, (int)number);
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		for (uint num = 0u; num < number; num++)
		{
			int n = item.extra_bytes[num] - last_item[num];
			enc.encodeSymbol(m_byte[num], (byte)MyDefs.U8_FOLD(n));
		}
		Buffer.BlockCopy(item.extra_bytes, 0, last_item, 0, (int)number);
		return true;
	}
}
internal class LASwriteItemCompressed_GPSTIME11_v2 : LASwriteItemCompressed
{
	private const int LASZIP_GPSTIME_MULTI = 500;

	private const int LASZIP_GPSTIME_MULTI_MINUS = -10;

	private const int LASZIP_GPSTIME_MULTI_UNCHANGED = 511;

	private const int LASZIP_GPSTIME_MULTI_CODE_FULL = 512;

	private const int LASZIP_GPSTIME_MULTI_TOTAL = 516;

	private ArithmeticEncoder enc;

	private uint last;

	private uint next;

	private readonly U64I64F64[] last_gpstime = new U64I64F64[4];

	private readonly int[] last_gpstime_diff = new int[4];

	private readonly int[] multi_extreme_counter = new int[4];

	private ArithmeticModel m_gpstime_multi;

	private ArithmeticModel m_gpstime_0diff;

	private IntegerCompressor ic_gpstime;

	public LASwriteItemCompressed_GPSTIME11_v2(ArithmeticEncoder enc)
	{
		this.enc = enc;
		m_gpstime_multi = enc.createSymbolModel(516u);
		m_gpstime_0diff = enc.createSymbolModel(6u);
		ic_gpstime = new IntegerCompressor(enc, 32u, 9u);
	}

	public override bool init(laszip_point item, ref uint context)
	{
		last = 0u;
		next = 0u;
		last_gpstime_diff[0] = 0;
		last_gpstime_diff[1] = 0;
		last_gpstime_diff[2] = 0;
		last_gpstime_diff[3] = 0;
		multi_extreme_counter[0] = 0;
		multi_extreme_counter[1] = 0;
		multi_extreme_counter[2] = 0;
		multi_extreme_counter[3] = 0;
		enc.initSymbolModel(m_gpstime_multi);
		enc.initSymbolModel(m_gpstime_0diff);
		ic_gpstime.initCompressor();
		last_gpstime[0].f64 = item.gps_time;
		last_gpstime[1].u64 = 0uL;
		last_gpstime[2].u64 = 0uL;
		last_gpstime[3].u64 = 0uL;
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		U64I64F64 u64I64F = new U64I64F64
		{
			f64 = item.gps_time
		};
		if (last_gpstime_diff[last] == 0)
		{
			if (u64I64F.i64 == last_gpstime[last].i64)
			{
				enc.encodeSymbol(m_gpstime_0diff, 0u);
			}
			else
			{
				long num = u64I64F.i64 - last_gpstime[last].i64;
				int num2 = (int)num;
				if (num == num2)
				{
					enc.encodeSymbol(m_gpstime_0diff, 1u);
					ic_gpstime.compress(0, num2);
					last_gpstime_diff[last] = num2;
					multi_extreme_counter[last] = 0;
				}
				else
				{
					for (uint num3 = 1u; num3 < 4; num3++)
					{
						long num4 = u64I64F.i64 - last_gpstime[(last + num3) & 3].i64;
						int num5 = (int)num4;
						if (num4 == num5)
						{
							enc.encodeSymbol(m_gpstime_0diff, num3 + 2);
							last = (last + num3) & 3;
							return write(item, ref context);
						}
					}
					enc.encodeSymbol(m_gpstime_0diff, 2u);
					ic_gpstime.compress((int)(last_gpstime[last].u64 >> 32), (int)(u64I64F.u64 >> 32), 8u);
					enc.writeInt((uint)u64I64F.u64);
					next = (next + 1) & 3;
					last = next;
					last_gpstime_diff[last] = 0;
					multi_extreme_counter[last] = 0;
				}
				last_gpstime[last].i64 = u64I64F.i64;
			}
		}
		else if (u64I64F.i64 == last_gpstime[last].i64)
		{
			enc.encodeSymbol(m_gpstime_multi, 511u);
		}
		else
		{
			long num6 = u64I64F.i64 - last_gpstime[last].i64;
			int num7 = (int)num6;
			if (num6 == num7)
			{
				int num8 = MyDefs.I32_QUANTIZE((double)num7 / (double)last_gpstime_diff[last]);
				if (num8 == 1)
				{
					enc.encodeSymbol(m_gpstime_multi, 1u);
					ic_gpstime.compress(last_gpstime_diff[last], num7, 1u);
					multi_extreme_counter[last] = 0;
				}
				else if (num8 > 0)
				{
					if (num8 < 500)
					{
						enc.encodeSymbol(m_gpstime_multi, (uint)num8);
						if (num8 < 10)
						{
							ic_gpstime.compress(num8 * last_gpstime_diff[last], num7, 2u);
						}
						else
						{
							ic_gpstime.compress(num8 * last_gpstime_diff[last], num7, 3u);
						}
					}
					else
					{
						enc.encodeSymbol(m_gpstime_multi, 500u);
						ic_gpstime.compress(500 * last_gpstime_diff[last], num7, 4u);
						multi_extreme_counter[last]++;
						if (multi_extreme_counter[last] > 3)
						{
							last_gpstime_diff[last] = num7;
							multi_extreme_counter[last] = 0;
						}
					}
				}
				else if (num8 < 0)
				{
					if (num8 > -10)
					{
						enc.encodeSymbol(m_gpstime_multi, (uint)(500 - num8));
						ic_gpstime.compress(num8 * last_gpstime_diff[last], num7, 5u);
					}
					else
					{
						enc.encodeSymbol(m_gpstime_multi, 510u);
						ic_gpstime.compress(-10 * last_gpstime_diff[last], num7, 6u);
						multi_extreme_counter[last]++;
						if (multi_extreme_counter[last] > 3)
						{
							last_gpstime_diff[last] = num7;
							multi_extreme_counter[last] = 0;
						}
					}
				}
				else
				{
					enc.encodeSymbol(m_gpstime_multi, 0u);
					ic_gpstime.compress(0, num7, 7u);
					multi_extreme_counter[last]++;
					if (multi_extreme_counter[last] > 3)
					{
						last_gpstime_diff[last] = num7;
						multi_extreme_counter[last] = 0;
					}
				}
			}
			else
			{
				for (uint num9 = 1u; num9 < 4; num9++)
				{
					long num10 = u64I64F.i64 - last_gpstime[(last + num9) & 3].i64;
					int num11 = (int)num10;
					if (num10 == num11)
					{
						enc.encodeSymbol(m_gpstime_multi, 512 + num9);
						last = (last + num9) & 3;
						return write(item, ref context);
					}
				}
				enc.encodeSymbol(m_gpstime_multi, 512u);
				ic_gpstime.compress((int)(last_gpstime[last].u64 >> 32), (int)(u64I64F.u64 >> 32), 8u);
				enc.writeInt((uint)u64I64F.u64);
				next = (next + 1) & 3;
				last = next;
				last_gpstime_diff[last] = 0;
				multi_extreme_counter[last] = 0;
			}
			last_gpstime[last].i64 = u64I64F.i64;
		}
		return true;
	}
}
internal class LASwriteItemCompressed_POINT10_v2 : LASwriteItemCompressed
{
	private ArithmeticEncoder enc;

	private LASpoint10 last;

	private readonly ushort[] last_intensity = new ushort[16];

	private readonly StreamingMedian5[] last_x_diff_median5 = new StreamingMedian5[16];

	private readonly StreamingMedian5[] last_y_diff_median5 = new StreamingMedian5[16];

	private readonly int[] last_height = new int[8];

	private IntegerCompressor ic_dx;

	private IntegerCompressor ic_dy;

	private IntegerCompressor ic_z;

	private IntegerCompressor ic_intensity;

	private IntegerCompressor ic_point_source_ID;

	private ArithmeticModel m_changed_values;

	private readonly ArithmeticModel[] m_scan_angle_rank = new ArithmeticModel[2];

	private readonly ArithmeticModel[] m_bit_byte = new ArithmeticModel[256];

	private readonly ArithmeticModel[] m_classification = new ArithmeticModel[256];

	private readonly ArithmeticModel[] m_user_data = new ArithmeticModel[256];

	public LASwriteItemCompressed_POINT10_v2(ArithmeticEncoder enc)
	{
		this.enc = enc;
		ic_dx = new IntegerCompressor(enc, 32u, 2u);
		ic_dy = new IntegerCompressor(enc, 32u, 22u);
		ic_z = new IntegerCompressor(enc, 32u, 20u);
		ic_intensity = new IntegerCompressor(enc, 16u, 4u);
		m_scan_angle_rank[0] = enc.createSymbolModel(256u);
		m_scan_angle_rank[1] = enc.createSymbolModel(256u);
		ic_point_source_ID = new IntegerCompressor(enc);
		m_changed_values = enc.createSymbolModel(64u);
		for (int i = 0; i < 256; i++)
		{
			m_bit_byte[i] = null;
			m_classification[i] = null;
			m_user_data[i] = null;
		}
	}

	public override bool init(laszip_point item, ref uint context)
	{
		for (int i = 0; i < 16; i++)
		{
			last_x_diff_median5[i].init();
			last_y_diff_median5[i].init();
			last_intensity[i] = 0;
			last_height[i / 2] = 0;
		}
		ic_dx.initCompressor();
		ic_dy.initCompressor();
		ic_z.initCompressor();
		ic_intensity.initCompressor();
		enc.initSymbolModel(m_scan_angle_rank[0]);
		enc.initSymbolModel(m_scan_angle_rank[1]);
		ic_point_source_ID.initCompressor();
		enc.initSymbolModel(m_changed_values);
		for (int j = 0; j < 256; j++)
		{
			if (m_bit_byte[j] != null)
			{
				enc.initSymbolModel(m_bit_byte[j]);
			}
			if (m_classification[j] != null)
			{
				enc.initSymbolModel(m_classification[j]);
			}
			if (m_user_data[j] != null)
			{
				enc.initSymbolModel(m_user_data[j]);
			}
		}
		last.X = item.X;
		last.Y = item.Y;
		last.Z = item.Z;
		last.intensity = item.intensity;
		last.flags = item.flags;
		last.classification_and_classification_flags = item.classification_and_classification_flags;
		last.scan_angle_rank = item.scan_angle_rank;
		last.user_data = item.user_data;
		last.point_source_ID = item.point_source_ID;
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		uint return_number = item.return_number;
		uint number_of_returns = item.number_of_returns;
		uint num = Laszip_Common_v2.number_return_map[number_of_returns, return_number];
		uint num2 = Laszip_Common_v2.number_return_level[number_of_returns, return_number];
		uint num3 = 0u;
		bool num4 = last.flags != item.flags;
		if (num4)
		{
			num3 |= 0x20;
		}
		bool flag = last_intensity[num] != item.intensity;
		if (flag)
		{
			num3 |= 0x10;
		}
		bool flag2 = last.classification_and_classification_flags != item.classification_and_classification_flags;
		if (flag2)
		{
			num3 |= 8;
		}
		bool flag3 = last.scan_angle_rank != item.scan_angle_rank;
		if (flag3)
		{
			num3 |= 4;
		}
		bool flag4 = last.user_data != item.user_data;
		if (flag4)
		{
			num3 |= 2;
		}
		bool flag5 = last.point_source_ID != item.point_source_ID;
		if (flag5)
		{
			num3 |= 1;
		}
		enc.encodeSymbol(m_changed_values, num3);
		if (num4)
		{
			if (m_bit_byte[last.flags] == null)
			{
				m_bit_byte[last.flags] = enc.createSymbolModel(256u);
				enc.initSymbolModel(m_bit_byte[last.flags]);
			}
			enc.encodeSymbol(m_bit_byte[last.flags], item.flags);
		}
		if (flag)
		{
			ic_intensity.compress(last_intensity[num], item.intensity, (num < 3) ? num : 3u);
			last_intensity[num] = item.intensity;
		}
		if (flag2)
		{
			if (m_classification[last.classification_and_classification_flags] == null)
			{
				m_classification[last.classification_and_classification_flags] = enc.createSymbolModel(256u);
				enc.initSymbolModel(m_classification[last.classification_and_classification_flags]);
			}
			enc.encodeSymbol(m_classification[last.classification_and_classification_flags], item.classification_and_classification_flags);
		}
		if (flag3)
		{
			enc.encodeSymbol(m_scan_angle_rank[item.scan_direction_flag], (uint)MyDefs.U8_FOLD((byte)item.scan_angle_rank - (byte)last.scan_angle_rank));
		}
		if (flag4)
		{
			if (m_user_data[last.user_data] == null)
			{
				m_user_data[last.user_data] = enc.createSymbolModel(256u);
				enc.initSymbolModel(m_user_data[last.user_data]);
			}
			enc.encodeSymbol(m_user_data[last.user_data], item.user_data);
		}
		if (flag5)
		{
			ic_point_source_ID.compress(last.point_source_ID, item.point_source_ID);
		}
		int pred = last_x_diff_median5[num].get();
		int num5 = item.X - last.X;
		ic_dx.compress(pred, num5, (number_of_returns == 1) ? 1u : 0u);
		last_x_diff_median5[num].add(num5);
		uint k = ic_dx.getK();
		pred = last_y_diff_median5[num].get();
		num5 = item.Y - last.Y;
		ic_dy.compress(pred, num5, ((number_of_returns == 1) ? 1u : 0u) + ((k < 20) ? (k & 0xFE) : 20));
		last_y_diff_median5[num].add(num5);
		k = (ic_dx.getK() + ic_dy.getK()) / 2;
		ic_z.compress(last_height[num2], item.Z, ((number_of_returns == 1) ? 1u : 0u) + ((k < 18) ? (k & 0xFE) : 18));
		last_height[num2] = item.Z;
		last.X = item.X;
		last.Y = item.Y;
		last.Z = item.Z;
		last.intensity = item.intensity;
		last.flags = item.flags;
		last.classification_and_classification_flags = item.classification_and_classification_flags;
		last.scan_angle_rank = item.scan_angle_rank;
		last.user_data = item.user_data;
		last.point_source_ID = item.point_source_ID;
		return true;
	}
}
internal class LASwriteItemCompressed_POINT14_v4 : LASwriteItemCompressed
{
	private const int LASZIP_GPSTIME_MULTI = 500;

	private const int LASZIP_GPSTIME_MULTI_MINUS = -10;

	private const int LASZIP_GPSTIME_MULTI_CODE_FULL = 511;

	private const int LASZIP_GPSTIME_MULTI_TOTAL = 515;

	private ArithmeticEncoder enc;

	private MemoryStream outstream_channel_returns_XY;

	private MemoryStream outstream_Z;

	private MemoryStream outstream_classification;

	private MemoryStream outstream_flags;

	private MemoryStream outstream_intensity;

	private MemoryStream outstream_scan_angle;

	private MemoryStream outstream_user_data;

	private MemoryStream outstream_point_source;

	private MemoryStream outstream_gps_time;

	private ArithmeticEncoder enc_channel_returns_XY;

	private ArithmeticEncoder enc_Z;

	private ArithmeticEncoder enc_classification;

	private ArithmeticEncoder enc_flags;

	private ArithmeticEncoder enc_intensity;

	private ArithmeticEncoder enc_scan_angle;

	private ArithmeticEncoder enc_user_data;

	private ArithmeticEncoder enc_point_source;

	private ArithmeticEncoder enc_gps_time;

	private bool changed_classification;

	private bool changed_flags;

	private bool changed_intensity;

	private bool changed_scan_angle;

	private bool changed_user_data;

	private bool changed_point_source;

	private bool changed_gps_time;

	private uint num_bytes_channel_returns_XY;

	private uint num_bytes_Z;

	private uint num_bytes_classification;

	private uint num_bytes_flags;

	private uint num_bytes_intensity;

	private uint num_bytes_scan_angle;

	private uint num_bytes_user_data;

	private uint num_bytes_point_source;

	private uint num_bytes_gps_time;

	private uint current_context;

	private readonly LAScontextPOINT14[] contexts = new LAScontextPOINT14[4]
	{
		new LAScontextPOINT14(),
		new LAScontextPOINT14(),
		new LAScontextPOINT14(),
		new LAScontextPOINT14()
	};

	public LASwriteItemCompressed_POINT14_v4(ArithmeticEncoder enc)
	{
		this.enc = enc;
		outstream_channel_returns_XY = null;
		outstream_Z = null;
		outstream_classification = null;
		outstream_flags = null;
		outstream_intensity = null;
		outstream_scan_angle = null;
		outstream_user_data = null;
		outstream_point_source = null;
		outstream_gps_time = null;
		enc_channel_returns_XY = null;
		enc_Z = null;
		enc_classification = null;
		enc_flags = null;
		enc_intensity = null;
		enc_scan_angle = null;
		enc_user_data = null;
		enc_point_source = null;
		enc_gps_time = null;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_changed_values[0] = null;
		}
		current_context = 0u;
		num_bytes_channel_returns_XY = 0u;
		num_bytes_Z = 0u;
		num_bytes_classification = 0u;
		num_bytes_flags = 0u;
		num_bytes_intensity = 0u;
		num_bytes_scan_angle = 0u;
		num_bytes_user_data = 0u;
		num_bytes_point_source = 0u;
		num_bytes_gps_time = 0u;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		if (outstream_channel_returns_XY == null)
		{
			outstream_channel_returns_XY = new MemoryStream();
			outstream_Z = new MemoryStream();
			outstream_classification = new MemoryStream();
			outstream_flags = new MemoryStream();
			outstream_intensity = new MemoryStream();
			outstream_scan_angle = new MemoryStream();
			outstream_user_data = new MemoryStream();
			outstream_point_source = new MemoryStream();
			outstream_gps_time = new MemoryStream();
			enc_channel_returns_XY = new ArithmeticEncoder();
			enc_Z = new ArithmeticEncoder();
			enc_classification = new ArithmeticEncoder();
			enc_flags = new ArithmeticEncoder();
			enc_intensity = new ArithmeticEncoder();
			enc_scan_angle = new ArithmeticEncoder();
			enc_user_data = new ArithmeticEncoder();
			enc_point_source = new ArithmeticEncoder();
			enc_gps_time = new ArithmeticEncoder();
		}
		else
		{
			outstream_channel_returns_XY.Seek(0L, SeekOrigin.Begin);
			outstream_Z.Seek(0L, SeekOrigin.Begin);
			outstream_classification.Seek(0L, SeekOrigin.Begin);
			outstream_flags.Seek(0L, SeekOrigin.Begin);
			outstream_intensity.Seek(0L, SeekOrigin.Begin);
			outstream_scan_angle.Seek(0L, SeekOrigin.Begin);
			outstream_user_data.Seek(0L, SeekOrigin.Begin);
			outstream_point_source.Seek(0L, SeekOrigin.Begin);
			outstream_gps_time.Seek(0L, SeekOrigin.Begin);
		}
		enc_channel_returns_XY.init(outstream_channel_returns_XY);
		enc_Z.init(outstream_Z);
		enc_classification.init(outstream_classification);
		enc_flags.init(outstream_flags);
		enc_intensity.init(outstream_intensity);
		enc_scan_angle.init(outstream_scan_angle);
		enc_user_data.init(outstream_user_data);
		enc_point_source.init(outstream_point_source);
		enc_gps_time.init(outstream_gps_time);
		changed_classification = false;
		changed_flags = false;
		changed_intensity = false;
		changed_scan_angle = false;
		changed_user_data = false;
		changed_point_source = false;
		changed_gps_time = false;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = item.extended_scanner_channel;
		context = current_context;
		createAndInitModelsAndCompressors(current_context, item);
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		laszip_point last_item = contexts[current_context].last_item;
		int num = ((last_item.extended_return_number == 1) ? 1 : 0);
		num += ((last_item.extended_return_number >= last_item.extended_number_of_returns) ? 2 : 0);
		num += (contexts[current_context].last_item_gps_time_change ? 4 : 0);
		uint extended_scanner_channel = item.extended_scanner_channel;
		if (extended_scanner_channel != current_context && !contexts[extended_scanner_channel].unused)
		{
			last_item = contexts[extended_scanner_channel].last_item;
		}
		uint extended_number_of_returns = last_item.extended_number_of_returns;
		uint extended_return_number = last_item.extended_return_number;
		uint extended_number_of_returns2 = item.extended_number_of_returns;
		uint extended_return_number2 = item.extended_return_number;
		bool num2 = extended_scanner_channel != current_context;
		bool flag = item.point_source_ID != last_item.point_source_ID;
		bool flag2 = item.gps_time != last_item.gps_time;
		bool flag3 = item.extended_scan_angle != last_item.extended_scan_angle;
		bool flag4 = extended_number_of_returns2 != extended_number_of_returns;
		int num3 = (num2 ? 64 : 0) | (flag ? 32 : 0) | (flag2 ? 16 : 0) | (flag3 ? 8 : 0) | (flag4 ? 4 : 0);
		if (extended_return_number2 != extended_return_number)
		{
			num3 = ((extended_return_number2 == (extended_return_number + 1) % 16) ? (num3 | 1) : ((extended_return_number2 != (extended_return_number + 15) % 16) ? (num3 | 3) : (num3 | 2)));
		}
		enc_channel_returns_XY.encodeSymbol(contexts[current_context].m_changed_values[num], (uint)num3);
		if (num2)
		{
			int num4 = (int)(extended_scanner_channel - current_context);
			if (num4 > 0)
			{
				enc_channel_returns_XY.encodeSymbol(contexts[current_context].m_scanner_channel, (uint)(num4 - 1));
			}
			else
			{
				enc_channel_returns_XY.encodeSymbol(contexts[current_context].m_scanner_channel, (uint)(num4 + 4 - 1));
			}
			if (contexts[extended_scanner_channel].unused)
			{
				createAndInitModelsAndCompressors(extended_scanner_channel, contexts[current_context].last_item);
				last_item = contexts[extended_scanner_channel].last_item;
			}
			current_context = extended_scanner_channel;
		}
		context = current_context;
		if (flag4)
		{
			if (contexts[current_context].m_number_of_returns[extended_number_of_returns] == null)
			{
				contexts[current_context].m_number_of_returns[extended_number_of_returns] = enc_channel_returns_XY.createSymbolModel(16u);
				enc_channel_returns_XY.initSymbolModel(contexts[current_context].m_number_of_returns[extended_number_of_returns]);
			}
			enc_channel_returns_XY.encodeSymbol(contexts[current_context].m_number_of_returns[extended_number_of_returns], extended_number_of_returns2);
		}
		if ((num3 & 3) == 3)
		{
			if (flag2)
			{
				if (contexts[current_context].m_return_number[extended_return_number] == null)
				{
					contexts[current_context].m_return_number[extended_return_number] = enc_channel_returns_XY.createSymbolModel(16u);
					enc_channel_returns_XY.initSymbolModel(contexts[current_context].m_return_number[extended_return_number]);
				}
				enc_channel_returns_XY.encodeSymbol(contexts[current_context].m_return_number[extended_return_number], extended_return_number2);
			}
			else
			{
				int num5 = (int)(extended_return_number2 - extended_return_number);
				if (num5 > 1)
				{
					enc_channel_returns_XY.encodeSymbol(contexts[current_context].m_return_number_gps_same, (uint)(num5 - 2));
				}
				else
				{
					enc_channel_returns_XY.encodeSymbol(contexts[current_context].m_return_number_gps_same, (uint)(num5 + 16 - 2));
				}
			}
		}
		uint num6 = Laszip_Common_v3.number_return_map_6ctx[extended_number_of_returns2, extended_return_number2];
		uint num7 = Laszip_Common_v3.number_return_level_8ctx[extended_number_of_returns2, extended_return_number2];
		int num8 = ((extended_return_number2 == 1) ? 2 : 0);
		num8 += ((extended_return_number2 >= extended_number_of_returns2) ? 1 : 0);
		int pred = contexts[current_context].last_X_diff_median5[(num6 << 1) | (flag2 ? 1u : 0u)].get();
		int num9 = item.X - last_item.X;
		contexts[current_context].ic_dX.compress(pred, num9, (extended_number_of_returns2 == 1) ? 1u : 0u);
		contexts[current_context].last_X_diff_median5[(num6 << 1) | (flag2 ? 1u : 0u)].add(num9);
		uint k = contexts[current_context].ic_dX.getK();
		pred = contexts[current_context].last_Y_diff_median5[(num6 << 1) | (flag2 ? 1u : 0u)].get();
		num9 = item.Y - last_item.Y;
		contexts[current_context].ic_dY.compress(pred, num9, ((extended_number_of_returns2 == 1) ? 1u : 0u) + ((k < 20) ? (k & 0xFE) : 20));
		contexts[current_context].last_Y_diff_median5[(num6 << 1) | (flag2 ? 1u : 0u)].add(num9);
		uint num10 = (contexts[current_context].ic_dX.getK() + contexts[current_context].ic_dY.getK()) / 2;
		contexts[current_context].ic_Z.compress(contexts[current_context].last_Z[num7], item.Z, ((extended_number_of_returns2 == 1) ? 1u : 0u) + ((num10 < 18) ? (num10 & 0xFE) : 18));
		contexts[current_context].last_Z[num7] = item.Z;
		uint extended_classification = last_item.extended_classification;
		uint extended_classification2 = item.extended_classification;
		if (extended_classification2 != extended_classification)
		{
			changed_classification = true;
		}
		int num11 = (int)((extended_classification & 0x1F) << 1) + ((num8 == 3) ? 1 : 0);
		if (contexts[current_context].m_classification[num11] == null)
		{
			contexts[current_context].m_classification[num11] = enc_classification.createSymbolModel(256u);
			enc_classification.initSymbolModel(contexts[current_context].m_classification[num11]);
		}
		enc_classification.encodeSymbol(contexts[current_context].m_classification[num11], extended_classification2);
		uint num12 = (uint)((last_item.edge_of_flight_line << 5) | (last_item.scan_direction_flag << 4) | last_item.extended_classification_flags);
		uint num13 = (uint)((item.edge_of_flight_line << 5) | (item.scan_direction_flag << 4) | item.extended_classification_flags);
		if (num13 != num12)
		{
			changed_flags = true;
		}
		if (contexts[current_context].m_flags[num12] == null)
		{
			contexts[current_context].m_flags[num12] = enc_flags.createSymbolModel(64u);
			enc_flags.initSymbolModel(contexts[current_context].m_flags[num12]);
		}
		enc_flags.encodeSymbol(contexts[current_context].m_flags[num12], num13);
		if (item.intensity != last_item.intensity)
		{
			changed_intensity = true;
		}
		contexts[current_context].ic_intensity.compress(contexts[current_context].last_intensity[(uint)(num8 << 1) | (flag2 ? 1u : 0u)], item.intensity, (uint)num8);
		contexts[current_context].last_intensity[(uint)(num8 << 1) | (flag2 ? 1u : 0u)] = item.intensity;
		if (flag3)
		{
			changed_scan_angle = true;
			contexts[current_context].ic_scan_angle.compress(last_item.extended_scan_angle, item.extended_scan_angle, flag2 ? 1u : 0u);
		}
		if (item.user_data != last_item.user_data)
		{
			changed_user_data = true;
		}
		if (contexts[current_context].m_user_data[last_item.user_data / 4] == null)
		{
			contexts[current_context].m_user_data[last_item.user_data / 4] = enc_user_data.createSymbolModel(256u);
			enc_user_data.initSymbolModel(contexts[current_context].m_user_data[last_item.user_data / 4]);
		}
		enc_user_data.encodeSymbol(contexts[current_context].m_user_data[last_item.user_data / 4], item.user_data);
		if (flag)
		{
			changed_point_source = true;
			contexts[current_context].ic_point_source_ID.compress(last_item.point_source_ID, item.point_source_ID);
		}
		if (flag2)
		{
			changed_gps_time = true;
			write_gps_time(new U64I64F64
			{
				f64 = item.gps_time
			});
		}
		last_item.X = item.X;
		last_item.Y = item.Y;
		last_item.Z = item.Z;
		last_item.intensity = item.intensity;
		last_item.flags = item.flags;
		last_item.classification_and_classification_flags = item.classification_and_classification_flags;
		last_item.scan_angle_rank = item.scan_angle_rank;
		last_item.user_data = item.user_data;
		last_item.point_source_ID = item.point_source_ID;
		last_item.extended_scan_angle = item.extended_scan_angle;
		last_item.extended_flags = item.extended_flags;
		last_item.extended_classification = item.extended_classification;
		last_item.extended_returns = item.extended_returns;
		last_item.gps_time = item.gps_time;
		contexts[current_context].last_item_gps_time_change = flag2;
		return true;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		enc_channel_returns_XY.done();
		enc_Z.done();
		if (changed_classification)
		{
			enc_classification.done();
		}
		if (changed_flags)
		{
			enc_flags.done();
		}
		if (changed_intensity)
		{
			enc_intensity.done();
		}
		if (changed_scan_angle)
		{
			enc_scan_angle.done();
		}
		if (changed_user_data)
		{
			enc_user_data.done();
		}
		if (changed_point_source)
		{
			enc_point_source.done();
		}
		if (changed_gps_time)
		{
			enc_gps_time.done();
		}
		uint num = (uint)outstream_channel_returns_XY.Position;
		num_bytes_channel_returns_XY += num;
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		num = (uint)outstream_Z.Position;
		num_bytes_Z += num;
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		if (changed_classification)
		{
			num = (uint)outstream_classification.Position;
			num_bytes_classification += num;
		}
		else
		{
			num = 0u;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		if (changed_flags)
		{
			num = (uint)outstream_flags.Position;
			num_bytes_flags += num;
		}
		else
		{
			num = 0u;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		if (changed_intensity)
		{
			num = (uint)outstream_intensity.Position;
			num_bytes_intensity += num;
		}
		else
		{
			num = 0u;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		if (changed_scan_angle)
		{
			num = (uint)outstream_scan_angle.Position;
			num_bytes_scan_angle += num;
		}
		else
		{
			num = 0u;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		if (changed_user_data)
		{
			num = (uint)outstream_user_data.Position;
			num_bytes_user_data += num;
		}
		else
		{
			num = 0u;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		if (changed_point_source)
		{
			num = (uint)outstream_point_source.Position;
			num_bytes_point_source += num;
		}
		else
		{
			num = 0u;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		if (changed_gps_time)
		{
			num = (uint)outstream_gps_time.Position;
			num_bytes_gps_time += num;
		}
		else
		{
			num = 0u;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		return true;
	}

	public override bool chunk_bytes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		byteStreamOut.Write(outstream_channel_returns_XY.GetBuffer(), 0, (int)outstream_channel_returns_XY.Position);
		byteStreamOut.Write(outstream_Z.GetBuffer(), 0, (int)outstream_Z.Position);
		if (changed_classification)
		{
			byteStreamOut.Write(outstream_classification.GetBuffer(), 0, (int)outstream_classification.Position);
		}
		if (changed_flags)
		{
			byteStreamOut.Write(outstream_flags.GetBuffer(), 0, (int)outstream_flags.Position);
		}
		if (changed_intensity)
		{
			byteStreamOut.Write(outstream_intensity.GetBuffer(), 0, (int)outstream_intensity.Position);
		}
		if (changed_scan_angle)
		{
			byteStreamOut.Write(outstream_scan_angle.GetBuffer(), 0, (int)outstream_scan_angle.Position);
		}
		if (changed_user_data)
		{
			byteStreamOut.Write(outstream_user_data.GetBuffer(), 0, (int)outstream_user_data.Position);
		}
		if (changed_point_source)
		{
			byteStreamOut.Write(outstream_point_source.GetBuffer(), 0, (int)outstream_point_source.Position);
		}
		if (changed_gps_time)
		{
			byteStreamOut.Write(outstream_gps_time.GetBuffer(), 0, (int)outstream_gps_time.Position);
		}
		return true;
	}

	private bool createAndInitModelsAndCompressors(uint context, laszip_point item)
	{
		if (contexts[context].m_changed_values[0] == null)
		{
			contexts[context].m_changed_values[0] = enc_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[1] = enc_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[2] = enc_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[3] = enc_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[4] = enc_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[5] = enc_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[6] = enc_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_changed_values[7] = enc_channel_returns_XY.createSymbolModel(128u);
			contexts[context].m_scanner_channel = enc_channel_returns_XY.createSymbolModel(3u);
			for (int i = 0; i < 16; i++)
			{
				contexts[context].m_number_of_returns[i] = null;
				contexts[context].m_return_number[i] = null;
			}
			contexts[context].m_return_number_gps_same = enc_channel_returns_XY.createSymbolModel(13u);
			contexts[context].ic_dX = new IntegerCompressor(enc_channel_returns_XY, 32u, 2u);
			contexts[context].ic_dY = new IntegerCompressor(enc_channel_returns_XY, 32u, 22u);
			contexts[context].ic_Z = new IntegerCompressor(enc_Z, 32u, 20u);
			for (int j = 0; j < 64; j++)
			{
				contexts[context].m_classification[j] = null;
				contexts[context].m_flags[j] = null;
				contexts[context].m_user_data[j] = null;
			}
			contexts[context].ic_intensity = new IntegerCompressor(enc_intensity, 16u, 4u);
			contexts[context].ic_scan_angle = new IntegerCompressor(enc_scan_angle, 16u, 2u);
			contexts[context].ic_point_source_ID = new IntegerCompressor(enc_point_source);
			contexts[context].m_gpstime_multi = enc_gps_time.createSymbolModel(515u);
			contexts[context].m_gpstime_0diff = enc_gps_time.createSymbolModel(5u);
			contexts[context].ic_gpstime = new IntegerCompressor(enc_gps_time, 32u, 9u);
		}
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[0]);
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[1]);
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[2]);
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[3]);
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[4]);
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[5]);
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[6]);
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_changed_values[7]);
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_scanner_channel);
		for (int k = 0; k < 16; k++)
		{
			if (contexts[context].m_number_of_returns[k] != null)
			{
				enc_channel_returns_XY.initSymbolModel(contexts[context].m_number_of_returns[k]);
			}
			if (contexts[context].m_return_number[k] != null)
			{
				enc_channel_returns_XY.initSymbolModel(contexts[context].m_return_number[k]);
			}
		}
		enc_channel_returns_XY.initSymbolModel(contexts[context].m_return_number_gps_same);
		contexts[context].ic_dX.initCompressor();
		contexts[context].ic_dY.initCompressor();
		for (int l = 0; l < 12; l++)
		{
			contexts[context].last_X_diff_median5[l].init();
			contexts[context].last_Y_diff_median5[l].init();
		}
		contexts[context].ic_Z.initCompressor();
		for (int m = 0; m < 8; m++)
		{
			contexts[context].last_Z[m] = item.Z;
		}
		for (int n = 0; n < 64; n++)
		{
			if (contexts[context].m_classification[n] != null)
			{
				enc_classification.initSymbolModel(contexts[context].m_classification[n]);
			}
			if (contexts[context].m_flags[n] != null)
			{
				enc_flags.initSymbolModel(contexts[context].m_flags[n]);
			}
			if (contexts[context].m_user_data[n] != null)
			{
				enc_user_data.initSymbolModel(contexts[context].m_user_data[n]);
			}
		}
		contexts[context].ic_intensity.initCompressor();
		for (int num = 0; num < 8; num++)
		{
			contexts[context].last_intensity[num] = item.intensity;
		}
		contexts[context].ic_scan_angle.initCompressor();
		contexts[context].ic_point_source_ID.initCompressor();
		enc_gps_time.initSymbolModel(contexts[context].m_gpstime_multi);
		enc_gps_time.initSymbolModel(contexts[context].m_gpstime_0diff);
		contexts[context].ic_gpstime.initCompressor();
		contexts[context].last = 0u;
		contexts[context].next = 0u;
		contexts[context].last_gpstime_diff[0] = 0;
		contexts[context].last_gpstime_diff[1] = 0;
		contexts[context].last_gpstime_diff[2] = 0;
		contexts[context].last_gpstime_diff[3] = 0;
		contexts[context].multi_extreme_counter[0] = 0;
		contexts[context].multi_extreme_counter[1] = 0;
		contexts[context].multi_extreme_counter[2] = 0;
		contexts[context].multi_extreme_counter[3] = 0;
		contexts[context].last_gpstime[0].f64 = item.gps_time;
		contexts[context].last_gpstime[1].u64 = 0uL;
		contexts[context].last_gpstime[2].u64 = 0uL;
		contexts[context].last_gpstime[3].u64 = 0uL;
		contexts[context].last_item.X = item.X;
		contexts[context].last_item.Y = item.Y;
		contexts[context].last_item.Z = item.Z;
		contexts[context].last_item.intensity = item.intensity;
		contexts[context].last_item.flags = item.flags;
		contexts[context].last_item.classification_and_classification_flags = item.classification_and_classification_flags;
		contexts[context].last_item.scan_angle_rank = item.scan_angle_rank;
		contexts[context].last_item.user_data = item.user_data;
		contexts[context].last_item.point_source_ID = item.point_source_ID;
		contexts[context].last_item.extended_scan_angle = item.extended_scan_angle;
		contexts[context].last_item.extended_flags = item.extended_flags;
		contexts[context].last_item.extended_classification = item.extended_classification;
		contexts[context].last_item.extended_returns = item.extended_returns;
		contexts[context].last_item.gps_time = item.gps_time;
		contexts[context].last_item_gps_time_change = false;
		contexts[context].unused = false;
		return true;
	}

	private void write_gps_time(U64I64F64 gps_time)
	{
		if (contexts[current_context].last_gpstime_diff[contexts[current_context].last] == 0)
		{
			long num = gps_time.i64 - contexts[current_context].last_gpstime[contexts[current_context].last].i64;
			int num2 = (int)num;
			if (num == num2)
			{
				enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_0diff, 0u);
				contexts[current_context].ic_gpstime.compress(0, num2);
				contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num2;
				contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
			}
			else
			{
				for (uint num3 = 1u; num3 < 4; num3++)
				{
					long num4 = gps_time.i64 - contexts[current_context].last_gpstime[(contexts[current_context].last + num3) & 3].i64;
					int num5 = (int)num4;
					if (num4 == num5)
					{
						enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_0diff, num3 + 1);
						contexts[current_context].last = (contexts[current_context].last + num3) & 3;
						write_gps_time(gps_time);
						return;
					}
				}
				enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_0diff, 1u);
				contexts[current_context].ic_gpstime.compress((int)(contexts[current_context].last_gpstime[contexts[current_context].last].u64 >> 32), (int)(gps_time.u64 >> 32), 8u);
				enc_gps_time.writeInt((uint)gps_time.u64);
				contexts[current_context].next = (contexts[current_context].next + 1) & 3;
				contexts[current_context].last = contexts[current_context].next;
				contexts[current_context].last_gpstime_diff[contexts[current_context].last] = 0;
				contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
			}
			contexts[current_context].last_gpstime[contexts[current_context].last].i64 = gps_time.i64;
			return;
		}
		long num6 = gps_time.i64 - contexts[current_context].last_gpstime[contexts[current_context].last].i64;
		int num7 = (int)num6;
		if (num6 == num7)
		{
			int num8 = MyDefs.I32_QUANTIZE((double)num7 / (double)contexts[current_context].last_gpstime_diff[contexts[current_context].last]);
			if (num8 == 1)
			{
				enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_multi, 1u);
				contexts[current_context].ic_gpstime.compress(contexts[current_context].last_gpstime_diff[contexts[current_context].last], num7, 1u);
				contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
			}
			else if (num8 > 0)
			{
				if (num8 < 500)
				{
					enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_multi, (uint)num8);
					if (num8 < 10)
					{
						contexts[current_context].ic_gpstime.compress(num8 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], num7, 2u);
					}
					else
					{
						contexts[current_context].ic_gpstime.compress(num8 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], num7, 3u);
					}
				}
				else
				{
					enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_multi, 500u);
					contexts[current_context].ic_gpstime.compress(500 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], num7, 4u);
					contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
					if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
					{
						contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num7;
						contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
					}
				}
			}
			else if (num8 < 0)
			{
				if (num8 > -10)
				{
					enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_multi, (uint)(500 - num8));
					contexts[current_context].ic_gpstime.compress(num8 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], num7, 5u);
				}
				else
				{
					enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_multi, 510u);
					contexts[current_context].ic_gpstime.compress(-10 * contexts[current_context].last_gpstime_diff[contexts[current_context].last], num7, 6u);
					contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
					if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
					{
						contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num7;
						contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
					}
				}
			}
			else
			{
				enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_multi, 0u);
				contexts[current_context].ic_gpstime.compress(0, num7, 7u);
				contexts[current_context].multi_extreme_counter[contexts[current_context].last]++;
				if (contexts[current_context].multi_extreme_counter[contexts[current_context].last] > 3)
				{
					contexts[current_context].last_gpstime_diff[contexts[current_context].last] = num7;
					contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
				}
			}
		}
		else
		{
			for (uint num9 = 1u; num9 < 4; num9++)
			{
				long num10 = gps_time.i64 - contexts[current_context].last_gpstime[(contexts[current_context].last + num9) & 3].i64;
				int num11 = (int)num10;
				if (num10 == num11)
				{
					enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_multi, 511 + num9);
					contexts[current_context].last = (contexts[current_context].last + num9) & 3;
					write_gps_time(gps_time);
					return;
				}
			}
			enc_gps_time.encodeSymbol(contexts[current_context].m_gpstime_multi, 511u);
			contexts[current_context].ic_gpstime.compress((int)(contexts[current_context].last_gpstime[contexts[current_context].last].u64 >> 32), (int)(gps_time.u64 >> 32), 8u);
			enc_gps_time.writeInt((uint)gps_time.u64);
			contexts[current_context].next = (contexts[current_context].next + 1) & 3;
			contexts[current_context].last = contexts[current_context].next;
			contexts[current_context].last_gpstime_diff[contexts[current_context].last] = 0;
			contexts[current_context].multi_extreme_counter[contexts[current_context].last] = 0;
		}
		contexts[current_context].last_gpstime[contexts[current_context].last].i64 = gps_time.i64;
	}
}
internal class LASwriteItemCompressed_RGB12_v2 : LASwriteItemCompressed
{
	private ArithmeticEncoder enc;

	private readonly ushort[] last_item = new ushort[3];

	private ArithmeticModel m_byte_used;

	private ArithmeticModel m_rgb_diff_0;

	private ArithmeticModel m_rgb_diff_1;

	private ArithmeticModel m_rgb_diff_2;

	private ArithmeticModel m_rgb_diff_3;

	private ArithmeticModel m_rgb_diff_4;

	private ArithmeticModel m_rgb_diff_5;

	public LASwriteItemCompressed_RGB12_v2(ArithmeticEncoder enc)
	{
		this.enc = enc;
		m_byte_used = enc.createSymbolModel(128u);
		m_rgb_diff_0 = enc.createSymbolModel(256u);
		m_rgb_diff_1 = enc.createSymbolModel(256u);
		m_rgb_diff_2 = enc.createSymbolModel(256u);
		m_rgb_diff_3 = enc.createSymbolModel(256u);
		m_rgb_diff_4 = enc.createSymbolModel(256u);
		m_rgb_diff_5 = enc.createSymbolModel(256u);
	}

	public override bool init(laszip_point item, ref uint context)
	{
		enc.initSymbolModel(m_byte_used);
		enc.initSymbolModel(m_rgb_diff_0);
		enc.initSymbolModel(m_rgb_diff_1);
		enc.initSymbolModel(m_rgb_diff_2);
		enc.initSymbolModel(m_rgb_diff_3);
		enc.initSymbolModel(m_rgb_diff_4);
		enc.initSymbolModel(m_rgb_diff_5);
		last_item[0] = item.rgb[0];
		last_item[1] = item.rgb[1];
		last_item[2] = item.rgb[2];
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		int num = 0;
		int num2 = 0;
		uint num3 = 0u;
		bool flag = (last_item[0] & 0xFF) != (item.rgb[0] & 0xFF);
		if (flag)
		{
			num3 |= 1;
		}
		bool flag2 = (last_item[0] & 0xFF00) != (item.rgb[0] & 0xFF00);
		if (flag2)
		{
			num3 |= 2;
		}
		bool flag3 = (last_item[1] & 0xFF) != (item.rgb[1] & 0xFF);
		if (flag3)
		{
			num3 |= 4;
		}
		bool flag4 = (last_item[1] & 0xFF00) != (item.rgb[1] & 0xFF00);
		if (flag4)
		{
			num3 |= 8;
		}
		bool flag5 = (last_item[2] & 0xFF) != (item.rgb[2] & 0xFF);
		if (flag5)
		{
			num3 |= 0x10;
		}
		bool flag6 = (last_item[2] & 0xFF00) != (item.rgb[2] & 0xFF00);
		if (flag6)
		{
			num3 |= 0x20;
		}
		int num4;
		if ((item.rgb[0] & 0xFF) == (item.rgb[1] & 0xFF) && (item.rgb[0] & 0xFF) == (item.rgb[2] & 0xFF) && (item.rgb[0] & 0xFF00) == (item.rgb[1] & 0xFF00))
		{
			num4 = (((item.rgb[0] & 0xFF00) != (item.rgb[2] & 0xFF00)) ? 1 : 0);
			if (num4 == 0)
			{
				goto IL_018e;
			}
		}
		else
		{
			num4 = 1;
		}
		num3 |= 0x40;
		goto IL_018e;
		IL_018e:
		enc.encodeSymbol(m_byte_used, num3);
		if (flag)
		{
			num = (item.rgb[0] & 0xFF) - (last_item[0] & 0xFF);
			enc.encodeSymbol(m_rgb_diff_0, (byte)MyDefs.U8_FOLD(num));
		}
		if (flag2)
		{
			num2 = (item.rgb[0] >> 8) - (last_item[0] >> 8);
			enc.encodeSymbol(m_rgb_diff_1, (byte)MyDefs.U8_FOLD(num2));
		}
		if (num4 != 0)
		{
			if (flag3)
			{
				int n = (item.rgb[1] & 0xFF) - MyDefs.U8_CLAMP(num + (last_item[1] & 0xFF));
				enc.encodeSymbol(m_rgb_diff_2, (byte)MyDefs.U8_FOLD(n));
			}
			if (flag5)
			{
				num = (num + (item.rgb[1] & 0xFF) - (last_item[1] & 0xFF)) / 2;
				int n2 = (item.rgb[2] & 0xFF) - MyDefs.U8_CLAMP(num + (last_item[2] & 0xFF));
				enc.encodeSymbol(m_rgb_diff_4, (byte)MyDefs.U8_FOLD(n2));
			}
			if (flag4)
			{
				int n3 = (item.rgb[1] >> 8) - MyDefs.U8_CLAMP(num2 + (last_item[1] >> 8));
				enc.encodeSymbol(m_rgb_diff_3, (byte)MyDefs.U8_FOLD(n3));
			}
			if (flag6)
			{
				num2 = (num2 + (item.rgb[1] >> 8) - (last_item[1] >> 8)) / 2;
				int n4 = (item.rgb[2] >> 8) - MyDefs.U8_CLAMP(num2 + (last_item[2] >> 8));
				enc.encodeSymbol(m_rgb_diff_5, (byte)MyDefs.U8_FOLD(n4));
			}
		}
		last_item[0] = item.rgb[0];
		last_item[1] = item.rgb[1];
		last_item[2] = item.rgb[2];
		return true;
	}
}
internal class LASwriteItemCompressed_RGB14_v4 : LASwriteItemCompressed
{
	private ArithmeticEncoder enc;

	private MemoryStream outstream_RGB;

	private ArithmeticEncoder enc_RGB;

	private bool changed_RGB;

	private uint num_bytes_RGB;

	private uint current_context;

	private readonly LAScontextRGB14[] contexts = new LAScontextRGB14[4]
	{
		new LAScontextRGB14(),
		new LAScontextRGB14(),
		new LAScontextRGB14(),
		new LAScontextRGB14()
	};

	public LASwriteItemCompressed_RGB14_v4(ArithmeticEncoder enc)
	{
		this.enc = enc;
		outstream_RGB = null;
		enc_RGB = null;
		num_bytes_RGB = 0u;
		changed_RGB = false;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_byte_used = null;
		}
		current_context = 0u;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		if (outstream_RGB == null)
		{
			outstream_RGB = new MemoryStream();
			enc_RGB = new ArithmeticEncoder();
		}
		else
		{
			outstream_RGB.Seek(0L, SeekOrigin.Begin);
		}
		enc_RGB.init(outstream_RGB);
		changed_RGB = false;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndCompressors(current_context, item.rgb);
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		ushort[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndCompressors(current_context, last_item);
			}
			last_item = contexts[current_context].last_item;
		}
		int num = 0;
		int num2 = 0;
		bool num3 = (last_item[0] & 0xFF) != (item.rgb[0] & 0xFF);
		bool flag = (last_item[0] & 0xFF00) != (item.rgb[0] & 0xFF00);
		bool flag2 = (last_item[1] & 0xFF) != (item.rgb[1] & 0xFF);
		bool flag3 = (last_item[1] & 0xFF00) != (item.rgb[1] & 0xFF00);
		bool flag4 = (last_item[2] & 0xFF) != (item.rgb[2] & 0xFF);
		bool flag5 = (last_item[2] & 0xFF00) != (item.rgb[2] & 0xFF00);
		bool flag6 = (item.rgb[0] & 0xFF) != (item.rgb[1] & 0xFF) || (item.rgb[0] & 0xFF) != (item.rgb[2] & 0xFF) || (item.rgb[0] & 0xFF00) != (item.rgb[1] & 0xFF00) || (item.rgb[0] & 0xFF00) != (item.rgb[2] & 0xFF00);
		uint num4 = (num3 ? 1u : 0u);
		num4 |= (uint)(flag ? 2 : 0);
		num4 |= (uint)(flag2 ? 4 : 0);
		num4 |= (uint)(flag3 ? 8 : 0);
		num4 |= (uint)(flag4 ? 16 : 0);
		num4 |= (uint)(flag5 ? 32 : 0);
		num4 |= (uint)(flag6 ? 64 : 0);
		enc_RGB.encodeSymbol(contexts[current_context].m_byte_used, num4);
		if (num3)
		{
			num = (item.rgb[0] & 0xFF) - (last_item[0] & 0xFF);
			enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_0, (uint)MyDefs.U8_FOLD(num));
		}
		if (flag)
		{
			num2 = (item.rgb[0] >> 8) - (last_item[0] >> 8);
			enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_1, (uint)MyDefs.U8_FOLD(num2));
		}
		if (flag6)
		{
			if (flag2)
			{
				int n = (item.rgb[1] & 0xFF) - MyDefs.U8_CLAMP(num + (last_item[1] & 0xFF));
				enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_2, (uint)MyDefs.U8_FOLD(n));
			}
			if (flag4)
			{
				num = (num + (item.rgb[1] & 0xFF) - (last_item[1] & 0xFF)) / 2;
				int n2 = (item.rgb[2] & 0xFF) - MyDefs.U8_CLAMP(num + (last_item[2] & 0xFF));
				enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_4, (uint)MyDefs.U8_FOLD(n2));
			}
			if (flag3)
			{
				int n3 = (item.rgb[1] >> 8) - MyDefs.U8_CLAMP(num2 + (last_item[1] >> 8));
				enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_3, (uint)MyDefs.U8_FOLD(n3));
			}
			if (flag5)
			{
				num2 = (num2 + (item.rgb[1] >> 8) - (last_item[1] >> 8)) / 2;
				int n4 = (item.rgb[2] >> 8) - MyDefs.U8_CLAMP(num2 + (last_item[2] >> 8));
				enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_5, (uint)MyDefs.U8_FOLD(n4));
			}
		}
		if (num4 != 0)
		{
			changed_RGB = true;
		}
		last_item[0] = item.rgb[0];
		last_item[1] = item.rgb[1];
		last_item[2] = item.rgb[2];
		return true;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		enc_RGB.done();
		uint num = 0u;
		if (changed_RGB)
		{
			num = (uint)outstream_RGB.Position;
			num_bytes_RGB += num;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		return true;
	}

	public override bool chunk_bytes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		if (changed_RGB)
		{
			byteStreamOut.Write(outstream_RGB.GetBuffer(), 0, (int)outstream_RGB.Position);
		}
		return true;
	}

	private bool createAndInitModelsAndCompressors(uint context, ushort[] item)
	{
		if (contexts[context].m_byte_used == null)
		{
			contexts[context].m_byte_used = enc_RGB.createSymbolModel(128u);
			contexts[context].m_rgb_diff_0 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_1 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_2 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_3 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_4 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_5 = enc_RGB.createSymbolModel(256u);
		}
		enc_RGB.initSymbolModel(contexts[context].m_byte_used);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_0);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_1);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_2);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_3);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_4);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_5);
		contexts[context].last_item[0] = item[0];
		contexts[context].last_item[1] = item[1];
		contexts[context].last_item[2] = item[2];
		contexts[context].unused = false;
		return true;
	}
}
internal class LASwriteItemCompressed_RGBNIR14_v4 : LASwriteItemCompressed
{
	private ArithmeticEncoder enc;

	private MemoryStream outstream_RGB;

	private MemoryStream outstream_NIR;

	private ArithmeticEncoder enc_RGB;

	private ArithmeticEncoder enc_NIR;

	private bool changed_RGB;

	private bool changed_NIR;

	private uint num_bytes_RGB;

	private uint num_bytes_NIR;

	private uint current_context;

	private readonly LAScontextRGBNIR14[] contexts = new LAScontextRGBNIR14[4]
	{
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14(),
		new LAScontextRGBNIR14()
	};

	public LASwriteItemCompressed_RGBNIR14_v4(ArithmeticEncoder enc)
	{
		this.enc = enc;
		outstream_RGB = null;
		outstream_NIR = null;
		enc_RGB = null;
		enc_NIR = null;
		num_bytes_RGB = 0u;
		num_bytes_NIR = 0u;
		changed_RGB = false;
		changed_NIR = false;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_rgb_bytes_used = null;
		}
		current_context = 0u;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		if (outstream_RGB == null)
		{
			outstream_RGB = new MemoryStream();
			outstream_NIR = new MemoryStream();
			enc_RGB = new ArithmeticEncoder();
			enc_NIR = new ArithmeticEncoder();
		}
		else
		{
			outstream_RGB.Seek(0L, SeekOrigin.Begin);
			outstream_NIR.Seek(0L, SeekOrigin.Begin);
		}
		enc_RGB.init(outstream_RGB);
		enc_NIR.init(outstream_NIR);
		changed_RGB = false;
		changed_NIR = false;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndCompressors(current_context, item.rgb);
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		ushort[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndCompressors(current_context, last_item);
			}
			last_item = contexts[current_context].last_item;
		}
		int num = 0;
		int num2 = 0;
		bool num3 = (last_item[0] & 0xFF) != (item.rgb[0] & 0xFF);
		bool flag = (last_item[0] & 0xFF00) != (item.rgb[0] & 0xFF00);
		bool flag2 = (last_item[1] & 0xFF) != (item.rgb[1] & 0xFF);
		bool flag3 = (last_item[1] & 0xFF00) != (item.rgb[1] & 0xFF00);
		bool flag4 = (last_item[2] & 0xFF) != (item.rgb[2] & 0xFF);
		bool flag5 = (last_item[2] & 0xFF00) != (item.rgb[2] & 0xFF00);
		bool flag6 = (item.rgb[0] & 0xFF) != (item.rgb[1] & 0xFF) || (item.rgb[0] & 0xFF) != (item.rgb[2] & 0xFF) || (item.rgb[0] & 0xFF00) != (item.rgb[1] & 0xFF00) || (item.rgb[0] & 0xFF00) != (item.rgb[2] & 0xFF00);
		uint num4 = (num3 ? 1u : 0u);
		num4 |= (uint)(flag ? 2 : 0);
		num4 |= (uint)(flag2 ? 4 : 0);
		num4 |= (uint)(flag3 ? 8 : 0);
		num4 |= (uint)(flag4 ? 16 : 0);
		num4 |= (uint)(flag5 ? 32 : 0);
		num4 |= (uint)(flag6 ? 64 : 0);
		enc_RGB.encodeSymbol(contexts[current_context].m_rgb_bytes_used, num4);
		if (num3)
		{
			num = (item.rgb[0] & 0xFF) - (last_item[0] & 0xFF);
			enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_0, (uint)MyDefs.U8_FOLD(num));
		}
		if (flag)
		{
			num2 = (item.rgb[0] >> 8) - (last_item[0] >> 8);
			enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_1, (uint)MyDefs.U8_FOLD(num2));
		}
		if (flag6)
		{
			if (flag2)
			{
				int n = (item.rgb[1] & 0xFF) - MyDefs.U8_CLAMP(num + (last_item[1] & 0xFF));
				enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_2, (uint)MyDefs.U8_FOLD(n));
			}
			if (flag4)
			{
				num = (num + (item.rgb[1] & 0xFF) - (last_item[1] & 0xFF)) / 2;
				int n2 = (item.rgb[2] & 0xFF) - MyDefs.U8_CLAMP(num + (last_item[2] & 0xFF));
				enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_4, (uint)MyDefs.U8_FOLD(n2));
			}
			if (flag3)
			{
				int n3 = (item.rgb[1] >> 8) - MyDefs.U8_CLAMP(num2 + (last_item[1] >> 8));
				enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_3, (uint)MyDefs.U8_FOLD(n3));
			}
			if (flag5)
			{
				num2 = (num2 + (item.rgb[1] >> 8) - (last_item[1] >> 8)) / 2;
				int n4 = (item.rgb[2] >> 8) - MyDefs.U8_CLAMP(num2 + (last_item[2] >> 8));
				enc_RGB.encodeSymbol(contexts[current_context].m_rgb_diff_5, (uint)MyDefs.U8_FOLD(n4));
			}
		}
		if (num4 != 0)
		{
			changed_RGB = true;
		}
		num4 = (((last_item[3] & 0xFF) != (item.rgb[3] & 0xFF)) ? 1u : 0u);
		num4 |= (uint)(((last_item[3] & 0xFF00) != (item.rgb[3] & 0xFF00)) ? 2 : 0);
		enc_NIR.encodeSymbol(contexts[current_context].m_nir_bytes_used, num4);
		if ((num4 & 1) != 0)
		{
			num = (item.rgb[3] & 0xFF) - (last_item[3] & 0xFF);
			enc_NIR.encodeSymbol(contexts[current_context].m_nir_diff_0, (uint)MyDefs.U8_FOLD(num));
		}
		if ((num4 & 2) != 0)
		{
			num2 = (item.rgb[3] >> 8) - (last_item[3] >> 8);
			enc_NIR.encodeSymbol(contexts[current_context].m_nir_diff_1, (uint)MyDefs.U8_FOLD(num2));
		}
		if (num4 != 0)
		{
			changed_NIR = true;
		}
		last_item[0] = item.rgb[0];
		last_item[1] = item.rgb[1];
		last_item[2] = item.rgb[2];
		last_item[3] = item.rgb[3];
		return true;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		enc_RGB.done();
		enc_NIR.done();
		uint num = 0u;
		if (changed_RGB)
		{
			num = (uint)outstream_RGB.Position;
			num_bytes_RGB += num;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		if (changed_NIR)
		{
			num = (uint)outstream_NIR.Position;
			num_bytes_NIR += num;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		return true;
	}

	public override bool chunk_bytes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		if (changed_RGB)
		{
			byteStreamOut.Write(outstream_RGB.GetBuffer(), 0, (int)outstream_RGB.Position);
		}
		if (changed_NIR)
		{
			byteStreamOut.Write(outstream_NIR.GetBuffer(), 0, (int)outstream_NIR.Position);
		}
		return true;
	}

	private bool createAndInitModelsAndCompressors(uint context, ushort[] item)
	{
		if (contexts[context].m_rgb_bytes_used == null)
		{
			contexts[context].m_rgb_bytes_used = enc_RGB.createSymbolModel(128u);
			contexts[context].m_rgb_diff_0 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_1 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_2 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_3 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_4 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_rgb_diff_5 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_nir_bytes_used = enc_RGB.createSymbolModel(4u);
			contexts[context].m_nir_diff_0 = enc_RGB.createSymbolModel(256u);
			contexts[context].m_nir_diff_1 = enc_RGB.createSymbolModel(256u);
		}
		enc_RGB.initSymbolModel(contexts[context].m_rgb_bytes_used);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_0);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_1);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_2);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_3);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_4);
		enc_RGB.initSymbolModel(contexts[context].m_rgb_diff_5);
		enc_NIR.initSymbolModel(contexts[context].m_nir_bytes_used);
		enc_NIR.initSymbolModel(contexts[context].m_nir_diff_0);
		enc_NIR.initSymbolModel(contexts[context].m_nir_diff_1);
		contexts[context].last_item[0] = item[0];
		contexts[context].last_item[1] = item[1];
		contexts[context].last_item[2] = item[2];
		contexts[context].last_item[3] = item[3];
		contexts[context].unused = false;
		return true;
	}
}
internal class LASwriteItemCompressed_WAVEPACKET13_v1 : LASwriteItemCompressed
{
	private ArithmeticEncoder enc;

	private LASwavepacket13 last_item;

	private int last_diff_32;

	private uint sym_last_offset_diff;

	private ArithmeticModel m_packet_index;

	private readonly ArithmeticModel[] m_offset_diff = new ArithmeticModel[4];

	private IntegerCompressor ic_offset_diff;

	private IntegerCompressor ic_packet_size;

	private IntegerCompressor ic_return_point;

	private IntegerCompressor ic_xyz;

	public LASwriteItemCompressed_WAVEPACKET13_v1(ArithmeticEncoder enc)
	{
		this.enc = enc;
		m_packet_index = enc.createSymbolModel(256u);
		m_offset_diff[0] = enc.createSymbolModel(4u);
		m_offset_diff[1] = enc.createSymbolModel(4u);
		m_offset_diff[2] = enc.createSymbolModel(4u);
		m_offset_diff[3] = enc.createSymbolModel(4u);
		ic_offset_diff = new IntegerCompressor(enc, 32u);
		ic_packet_size = new IntegerCompressor(enc, 32u);
		ic_return_point = new IntegerCompressor(enc, 32u);
		ic_xyz = new IntegerCompressor(enc, 32u, 3u);
	}

	public unsafe override bool init(laszip_point item, ref uint context)
	{
		last_diff_32 = 0;
		sym_last_offset_diff = 0u;
		enc.initSymbolModel(m_packet_index);
		enc.initSymbolModel(m_offset_diff[0]);
		enc.initSymbolModel(m_offset_diff[1]);
		enc.initSymbolModel(m_offset_diff[2]);
		enc.initSymbolModel(m_offset_diff[3]);
		ic_offset_diff.initCompressor();
		ic_packet_size.initCompressor();
		ic_return_point.initCompressor();
		ic_xyz.initCompressor();
		fixed (byte* wave_packet = item.wave_packet)
		{
			last_item = *(LASwavepacket13*)(wave_packet + 1);
		}
		return true;
	}

	public unsafe override bool write(laszip_point item, ref uint context)
	{
		enc.encodeSymbol(m_packet_index, item.wave_packet[0]);
		fixed (byte* wave_packet = item.wave_packet)
		{
			LASwavepacket13* ptr = (LASwavepacket13*)(wave_packet + 1);
			ulong num = ptr->offset - last_item.offset;
			int num2 = (int)num;
			if (num == (ulong)num2)
			{
				if (num2 == 0)
				{
					enc.encodeSymbol(m_offset_diff[sym_last_offset_diff], 0u);
					sym_last_offset_diff = 0u;
				}
				else if (num2 == (int)last_item.packet_size)
				{
					enc.encodeSymbol(m_offset_diff[sym_last_offset_diff], 1u);
					sym_last_offset_diff = 1u;
				}
				else
				{
					enc.encodeSymbol(m_offset_diff[sym_last_offset_diff], 2u);
					sym_last_offset_diff = 2u;
					ic_offset_diff.compress(last_diff_32, num2);
					last_diff_32 = num2;
				}
			}
			else
			{
				enc.encodeSymbol(m_offset_diff[sym_last_offset_diff], 3u);
				sym_last_offset_diff = 3u;
				enc.writeInt64(ptr->offset);
			}
			ic_packet_size.compress((int)last_item.packet_size, (int)ptr->packet_size);
			ic_return_point.compress(last_item.return_point.i32, ptr->return_point.i32);
			ic_xyz.compress(last_item.x.i32, ptr->x.i32);
			ic_xyz.compress(last_item.y.i32, ptr->y.i32, 1u);
			ic_xyz.compress(last_item.z.i32, ptr->z.i32, 2u);
			last_item = *ptr;
		}
		return true;
	}
}
internal class LASwriteItemCompressed_WAVEPACKET14_v4 : LASwriteItemCompressed
{
	private ArithmeticEncoder enc;

	private MemoryStream outstream_wavepacket;

	private ArithmeticEncoder enc_wavepacket;

	private bool changed_wavepacket;

	private uint num_bytes_wavepacket;

	private uint current_context;

	private readonly LAScontextWAVEPACKET14[] contexts = new LAScontextWAVEPACKET14[4]
	{
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14(),
		new LAScontextWAVEPACKET14()
	};

	public LASwriteItemCompressed_WAVEPACKET14_v4(ArithmeticEncoder enc)
	{
		this.enc = enc;
		outstream_wavepacket = null;
		enc_wavepacket = null;
		num_bytes_wavepacket = 0u;
		changed_wavepacket = false;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].m_packet_index = null;
		}
		current_context = 0u;
	}

	public override bool init(laszip_point item, ref uint context)
	{
		if (outstream_wavepacket == null)
		{
			outstream_wavepacket = new MemoryStream();
			enc_wavepacket = new ArithmeticEncoder();
		}
		else
		{
			outstream_wavepacket.Seek(0L, SeekOrigin.Begin);
		}
		enc_wavepacket.init(outstream_wavepacket);
		changed_wavepacket = false;
		for (int i = 0; i < 4; i++)
		{
			contexts[i].unused = true;
		}
		current_context = context;
		createAndInitModelsAndCompressors(current_context, item.wave_packet);
		return true;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		byte[] last_item = contexts[current_context].last_item;
		if (current_context != context)
		{
			current_context = context;
			if (contexts[current_context].unused)
			{
				createAndInitModelsAndCompressors(current_context, last_item);
			}
			last_item = contexts[current_context].last_item;
		}
		if (!changed_wavepacket)
		{
			for (int i = 0; i < 29; i++)
			{
				if (item.wave_packet[i] != last_item[i])
				{
					changed_wavepacket = true;
					break;
				}
			}
		}
		enc_wavepacket.encodeSymbol(contexts[current_context].m_packet_index, item.wave_packet[0]);
		LASwavepacket13 lASwavepacket = LASwavepacket13.unpack(item.wave_packet, 1);
		LASwavepacket13 lASwavepacket2 = LASwavepacket13.unpack(last_item, 1);
		ulong num = lASwavepacket.offset - lASwavepacket2.offset;
		int num2 = (int)num;
		if (num == (ulong)num2)
		{
			if (num2 == 0)
			{
				enc_wavepacket.encodeSymbol(contexts[current_context].m_offset_diff[contexts[current_context].sym_last_offset_diff], 0u);
				contexts[current_context].sym_last_offset_diff = 0u;
			}
			else if (num2 == (int)lASwavepacket2.packet_size)
			{
				enc_wavepacket.encodeSymbol(contexts[current_context].m_offset_diff[contexts[current_context].sym_last_offset_diff], 1u);
				contexts[current_context].sym_last_offset_diff = 1u;
			}
			else
			{
				enc_wavepacket.encodeSymbol(contexts[current_context].m_offset_diff[contexts[current_context].sym_last_offset_diff], 2u);
				contexts[current_context].sym_last_offset_diff = 2u;
				contexts[current_context].ic_offset_diff.compress(contexts[current_context].last_diff_32, num2);
				contexts[current_context].last_diff_32 = num2;
			}
		}
		else
		{
			enc_wavepacket.encodeSymbol(contexts[current_context].m_offset_diff[contexts[current_context].sym_last_offset_diff], 3u);
			contexts[current_context].sym_last_offset_diff = 3u;
			enc_wavepacket.writeInt64(lASwavepacket.offset);
		}
		contexts[current_context].ic_packet_size.compress((int)lASwavepacket2.packet_size, (int)lASwavepacket.packet_size);
		contexts[current_context].ic_return_point.compress(lASwavepacket2.return_point.i32, lASwavepacket.return_point.i32);
		contexts[current_context].ic_xyz.compress(lASwavepacket2.x.i32, lASwavepacket.x.i32);
		contexts[current_context].ic_xyz.compress(lASwavepacket2.y.i32, lASwavepacket.y.i32, 1u);
		contexts[current_context].ic_xyz.compress(lASwavepacket2.z.i32, lASwavepacket.z.i32, 2u);
		Array.Copy(item.wave_packet, last_item, 29);
		return true;
	}

	public override bool chunk_sizes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		enc_wavepacket.done();
		uint num = 0u;
		if (changed_wavepacket)
		{
			num = (uint)outstream_wavepacket.Position;
			num_bytes_wavepacket += num;
		}
		byteStreamOut.Write(BitConverter.GetBytes(num), 0, 4);
		return true;
	}

	public override bool chunk_bytes()
	{
		Stream byteStreamOut = enc.getByteStreamOut();
		if (changed_wavepacket)
		{
			byteStreamOut.Write(outstream_wavepacket.GetBuffer(), 0, (int)outstream_wavepacket.Position);
		}
		return true;
	}

	private bool createAndInitModelsAndCompressors(uint context, byte[] item)
	{
		if (contexts[context].m_packet_index == null)
		{
			contexts[context].m_packet_index = enc_wavepacket.createSymbolModel(256u);
			contexts[context].m_offset_diff[0] = enc_wavepacket.createSymbolModel(4u);
			contexts[context].m_offset_diff[1] = enc_wavepacket.createSymbolModel(4u);
			contexts[context].m_offset_diff[2] = enc_wavepacket.createSymbolModel(4u);
			contexts[context].m_offset_diff[3] = enc_wavepacket.createSymbolModel(4u);
			contexts[context].ic_offset_diff = new IntegerCompressor(enc_wavepacket, 32u);
			contexts[context].ic_packet_size = new IntegerCompressor(enc_wavepacket, 32u);
			contexts[context].ic_return_point = new IntegerCompressor(enc_wavepacket, 32u);
			contexts[context].ic_xyz = new IntegerCompressor(enc_wavepacket, 32u, 3u);
		}
		enc_wavepacket.initSymbolModel(contexts[context].m_packet_index);
		enc_wavepacket.initSymbolModel(contexts[context].m_offset_diff[0]);
		enc_wavepacket.initSymbolModel(contexts[context].m_offset_diff[1]);
		enc_wavepacket.initSymbolModel(contexts[context].m_offset_diff[2]);
		enc_wavepacket.initSymbolModel(contexts[context].m_offset_diff[3]);
		contexts[context].ic_offset_diff.initCompressor();
		contexts[context].ic_packet_size.initCompressor();
		contexts[context].ic_return_point.initCompressor();
		contexts[context].ic_xyz.initCompressor();
		contexts[context].last_diff_32 = 0;
		contexts[context].sym_last_offset_diff = 0u;
		Array.Copy(item, contexts[context].last_item, 29);
		contexts[context].unused = false;
		return true;
	}
}
internal abstract class LASwriteItemRaw : LASwriteItem
{
	protected Stream outstream;

	public LASwriteItemRaw()
	{
		outstream = null;
	}

	public bool init(Stream outstream)
	{
		if (outstream == null)
		{
			return false;
		}
		this.outstream = outstream;
		return true;
	}
}
internal class LASwriteItemRaw_BYTE : LASwriteItemRaw
{
	private uint number;

	public LASwriteItemRaw_BYTE(uint number)
	{
		this.number = number;
	}

	public override bool write(laszip_point item, ref uint context)
	{
		try
		{
			outstream.Write(item.extra_bytes, 0, (int)number);
		}
		catch
		{
			return false;
		}
		return true;
	}
}
internal class LASwriteItemRaw_GPSTIME11 : LASwriteItemRaw
{
	public override bool write(laszip_point item, ref uint context)
	{
		try
		{
			outstream.Write(BitConverter.GetBytes(item.gps_time), 0, 8);
		}
		catch
		{
			return false;
		}
		return true;
	}
}
internal class LASwriteItemRaw_POINT10 : LASwriteItemRaw
{
	private readonly byte[] buffer = new byte[20];

	public unsafe override bool write(laszip_point item, ref uint context)
	{
		fixed (byte* ptr = buffer)
		{
			LASpoint10* ptr2 = (LASpoint10*)ptr;
			ptr2->X = item.X;
			ptr2->Y = item.Y;
			ptr2->Z = item.Z;
			ptr2->intensity = item.intensity;
			ptr2->flags = item.flags;
			ptr2->classification_and_classification_flags = item.classification_and_classification_flags;
			ptr2->scan_angle_rank = item.scan_angle_rank;
			ptr2->user_data = item.user_data;
			ptr2->point_source_ID = item.point_source_ID;
		}
		try
		{
			outstream.Write(buffer, 0, 20);
		}
		catch
		{
			return false;
		}
		return true;
	}
}
internal class LASwriteItemRaw_POINT14 : LASwriteItemRaw
{
	private readonly byte[] buffer = new byte[30];

	public unsafe override bool write(laszip_point item, ref uint context)
	{
		fixed (byte* ptr = buffer)
		{
			LASpoint14* ptr2 = (LASpoint14*)ptr;
			ptr2->X = item.X;
			ptr2->Y = item.Y;
			ptr2->Z = item.Z;
			ptr2->intensity = item.intensity;
			ptr2->scan_direction_flag = item.scan_direction_flag;
			ptr2->edge_of_flight_line = item.edge_of_flight_line;
			ptr2->classification = (byte)(item.classification_and_classification_flags & 0x1F);
			ptr2->user_data = item.user_data;
			ptr2->point_source_ID = item.point_source_ID;
			if (item.extended_point_type != 0)
			{
				ptr2->classification_flags = (byte)((item.extended_classification_flags & 8) | (item.classification_and_classification_flags >> 5));
				if (item.classification == 0)
				{
					ptr2->classification = item.extended_classification;
				}
				ptr2->scanner_channel = item.extended_scanner_channel;
				ptr2->return_number = item.extended_return_number;
				ptr2->number_of_returns = item.extended_number_of_returns;
				ptr2->scan_angle = item.extended_scan_angle;
			}
			else
			{
				ptr2->classification_flags = (byte)(item.classification_and_classification_flags >> 5);
				ptr2->scanner_channel = 0;
				ptr2->return_number = item.return_number;
				ptr2->number_of_returns = item.number_of_returns;
				ptr2->scan_angle = MyDefs.I16_QUANTIZE((float)item.scan_angle_rank / 0.006f);
			}
			ptr2->gps_time = item.gps_time;
		}
		try
		{
			outstream.Write(buffer, 0, 30);
		}
		catch
		{
			return false;
		}
		return true;
	}
}
internal class LASwriteItemRaw_RGB12 : LASwriteItemRaw
{
	public override bool write(laszip_point item, ref uint context)
	{
		try
		{
			outstream.Write(BitConverter.GetBytes(item.rgb[0]), 0, 2);
			outstream.Write(BitConverter.GetBytes(item.rgb[1]), 0, 2);
			outstream.Write(BitConverter.GetBytes(item.rgb[2]), 0, 2);
		}
		catch
		{
			return false;
		}
		return true;
	}
}
internal class LASwriteItemRaw_RGBNIR14 : LASwriteItemRaw
{
	public override bool write(laszip_point item, ref uint context)
	{
		try
		{
			outstream.Write(BitConverter.GetBytes(item.rgb[0]), 0, 2);
			outstream.Write(BitConverter.GetBytes(item.rgb[1]), 0, 2);
			outstream.Write(BitConverter.GetBytes(item.rgb[2]), 0, 2);
			outstream.Write(BitConverter.GetBytes(item.rgb[3]), 0, 2);
		}
		catch
		{
			return false;
		}
		return true;
	}
}
internal class LASwriteItemRaw_WAVEPACKET13 : LASwriteItemRaw
{
	public override bool write(laszip_point item, ref uint context)
	{
		try
		{
			outstream.Write(item.wave_packet, 0, 29);
		}
		catch
		{
			return false;
		}
		return true;
	}
}
internal class LASwritePoint
{
	private Stream outstream;

	private uint num_writers;

	private LASwriteItem[] writers;

	private LASwriteItem[] writers_raw;

	private LASwriteItem[] writers_compressed;

	private ArithmeticEncoder enc;

	private bool layered_las14_compression;

	private uint chunk_size;

	private uint chunk_count;

	private bool init_chunking;

	private List<uint> chunk_sizes = new List<uint>();

	private List<uint> chunk_bytes = new List<uint>();

	private long chunk_start_position;

	private long chunk_table_start_position;

	public LASwritePoint()
	{
		outstream = null;
		num_writers = 0u;
		writers = null;
		writers_raw = null;
		writers_compressed = null;
		enc = null;
		layered_las14_compression = false;
		chunk_size = uint.MaxValue;
		chunk_count = 0u;
		init_chunking = false;
		chunk_table_start_position = 0L;
		chunk_start_position = 0L;
	}

	public bool setup(uint num_items, LASitem[] items, LASzip laszip = null)
	{
		if (laszip != null)
		{
			if (num_items == 0)
			{
				return false;
			}
			if (items == null)
			{
				return false;
			}
			if (num_items != laszip.num_items)
			{
				return false;
			}
			if (items != laszip.items)
			{
				return false;
			}
		}
		enc = null;
		if (laszip != null && laszip.compressor != 0)
		{
			if (laszip.coder != 0)
			{
				return false;
			}
			enc = new ArithmeticEncoder();
			layered_las14_compression = laszip.compressor == 3;
		}
		writers = null;
		num_writers = num_items;
		chunk_size = uint.MaxValue;
		writers_raw = new LASwriteItem[num_writers];
		for (uint num = 0u; num < num_writers; num++)
		{
			switch (items[num].type)
			{
			case LASitem.Type.POINT10:
				writers_raw[num] = new LASwriteItemRaw_POINT10();
				break;
			case LASitem.Type.GPSTIME11:
				writers_raw[num] = new LASwriteItemRaw_GPSTIME11();
				break;
			case LASitem.Type.RGB12:
			case LASitem.Type.RGB14:
				writers_raw[num] = new LASwriteItemRaw_RGB12();
				break;
			case LASitem.Type.BYTE:
			case LASitem.Type.BYTE14:
				writers_raw[num] = new LASwriteItemRaw_BYTE(items[num].size);
				break;
			case LASitem.Type.POINT14:
				writers_raw[num] = new LASwriteItemRaw_POINT14();
				break;
			case LASitem.Type.RGBNIR14:
				writers_raw[num] = new LASwriteItemRaw_RGBNIR14();
				break;
			case LASitem.Type.WAVEPACKET13:
			case LASitem.Type.WAVEPACKET14:
				writers_raw[num] = new LASwriteItemRaw_WAVEPACKET13();
				break;
			default:
				return false;
			}
		}
		if (enc != null)
		{
			writers_compressed = new LASwriteItem[num_writers];
			for (uint num2 = 0u; num2 < num_writers; num2++)
			{
				switch (items[num2].type)
				{
				case LASitem.Type.POINT10:
					if (items[num2].version == 1)
					{
						throw new NotSupportedException("Version 1 POINT10 is no longer supported, use version 2.");
					}
					if (items[num2].version == 2)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_POINT10_v2(enc);
						break;
					}
					return false;
				case LASitem.Type.GPSTIME11:
					if (items[num2].version == 1)
					{
						throw new NotSupportedException("Version 1 GPSTIME11 is no longer supported, use version 2.");
					}
					if (items[num2].version == 2)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_GPSTIME11_v2(enc);
						break;
					}
					return false;
				case LASitem.Type.RGB12:
					if (items[num2].version == 1)
					{
						throw new NotSupportedException("Version 1 RGB12 is no longer supported, use version 2.");
					}
					if (items[num2].version == 2)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_RGB12_v2(enc);
						break;
					}
					return false;
				case LASitem.Type.BYTE:
					if (items[num2].version == 1)
					{
						throw new NotSupportedException("Version 1 BYTE is no longer supported, use version 2.");
					}
					if (items[num2].version == 2)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_BYTE_v2(enc, items[num2].size);
						break;
					}
					return false;
				case LASitem.Type.POINT14:
					if (items[num2].version == 3)
					{
						throw new NotSupportedException("Version 3 POINT14 is no longer supported, use version 4.");
					}
					if (items[num2].version == 4)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_POINT14_v4(enc);
						break;
					}
					return false;
				case LASitem.Type.RGB14:
					if (items[num2].version == 3)
					{
						throw new NotSupportedException("Version 3 RGB14 is no longer supported, use version 4.");
					}
					if (items[num2].version == 4)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_RGB14_v4(enc);
						break;
					}
					return false;
				case LASitem.Type.RGBNIR14:
					if (items[num2].version == 3)
					{
						throw new NotSupportedException("Version 3 RGBNIR14 is no longer supported, use version 4.");
					}
					if (items[num2].version == 4)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_RGBNIR14_v4(enc);
						break;
					}
					return false;
				case LASitem.Type.BYTE14:
					if (items[num2].version == 3)
					{
						throw new NotSupportedException("Version 3 BYTE14 is no longer supported, use version 4.");
					}
					if (items[num2].version == 4)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_BYTE14_v4(enc, items[num2].size);
						break;
					}
					return false;
				case LASitem.Type.WAVEPACKET13:
					if (items[num2].version == 1)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_WAVEPACKET13_v1(enc);
						break;
					}
					return false;
				case LASitem.Type.WAVEPACKET14:
					if (items[num2].version == 3)
					{
						throw new NotSupportedException("Version 3 WAVEPACKET14 is no longer supported, use version 4.");
					}
					if (items[num2].version == 4)
					{
						writers_compressed[num2] = new LASwriteItemCompressed_WAVEPACKET14_v4(enc);
						break;
					}
					return false;
				default:
					return false;
				}
			}
			if (laszip.compressor != 1)
			{
				if (laszip.chunk_size != 0)
				{
					chunk_size = laszip.chunk_size;
				}
				chunk_count = 0u;
				init_chunking = true;
			}
		}
		return true;
	}

	public bool init(Stream outstream)
	{
		if (outstream == null)
		{
			return false;
		}
		this.outstream = outstream;
		if (init_chunking)
		{
			init_chunking = false;
			if (outstream.CanSeek)
			{
				chunk_table_start_position = outstream.Position;
			}
			else
			{
				chunk_table_start_position = -1L;
			}
			outstream.Write(BitConverter.GetBytes(chunk_table_start_position), 0, 8);
			chunk_start_position = outstream.Position;
		}
		for (uint num = 0u; num < num_writers; num++)
		{
			((LASwriteItemRaw)writers_raw[num]).init(outstream);
		}
		if (enc != null)
		{
			writers = null;
		}
		else
		{
			writers = writers_raw;
		}
		return true;
	}

	public bool write(laszip_point point)
	{
		uint context = 0u;
		if (chunk_count == chunk_size)
		{
			if (layered_las14_compression)
			{
				outstream.Write(BitConverter.GetBytes(chunk_count), 0, 4);
				for (uint num = 0u; num < num_writers; num++)
				{
					((LASwriteItemCompressed)writers[num]).chunk_sizes();
				}
				for (uint num2 = 0u; num2 < num_writers; num2++)
				{
					((LASwriteItemCompressed)writers[num2]).chunk_bytes();
				}
			}
			else
			{
				enc.done();
			}
			add_chunk_to_table();
			init(outstream);
			chunk_count = 0u;
		}
		chunk_count++;
		if (writers != null)
		{
			for (uint num3 = 0u; num3 < num_writers; num3++)
			{
				writers[num3].write(point, ref context);
			}
		}
		else
		{
			for (uint num4 = 0u; num4 < num_writers; num4++)
			{
				writers_raw[num4].write(point, ref context);
				((LASwriteItemCompressed)writers_compressed[num4]).init(point, ref context);
			}
			writers = writers_compressed;
			enc.init(outstream);
		}
		return true;
	}

	public bool chunk()
	{
		if (chunk_start_position == 0L || chunk_size != uint.MaxValue)
		{
			return false;
		}
		if (layered_las14_compression)
		{
			outstream.Write(BitConverter.GetBytes(chunk_count), 0, 4);
			for (uint num = 0u; num < num_writers; num++)
			{
				((LASwriteItemCompressed)writers[num]).chunk_sizes();
			}
			for (uint num2 = 0u; num2 < num_writers; num2++)
			{
				((LASwriteItemCompressed)writers[num2]).chunk_bytes();
			}
		}
		else
		{
			enc.done();
		}
		add_chunk_to_table();
		init(outstream);
		chunk_count = 0u;
		return true;
	}

	public bool done()
	{
		if (writers == writers_compressed)
		{
			if (layered_las14_compression)
			{
				outstream.Write(BitConverter.GetBytes(chunk_count), 0, 4);
				for (uint num = 0u; num < num_writers; num++)
				{
					((LASwriteItemCompressed)writers[num]).chunk_sizes();
				}
				for (uint num2 = 0u; num2 < num_writers; num2++)
				{
					((LASwriteItemCompressed)writers[num2]).chunk_bytes();
				}
			}
			else
			{
				enc.done();
			}
			if (chunk_start_position != 0L)
			{
				if (chunk_count != 0)
				{
					add_chunk_to_table();
				}
				return write_chunk_table();
			}
		}
		else if (writers == null && chunk_start_position != 0L)
		{
			return write_chunk_table();
		}
		return true;
	}

	private bool add_chunk_to_table()
	{
		long position = outstream.Position;
		if (chunk_size == uint.MaxValue)
		{
			chunk_sizes.Add(chunk_count);
		}
		chunk_bytes.Add((uint)(position - chunk_start_position));
		chunk_start_position = position;
		return true;
	}

	private bool write_chunk_table()
	{
		long position = outstream.Position;
		if (chunk_table_start_position != -1)
		{
			try
			{
				outstream.Seek(chunk_table_start_position, SeekOrigin.Begin);
				outstream.Write(BitConverter.GetBytes(position), 0, 8);
				outstream.Seek(position, SeekOrigin.Begin);
			}
			catch
			{
				return false;
			}
		}
		try
		{
			uint value = 0u;
			outstream.Write(BitConverter.GetBytes(value), 0, 4);
			outstream.Write(BitConverter.GetBytes(chunk_bytes.Count), 0, 4);
		}
		catch
		{
			return false;
		}
		if (chunk_bytes.Count > 0)
		{
			enc.init(outstream);
			IntegerCompressor integerCompressor = new IntegerCompressor(enc, 32u, 2u);
			integerCompressor.initCompressor();
			for (int i = 0; i < chunk_bytes.Count; i++)
			{
				if (chunk_size == uint.MaxValue)
				{
					integerCompressor.compress((int)((i != 0) ? chunk_sizes[i - 1] : 0), (int)chunk_sizes[i]);
				}
				integerCompressor.compress((int)((i != 0) ? chunk_bytes[i - 1] : 0), (int)chunk_bytes[i], 1u);
			}
			enc.done();
		}
		if (chunk_table_start_position == -1)
		{
			try
			{
				outstream.Write(BitConverter.GetBytes(position), 0, 8);
			}
			catch
			{
				return false;
			}
		}
		return true;
	}
}
internal class LASzip
{
	public const int VERSION_MAJOR = 3;

	public const int VERSION_MINOR = 2;

	public const int VERSION_REVISION = 9;

	public const int VERSION_BUILD_DATE = 181227;

	public const int COMPRESSOR_NONE = 0;

	public const int COMPRESSOR_POINTWISE = 1;

	public const int COMPRESSOR_POINTWISE_CHUNKED = 2;

	public const int COMPRESSOR_LAYERED_CHUNKED = 3;

	public const int COMPRESSOR_TOTAL_NUMBER_OF = 4;

	public const int COMPRESSOR_CHUNKED = 2;

	public const int COMPRESSOR_NOT_CHUNKED = 1;

	public const int COMPRESSOR_DEFAULT = 2;

	public const int CODER_ARITHMETIC = 0;

	private const int CODER_TOTAL_NUMBER_OF = 1;

	internal const int CHUNK_SIZE_DEFAULT = 50000;

	public byte[] bytes;

	public ushort compressor;

	public ushort coder;

	public byte version_major;

	public byte version_minor;

	public ushort version_revision;

	public uint options;

	public uint chunk_size;

	public long number_of_special_evlrs;

	public long offset_to_special_evlrs;

	public ushort num_items;

	public LASitem[] items;

	private string error_string;

	public bool check_compressor(ushort compressor)
	{
		if (compressor < 4)
		{
			return true;
		}
		return return_error($"compressor {compressor} not supported");
	}

	public bool check_coder(ushort coder)
	{
		if (coder < 1)
		{
			return true;
		}
		return return_error($"coder {coder} not supported");
	}

	public bool check_item(LASitem item)
	{
		switch (item.type)
		{
		case LASitem.Type.POINT10:
			if (item.size != 20)
			{
				return return_error("POINT10 has size != 20");
			}
			if (item.version > 2)
			{
				return return_error("POINT10 has version > 2");
			}
			break;
		case LASitem.Type.GPSTIME11:
			if (item.size != 8)
			{
				return return_error("GPSTIME11 has size != 8");
			}
			if (item.version > 2)
			{
				return return_error("GPSTIME11 has version > 2");
			}
			break;
		case LASitem.Type.RGB12:
			if (item.size != 6)
			{
				return return_error("RGB12 has size != 6");
			}
			if (item.version > 2)
			{
				return return_error("RGB12 has version > 2");
			}
			break;
		case LASitem.Type.BYTE:
			if (item.size < 1)
			{
				return return_error("BYTE has size < 1");
			}
			if (item.version > 2)
			{
				return return_error("BYTE has version > 2");
			}
			break;
		case LASitem.Type.POINT14:
			if (item.size != 30)
			{
				return return_error("POINT14 has size != 30");
			}
			if (item.version != 0 && item.version != 2 && item.version != 3 && item.version != 4)
			{
				return return_error("POINT14 has version != 0 and != 2 and != 3 and != 4");
			}
			break;
		case LASitem.Type.RGB14:
			if (item.size != 6)
			{
				return return_error("RGB14 has size != 6");
			}
			if (item.version != 0 && item.version != 2 && item.version != 3 && item.version != 4)
			{
				return return_error("RGB14 has version != 0 and != 2 and != 3 and != 4");
			}
			break;
		case LASitem.Type.RGBNIR14:
			if (item.size != 8)
			{
				return return_error("RGBNIR14 has size != 8");
			}
			if (item.version != 0 && item.version != 2 && item.version != 3 && item.version != 4)
			{
				return return_error("RGBNIR14 has version != 0 and != 2 and != 3 and != 4");
			}
			break;
		case LASitem.Type.BYTE14:
			if (item.size < 1)
			{
				return return_error("BYTE14 has size < 1");
			}
			if (item.version != 0 && item.version != 2 && item.version != 3 && item.version != 4)
			{
				return return_error("BYTE14 has version != 0 and != 2 and != 3 and != 4");
			}
			break;
		case LASitem.Type.WAVEPACKET13:
			if (item.size != 29)
			{
				return return_error("WAVEPACKET13 has size != 29");
			}
			if (item.version > 1)
			{
				return return_error("WAVEPACKET13 has version > 1");
			}
			break;
		case LASitem.Type.WAVEPACKET14:
			if (item.size != 29)
			{
				return return_error("WAVEPACKET14 has size != 29");
			}
			if (item.version != 0 && item.version != 3 && item.version != 4)
			{
				return return_error("WAVEPACKET14 has version != 0 and != 3 and != 4");
			}
			break;
		default:
			return return_error($"item unknown ({item.type},{item.size},{item.version})");
		}
		return true;
	}

	public bool check_items(ushort num_items, LASitem[] items, ushort point_size = 0)
	{
		if (num_items == 0)
		{
			return return_error("number of items cannot be zero");
		}
		if (items == null)
		{
			return return_error("items pointer cannot be NULL");
		}
		ushort num = 0;
		for (int i = 0; i < num_items; i++)
		{
			if (!check_item(items[i]))
			{
				return false;
			}
			num += items[i].size;
		}
		if (point_size != 0 && point_size != num)
		{
			return return_error($"point has size of {point_size} but items only add up to {num} bytes");
		}
		return true;
	}

	public bool check(ushort point_size = 0)
	{
		if (!check_compressor(compressor))
		{
			return false;
		}
		if (!check_coder(coder))
		{
			return false;
		}
		if (!check_items(num_items, items, point_size))
		{
			return false;
		}
		return true;
	}

	public bool setup(out ushort num_items, out LASitem[] items, byte point_type, ushort point_size, ushort compressor = 0)
	{
		num_items = 0;
		items = null;
		bool flag = false;
		bool flag2 = false;
		bool flag3 = false;
		bool flag4 = false;
		bool flag5 = false;
		bool flag6 = false;
		int num = 0;
		if ((options & 1) != 0)
		{
			flag = true;
		}
		switch (point_type)
		{
		case 0:
			num = point_size - 20;
			break;
		case 1:
			flag3 = true;
			num = point_size - 28;
			break;
		case 2:
			flag4 = true;
			num = point_size - 26;
			break;
		case 3:
			flag3 = true;
			flag4 = true;
			num = point_size - 34;
			break;
		case 4:
			flag3 = true;
			flag6 = true;
			num = point_size - 57;
			break;
		case 5:
			flag3 = true;
			flag4 = true;
			flag6 = true;
			num = point_size - 63;
			break;
		case 6:
			flag2 = true;
			num = point_size - 30;
			break;
		case 7:
			flag2 = true;
			flag4 = true;
			num = point_size - 36;
			break;
		case 8:
			flag2 = true;
			flag4 = true;
			flag5 = true;
			num = point_size - 38;
			break;
		case 9:
			flag2 = true;
			flag6 = true;
			num = point_size - 59;
			break;
		case 10:
			flag2 = true;
			flag4 = true;
			flag5 = true;
			flag6 = true;
			num = point_size - 67;
			break;
		default:
			return return_error($"point type {point_type} unknown");
		}
		if (num < 0)
		{
			Console.Error.WriteLine("WARNING: point size {0} too small by {1} bytes for point type {2}. assuming point_size of {3}", point_size, -num, point_type, point_size - num);
			num = 0;
		}
		if (flag2 && flag)
		{
			num += 5;
			flag3 = true;
			flag2 = false;
			if (flag5)
			{
				num += 2;
				flag5 = false;
			}
		}
		num_items = (ushort)((uint)(1 + (flag3 ? 1 : 0) + (flag4 ? 1 : 0) + (flag6 ? 1 : 0)) + ((num != 0) ? 1u : 0u));
		items = new LASitem[num_items];
		ushort num2 = 1;
		if (flag2)
		{
			items[0] = new LASitem();
			items[0].type = LASitem.Type.POINT14;
			items[0].size = 30;
			items[0].version = 0;
		}
		else
		{
			items[0] = new LASitem();
			items[0].type = LASitem.Type.POINT10;
			items[0].size = 20;
			items[0].version = 0;
		}
		if (flag3)
		{
			items[num2] = new LASitem();
			items[num2].type = LASitem.Type.GPSTIME11;
			items[num2].size = 8;
			items[num2].version = 0;
			num2++;
		}
		if (flag4)
		{
			items[num2] = new LASitem();
			if (flag2)
			{
				if (flag5)
				{
					items[num2].type = LASitem.Type.RGBNIR14;
					items[num2].size = 8;
					items[num2].version = 0;
				}
				else
				{
					items[num2].type = LASitem.Type.RGB14;
					items[num2].size = 6;
					items[num2].version = 0;
				}
			}
			else
			{
				items[num2].type = LASitem.Type.RGB12;
				items[num2].size = 6;
				items[num2].version = 0;
			}
			num2++;
		}
		if (flag6)
		{
			items[num2] = new LASitem();
			if (flag2)
			{
				items[num2].type = LASitem.Type.WAVEPACKET14;
				items[num2].size = 29;
				items[num2].version = 0;
			}
			else
			{
				items[num2].type = LASitem.Type.WAVEPACKET13;
				items[num2].size = 29;
				items[num2].version = 0;
			}
			num2++;
		}
		if (num != 0)
		{
			items[num2] = new LASitem();
			if (flag2)
			{
				items[num2].type = LASitem.Type.BYTE14;
				items[num2].size = (ushort)num;
				items[num2].version = 0;
			}
			else
			{
				items[num2].type = LASitem.Type.BYTE;
				items[num2].size = (ushort)num;
				items[num2].version = 0;
			}
			num2++;
		}
		if (compressor != 0)
		{
			request_version(2);
		}
		return true;
	}

	public bool is_standard(ushort num_items, LASitem[] items, out byte point_type, out ushort record_length)
	{
		point_type = 127;
		record_length = 0;
		if (items == null)
		{
			return return_error("LASitem array is zero");
		}
		for (int i = 0; i < num_items; i++)
		{
			record_length += items[i].size;
		}
		if (num_items < 1)
		{
			return return_error("less than one LASitem entries");
		}
		if (num_items > 5)
		{
			return return_error("more than five LASitem entries");
		}
		if (items[0].is_type(LASitem.Type.POINT10))
		{
			if (num_items == 1)
			{
				point_type = 0;
				return true;
			}
			if (items[1].is_type(LASitem.Type.GPSTIME11))
			{
				if (num_items == 2)
				{
					point_type = 1;
					return true;
				}
				if (items[2].is_type(LASitem.Type.RGB12))
				{
					if (num_items == 3)
					{
						point_type = 3;
						return true;
					}
					if (items[3].is_type(LASitem.Type.WAVEPACKET13))
					{
						if (num_items == 4)
						{
							point_type = 5;
							return true;
						}
						if (items[4].is_type(LASitem.Type.BYTE) && num_items == 5)
						{
							point_type = 5;
							return true;
						}
					}
					else if (items[3].is_type(LASitem.Type.BYTE) && num_items == 4)
					{
						point_type = 3;
						return true;
					}
				}
				else if (items[2].is_type(LASitem.Type.WAVEPACKET13))
				{
					if (num_items == 3)
					{
						point_type = 4;
						return true;
					}
					if (items[3].is_type(LASitem.Type.BYTE) && num_items == 4)
					{
						point_type = 4;
						return true;
					}
				}
				else if (items[2].is_type(LASitem.Type.BYTE) && num_items == 3)
				{
					point_type = 1;
					return true;
				}
			}
			else if (items[1].is_type(LASitem.Type.RGB12))
			{
				if (num_items == 2)
				{
					point_type = 2;
					return true;
				}
				if (items[2].is_type(LASitem.Type.BYTE) && num_items == 3)
				{
					point_type = 2;
					return true;
				}
			}
			else if (items[1].is_type(LASitem.Type.BYTE) && num_items == 2)
			{
				point_type = 0;
				return true;
			}
		}
		else if (items[0].is_type(LASitem.Type.POINT14))
		{
			if (num_items == 1)
			{
				point_type = 6;
				return true;
			}
			if (items[1].is_type(LASitem.Type.RGB14) || items[1].is_type(LASitem.Type.RGB12))
			{
				if (num_items == 2)
				{
					point_type = 7;
					return true;
				}
				if ((items[2].is_type(LASitem.Type.BYTE) || items[2].is_type(LASitem.Type.BYTE14)) && num_items == 3)
				{
					point_type = 7;
					return true;
				}
			}
			else if (items[1].is_type(LASitem.Type.RGBNIR14))
			{
				if (num_items == 2)
				{
					point_type = 8;
					return true;
				}
				if (items[2].is_type(LASitem.Type.WAVEPACKET13) || items[2].is_type(LASitem.Type.WAVEPACKET14))
				{
					if (num_items == 3)
					{
						point_type = 10;
						return true;
					}
					if ((items[3].is_type(LASitem.Type.BYTE) || items[3].is_type(LASitem.Type.BYTE14)) && num_items == 4)
					{
						point_type = 10;
						return true;
					}
				}
				else if ((items[2].is_type(LASitem.Type.BYTE) || items[2].is_type(LASitem.Type.BYTE14)) && num_items == 3)
				{
					point_type = 8;
					return true;
				}
			}
			else if (items[1].is_type(LASitem.Type.WAVEPACKET13) || items[1].is_type(LASitem.Type.WAVEPACKET14))
			{
				if (num_items == 2)
				{
					point_type = 9;
					return true;
				}
				if ((items[2].is_type(LASitem.Type.BYTE) || items[2].is_type(LASitem.Type.BYTE14)) && num_items == 3)
				{
					point_type = 9;
					return true;
				}
			}
			else if ((items[1].is_type(LASitem.Type.BYTE) || items[1].is_type(LASitem.Type.BYTE14)) && num_items == 2)
			{
				point_type = 6;
				return true;
			}
		}
		else
		{
			return_error("first LASitem is neither POINT10 nor POINT14");
		}
		return return_error("LASitem array does not match LAS specification 1.4");
	}

	public bool is_standard(out byte point_type, out ushort record_length)
	{
		return is_standard(num_items, items, out point_type, out record_length);
	}

	public unsafe bool unpack(byte[] bytes, int num)
	{
		if (num < 34)
		{
			return return_error("too few bytes to unpack");
		}
		if ((num - 34) % 6 != 0)
		{
			return return_error("wrong number bytes to unpack");
		}
		if ((num - 34) / 6 == 0)
		{
			return return_error("zero items to unpack");
		}
		num_items = (ushort)((num - 34) / 6);
		items = new LASitem[num_items];
		fixed (byte* ptr = bytes)
		{
			byte* ptr2 = ptr;
			compressor = *(ushort*)ptr2;
			ptr2 += 2;
			coder = *(ushort*)ptr2;
			ptr2 += 2;
			version_major = *ptr2;
			ptr2++;
			version_minor = *ptr2;
			ptr2++;
			version_revision = *(ushort*)ptr2;
			ptr2 += 2;
			options = *(uint*)ptr2;
			ptr2 += 4;
			chunk_size = *(uint*)ptr2;
			ptr2 += 4;
			number_of_special_evlrs = *(long*)ptr2;
			ptr2 += 8;
			offset_to_special_evlrs = *(long*)ptr2;
			ptr2 += 8;
			num_items = *(ushort*)ptr2;
			ptr2 += 2;
			for (int i = 0; i < num_items; i++)
			{
				items[i] = new LASitem();
				items[i].type = (LASitem.Type)(*(ushort*)ptr2);
				ptr2 += 2;
				items[i].size = *(ushort*)ptr2;
				ptr2 += 2;
				items[i].version = *(ushort*)ptr2;
				ptr2 += 2;
			}
			for (int j = 0; j < num_items; j++)
			{
				if (!check_item(items[j]))
				{
					return false;
				}
			}
			return true;
		}
	}

	public unsafe bool pack(out byte[] bytes, ref int num)
	{
		bytes = null;
		num = 0;
		if (!check(0))
		{
			return false;
		}
		num = 34 + 6 * num_items;
		this.bytes = (bytes = new byte[num]);
		fixed (byte* ptr = bytes)
		{
			byte* ptr2 = ptr;
			*(ushort*)ptr2 = compressor;
			ptr2 += 2;
			*(ushort*)ptr2 = coder;
			ptr2 += 2;
			*ptr2 = version_major;
			ptr2++;
			*ptr2 = version_minor;
			ptr2++;
			*(ushort*)ptr2 = version_revision;
			ptr2 += 2;
			*(uint*)ptr2 = options;
			ptr2 += 4;
			*(uint*)ptr2 = chunk_size;
			ptr2 += 4;
			*(long*)ptr2 = number_of_special_evlrs;
			ptr2 += 8;
			*(long*)ptr2 = offset_to_special_evlrs;
			ptr2 += 8;
			*(ushort*)ptr2 = num_items;
			ptr2 += 2;
			for (int i = 0; i < num_items; i++)
			{
				*(ushort*)ptr2 = (ushort)items[i].type;
				ptr2 += 2;
				*(ushort*)ptr2 = items[i].size;
				ptr2 += 2;
				*(ushort*)ptr2 = items[i].version;
				ptr2 += 2;
			}
			return true;
		}
	}

	internal bool request_compatibility_mode(ushort requested_compatibility_mode = 0)
	{
		if (num_items != 0)
		{
			return return_error("request compatibility mode before calling setup()");
		}
		if (requested_compatibility_mode > 1)
		{
			return return_error("compatibility mode larger than 1 not supported");
		}
		if (requested_compatibility_mode != 0)
		{
			options |= 1u;
		}
		else
		{
			options &= 4294967294u;
		}
		return true;
	}

	public bool setup(byte point_type, ushort point_size, ushort compressor = 2)
	{
		if (!check_compressor(compressor))
		{
			return false;
		}
		num_items = 0;
		items = null;
		if (!setup(out num_items, out items, point_type, point_size, compressor))
		{
			return false;
		}
		if (compressor != 0)
		{
			if (items[0].type == LASitem.Type.POINT14)
			{
				if (compressor != 3)
				{
					return false;
				}
				this.compressor = 3;
			}
			else if (compressor == 3)
			{
				this.compressor = 2;
			}
			else
			{
				this.compressor = compressor;
			}
			if (compressor != 1 && chunk_size == 0)
			{
				chunk_size = 50000u;
			}
		}
		else
		{
			this.compressor = 0;
		}
		return true;
	}

	public bool setup(ushort num_items, LASitem[] items, ushort compressor)
	{
		if (!check_compressor(compressor))
		{
			return false;
		}
		if (!check_items(num_items, items, 0))
		{
			return false;
		}
		if (compressor != 0)
		{
			if (items[0].type == LASitem.Type.POINT14)
			{
				if (compressor != 3)
				{
					return false;
				}
				this.compressor = 3;
			}
			else if (compressor == 3)
			{
				this.compressor = 2;
			}
			else
			{
				this.compressor = compressor;
			}
			if (compressor != 1 && chunk_size == 0)
			{
				chunk_size = 50000u;
			}
		}
		else
		{
			this.compressor = 0;
		}
		this.num_items = 0;
		this.items = null;
		this.num_items = num_items;
		this.items = new LASitem[num_items];
		for (int i = 0; i < num_items; i++)
		{
			this.items[i] = items[i];
		}
		return true;
	}

	public bool set_chunk_size(uint chunk_size)
	{
		if (num_items == 0)
		{
			return return_error("call setup() before setting chunk size");
		}
		if (compressor != 1)
		{
			this.chunk_size = chunk_size;
			return true;
		}
		return false;
	}

	public bool request_version(ushort requested_version)
	{
		if (num_items == 0)
		{
			return return_error("call setup() before requesting version");
		}
		if (compressor == 0)
		{
			if (requested_version > 0)
			{
				return return_error("without compression version is always 0");
			}
		}
		else
		{
			if (requested_version < 1)
			{
				return return_error("with compression version is at least 1");
			}
			if (requested_version > 2)
			{
				return return_error("version larger than 2 not supported");
			}
		}
		for (int i = 0; i < num_items; i++)
		{
			switch (items[i].type)
			{
			case LASitem.Type.BYTE:
			case LASitem.Type.POINT10:
			case LASitem.Type.GPSTIME11:
			case LASitem.Type.RGB12:
				items[i].version = requested_version;
				break;
			case LASitem.Type.WAVEPACKET13:
				items[i].version = 1;
				break;
			case LASitem.Type.POINT14:
			case LASitem.Type.RGB14:
			case LASitem.Type.RGBNIR14:
			case LASitem.Type.WAVEPACKET14:
			case LASitem.Type.BYTE14:
				items[i].version = 4;
				break;
			default:
				return return_error("item type not supported");
			}
		}
		return true;
	}

	public string get_error()
	{
		return error_string;
	}

	public LASzip()
	{
		compressor = 2;
		coder = 0;
		version_major = 3;
		version_minor = 2;
		version_revision = 9;
		options = 0u;
		num_items = 0;
		chunk_size = 50000u;
		number_of_special_evlrs = -1L;
		offset_to_special_evlrs = -1L;
		error_string = null;
		items = null;
		bytes = null;
	}

	private bool return_error(string error)
	{
		error_string = $"{error} (LASzip v{3}.{2}r{9})";
		return false;
	}
}
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
[StructLayout(LayoutKind.Sequential, Pack = 1)]
internal struct LASpoint10
{
	public int X;

	public int Y;

	public int Z;

	public ushort intensity;

	public byte flags;

	public byte classification_and_classification_flags;

	public sbyte scan_angle_rank;

	public byte user_data;

	public ushort point_source_ID;
}
[StructLayout(LayoutKind.Sequential, Pack = 1)]
internal struct LASwavepacket13
{
	public ulong offset;

	public uint packet_size;

	public U32I32F32 return_point;

	public U32I32F32 x;

	public U32I32F32 y;

	public U32I32F32 z;

	public static LASwavepacket13 unpack(byte[] item, int offset = 0)
	{
		return new LASwavepacket13
		{
			offset = makeU64(item, offset),
			packet_size = makeU32(item, offset + 8),
			return_point = 
			{
				u32 = makeU32(item, offset + 12)
			},
			x = 
			{
				u32 = makeU32(item, offset + 16)
			},
			y = 
			{
				u32 = makeU32(item, offset + 20)
			},
			z = 
			{
				u32 = makeU32(item, offset + 24)
			}
		};
	}

	public void pack(byte[] item, int item_offset = 0)
	{
		packU32((uint)(offset & 0xFFFFFFFFu), item, item_offset);
		packU32((uint)(offset >> 32), item, item_offset + 4);
		packU32(packet_size, item, item_offset + 8);
		packU32(return_point.u32, item, item_offset + 12);
		packU32(x.u32, item, item_offset + 16);
		packU32(y.u32, item, item_offset + 20);
		packU32(z.u32, item, item_offset + 24);
	}

	private static ulong makeU64(byte[] item, int offset = 0)
	{
		long num = makeU32(item, offset);
		ulong num2 = makeU32(item, offset + 4);
		return (ulong)num | (num2 << 32);
	}

	private static uint makeU32(byte[] item, int offset = 0)
	{
		byte num = item[offset];
		uint num2 = item[offset + 1];
		uint num3 = item[offset + 2];
		uint num4 = item[offset + 3];
		return num | (num2 << 8) | (num3 << 16) | (num4 << 24);
	}

	private static void packU32(uint v, byte[] item, int offset = 0)
	{
		item[offset] = (byte)(v & 0xFF);
		item[offset + 1] = (byte)((v >> 8) & 0xFF);
		item[offset + 2] = (byte)((v >> 16) & 0xFF);
		item[offset + 3] = (byte)((v >> 24) & 0xFF);
	}
}
[StructLayout(LayoutKind.Sequential, Pack = 1)]
internal struct LASpoint14
{
	public int X;

	public int Y;

	public int Z;

	public ushort intensity;

	public byte returns;

	public byte flags;

	public byte classification;

	public byte user_data;

	public short scan_angle;

	public ushort point_source_ID;

	public double gps_time;

	public byte return_number
	{
		get
		{
			return (byte)(returns & 0xF);
		}
		set
		{
			returns = (byte)((returns & 0xF0) | (value & 0xF));
		}
	}

	public byte number_of_returns
	{
		get
		{
			return (byte)((returns >> 4) & 0xF);
		}
		set
		{
			returns = (byte)((returns & 0xF) | ((value & 0xF) << 4));
		}
	}

	public byte classification_flags
	{
		get
		{
			return (byte)(flags & 0xF);
		}
		set
		{
			flags = (byte)((flags & 0xF0) | (value & 0xF));
		}
	}

	public byte scanner_channel
	{
		get
		{
			return (byte)((flags >> 4) & 3);
		}
		set
		{
			flags = (byte)((flags & 0xCF) | ((value & 3) << 4));
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
}
internal class Laszip_Common_v2
{
	internal static readonly byte[,] number_return_map = new byte[8, 8]
	{
		{ 15, 14, 13, 12, 11, 10, 9, 8 },
		{ 14, 0, 1, 3, 6, 10, 10, 9 },
		{ 13, 1, 2, 4, 7, 11, 11, 10 },
		{ 12, 3, 4, 5, 8, 12, 12, 11 },
		{ 11, 6, 7, 8, 9, 13, 13, 12 },
		{ 10, 10, 11, 12, 13, 14, 14, 13 },
		{ 9, 10, 11, 12, 13, 14, 15, 14 },
		{ 8, 9, 10, 11, 12, 13, 14, 15 }
	};

	internal static readonly byte[,] number_return_level = new byte[8, 8]
	{
		{ 0, 1, 2, 3, 4, 5, 6, 7 },
		{ 1, 0, 1, 2, 3, 4, 5, 6 },
		{ 2, 1, 0, 1, 2, 3, 4, 5 },
		{ 3, 2, 1, 0, 1, 2, 3, 4 },
		{ 4, 3, 2, 1, 0, 1, 2, 3 },
		{ 5, 4, 3, 2, 1, 0, 1, 2 },
		{ 6, 5, 4, 3, 2, 1, 0, 1 },
		{ 7, 6, 5, 4, 3, 2, 1, 0 }
	};
}
internal class LAScontextPOINT14
{
	public bool unused;

	public laszip_point last_item = new laszip_point();

	public bool last_item_gps_time_change;

	public readonly ushort[] last_intensity = new ushort[8];

	public readonly StreamingMedian5[] last_X_diff_median5 = new StreamingMedian5[12];

	public readonly StreamingMedian5[] last_Y_diff_median5 = new StreamingMedian5[12];

	public readonly int[] last_Z = new int[8];

	public readonly ArithmeticModel[] m_changed_values = new ArithmeticModel[8];

	public ArithmeticModel m_scanner_channel;

	public readonly ArithmeticModel[] m_number_of_returns = new ArithmeticModel[16];

	public ArithmeticModel m_return_number_gps_same;

	public readonly ArithmeticModel[] m_return_number = new ArithmeticModel[16];

	public IntegerCompressor ic_dX;

	public IntegerCompressor ic_dY;

	public IntegerCompressor ic_Z;

	public readonly ArithmeticModel[] m_classification = new ArithmeticModel[64];

	public readonly ArithmeticModel[] m_flags = new ArithmeticModel[64];

	public readonly ArithmeticModel[] m_user_data = new ArithmeticModel[64];

	public IntegerCompressor ic_intensity;

	public IntegerCompressor ic_scan_angle;

	public IntegerCompressor ic_point_source_ID;

	public uint last;

	public uint next;

	public readonly U64I64F64[] last_gpstime = new U64I64F64[4];

	public readonly int[] last_gpstime_diff = new int[4];

	public readonly int[] multi_extreme_counter = new int[4];

	public ArithmeticModel m_gpstime_multi;

	public ArithmeticModel m_gpstime_0diff;

	public IntegerCompressor ic_gpstime;
}
internal class LAScontextRGB14
{
	public bool unused;

	public readonly ushort[] last_item = new ushort[3];

	public ArithmeticModel m_byte_used;

	public ArithmeticModel m_rgb_diff_0;

	public ArithmeticModel m_rgb_diff_1;

	public ArithmeticModel m_rgb_diff_2;

	public ArithmeticModel m_rgb_diff_3;

	public ArithmeticModel m_rgb_diff_4;

	public ArithmeticModel m_rgb_diff_5;
}
internal class LAScontextRGBNIR14
{
	public bool unused;

	public readonly ushort[] last_item = new ushort[4];

	public ArithmeticModel m_rgb_bytes_used;

	public ArithmeticModel m_rgb_diff_0;

	public ArithmeticModel m_rgb_diff_1;

	public ArithmeticModel m_rgb_diff_2;

	public ArithmeticModel m_rgb_diff_3;

	public ArithmeticModel m_rgb_diff_4;

	public ArithmeticModel m_rgb_diff_5;

	public ArithmeticModel m_nir_bytes_used;

	public ArithmeticModel m_nir_diff_0;

	public ArithmeticModel m_nir_diff_1;
}
internal class LAScontextWAVEPACKET14
{
	public bool unused;

	public readonly byte[] last_item = new byte[29];

	public int last_diff_32;

	public uint sym_last_offset_diff;

	public ArithmeticModel m_packet_index;

	public readonly ArithmeticModel[] m_offset_diff = new ArithmeticModel[4];

	public IntegerCompressor ic_offset_diff;

	public IntegerCompressor ic_packet_size;

	public IntegerCompressor ic_return_point;

	public IntegerCompressor ic_xyz;
}
internal class LAScontextBYTE14
{
	public bool unused;

	public byte[] last_item;

	public ArithmeticModel[] m_bytes;
}
internal class Laszip_Common_v3
{
	internal static readonly byte[,] number_return_map_6ctx = new byte[16, 16]
	{
		{
			0, 1, 2, 3, 4, 5, 3, 4, 4, 5,
			5, 5, 5, 5, 5, 5
		},
		{
			1, 0, 1, 3, 3, 3, 3, 3, 3, 3,
			3, 3, 3, 3, 3, 3
		},
		{
			2, 1, 2, 4, 4, 4, 4, 4, 4, 4,
			4, 3, 3, 3, 3, 3
		},
		{
			3, 3, 4, 5, 4, 4, 4, 4, 4, 4,
			4, 4, 4, 4, 4, 4
		},
		{
			4, 3, 4, 4, 5, 4, 4, 4, 4, 4,
			4, 4, 4, 4, 4, 4
		},
		{
			5, 3, 4, 4, 4, 5, 4, 4, 4, 4,
			4, 4, 4, 4, 4, 4
		},
		{
			3, 3, 4, 4, 4, 4, 5, 4, 4, 4,
			4, 4, 4, 4, 4, 4
		},
		{
			4, 3, 4, 4, 4, 4, 4, 5, 4, 4,
			4, 4, 4, 4, 4, 4
		},
		{
			4, 3, 4, 4, 4, 4, 4, 4, 5, 4,
			4, 4, 4, 4, 4, 4
		},
		{
			5, 3, 4, 4, 4, 4, 4, 4, 4, 5,
			4, 4, 4, 4, 4, 4
		},
		{
			5, 3, 4, 4, 4, 4, 4, 4, 4, 4,
			5, 4, 4, 4, 4, 4
		},
		{
			5, 3, 3, 4, 4, 4, 4, 4, 4, 4,
			4, 5, 5, 4, 4, 4
		},
		{
			5, 3, 3, 4, 4, 4, 4, 4, 4, 4,
			4, 5, 5, 5, 4, 4
		},
		{
			5, 3, 3, 4, 4, 4, 4, 4, 4, 4,
			4, 4, 5, 5, 5, 4
		},
		{
			5, 3, 3, 4, 4, 4, 4, 4, 4, 4,
			4, 4, 4, 5, 5, 5
		},
		{
			5, 3, 3, 4, 4, 4, 4, 4, 4, 4,
			4, 4, 4, 4, 5, 5
		}
	};

	internal static readonly byte[,] number_return_level_8ctx = new byte[16, 16]
	{
		{
			0, 1, 2, 3, 4, 5, 6, 7, 7, 7,
			7, 7, 7, 7, 7, 7
		},
		{
			1, 0, 1, 2, 3, 4, 5, 6, 7, 7,
			7, 7, 7, 7, 7, 7
		},
		{
			2, 1, 0, 1, 2, 3, 4, 5, 6, 7,
			7, 7, 7, 7, 7, 7
		},
		{
			3, 2, 1, 0, 1, 2, 3, 4, 5, 6,
			7, 7, 7, 7, 7, 7
		},
		{
			4, 3, 2, 1, 0, 1, 2, 3, 4, 5,
			6, 7, 7, 7, 7, 7
		},
		{
			5, 4, 3, 2, 1, 0, 1, 2, 3, 4,
			5, 6, 7, 7, 7, 7
		},
		{
			6, 5, 4, 3, 2, 1, 0, 1, 2, 3,
			4, 5, 6, 7, 7, 7
		},
		{
			7, 6, 5, 4, 3, 2, 1, 0, 1, 2,
			3, 4, 5, 6, 7, 7
		},
		{
			7, 7, 6, 5, 4, 3, 2, 1, 0, 1,
			2, 3, 4, 5, 6, 7
		},
		{
			7, 7, 7, 6, 5, 4, 3, 2, 1, 0,
			1, 2, 3, 4, 5, 6
		},
		{
			7, 7, 7, 7, 6, 5, 4, 3, 2, 1,
			0, 1, 2, 3, 4, 5
		},
		{
			7, 7, 7, 7, 7, 6, 5, 4, 3, 2,
			1, 0, 1, 2, 3, 4
		},
		{
			7, 7, 7, 7, 7, 7, 6, 5, 4, 3,
			2, 1, 0, 1, 2, 3
		},
		{
			7, 7, 7, 7, 7, 7, 7, 6, 5, 4,
			3, 2, 1, 0, 1, 2
		},
		{
			7, 7, 7, 7, 7, 7, 7, 7, 6, 5,
			4, 3, 2, 1, 0, 1
		},
		{
			7, 7, 7, 7, 7, 7, 7, 7, 7, 6,
			5, 4, 3, 2, 1, 0
		}
	};
}
[Flags]
public enum LASZIP_DECOMPRESS_SELECTIVE : uint
{
	CHANNEL_RETURNS_XY = 0u,
	Z = 1u,
	CLASSIFICATION = 2u,
	FLAGS = 4u,
	INTENSITY = 8u,
	SCAN_ANGLE = 0x10u,
	USER_DATA = 0x20u,
	POINT_SOURCE = 0x40u,
	GPS_TIME = 0x80u,
	RGB = 0x100u,
	NIR = 0x200u,
	WAVEPACKET = 0x400u,
	BYTE0 = 0x10000u,
	BYTE1 = 0x20000u,
	BYTE2 = 0x40000u,
	BYTE3 = 0x80000u,
	BYTE4 = 0x100000u,
	BYTE5 = 0x200000u,
	BYTE6 = 0x400000u,
	BYTE7 = 0x800000u,
	EXTRA_BYTES = 0xFFFF0000u,
	ALL = 0xFFFF07FFu
}
public class laszip_evlr
{
	public ushort reserved;

	public readonly byte[] user_id = new byte[16];

	public ushort record_id;

	public ulong record_length_after_header;

	public readonly byte[] description = new byte[32];

	public byte[] data;
}
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct laszip_geokey
{
	public ushort key_id;

	public ushort tiff_tag_location;

	public ushort count;

	public ushort value_offset;
}
public class laszip_header
{
	public ushort file_source_ID;

	public ushort global_encoding;

	public uint project_ID_GUID_data_1;

	public ushort project_ID_GUID_data_2;

	public ushort project_ID_GUID_data_3;

	public readonly byte[] project_ID_GUID_data_4 = new byte[8];

	public byte version_major;

	public byte version_minor;

	public readonly byte[] system_identifier = new byte[32];

	public readonly byte[] generating_software = new byte[32];

	public ushort file_creation_day;

	public ushort file_creation_year;

	public ushort header_size;

	public uint offset_to_point_data;

	public uint number_of_variable_length_records;

	public byte point_data_format;

	public ushort point_data_record_length;

	public uint number_of_point_records;

	public readonly uint[] number_of_points_by_return = new uint[5];

	public double x_scale_factor;

	public double y_scale_factor;

	public double z_scale_factor;

	public double x_offset;

	public double y_offset;

	public double z_offset;

	public double max_x;

	public double min_x;

	public double max_y;

	public double min_y;

	public double max_z;

	public double min_z;

	public ulong start_of_waveform_data_packet_record;

	public ulong start_of_first_extended_variable_length_record;

	public uint number_of_extended_variable_length_records;

	public ulong extended_number_of_point_records;

	public readonly ulong[] extended_number_of_points_by_return = new ulong[15];

	public uint user_data_in_header_size;

	public byte[] user_data_in_header;

	public List<laszip_vlr> vlrs = new List<laszip_vlr>();

	public uint user_data_after_header_size;

	public byte[] user_data_after_header;

	public laszip_header()
	{
		setDefault();
	}

	public void setDefault()
	{
		byte[] bytes = Encoding.ASCII.GetBytes($"LASzip.net DLL {3}.{2} r{9} ({181227})");
		Array.Copy(bytes, generating_software, Math.Min(bytes.Length, 32));
		version_major = 1;
		version_minor = 2;
		header_size = 227;
		offset_to_point_data = 227u;
		point_data_format = 1;
		point_data_record_length = 28;
		x_scale_factor = 0.01;
		y_scale_factor = 0.01;
		z_scale_factor = 0.01;
	}
}
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
public class laszip_vlr
{
	public ushort reserved;

	public readonly byte[] user_id = new byte[16];

	public ushort record_id;

	public ushort record_length_after_header;

	public readonly byte[] description = new byte[32];

	public byte[] data;
}
internal class MyDefs
{
	private const int U8_MAX_PLUS_ONE = 256;

	private const int U16_MAX_PLUS_ONE = 65536;

	private const long U32_MAX_PLUS_ONE = 4294967296L;

	public static int U8_FOLD(int n)
	{
		if (n >= 0)
		{
			if (n <= 255)
			{
				return n;
			}
			return n - 256;
		}
		return n + 256;
	}

	public static sbyte I8_CLAMP(int n)
	{
		if (n > -128)
		{
			if (n < 127)
			{
				return (sbyte)n;
			}
			return sbyte.MaxValue;
		}
		return sbyte.MinValue;
	}

	public static byte U8_CLAMP(int n)
	{
		if (n > 0)
		{
			if (n < 255)
			{
				return (byte)n;
			}
			return byte.MaxValue;
		}
		return 0;
	}

	public static short I16_CLAMP(int n)
	{
		if (n > -32768)
		{
			if (n < 32767)
			{
				return (short)n;
			}
			return short.MaxValue;
		}
		return short.MinValue;
	}

	public static ushort U16_CLAMP(int n)
	{
		if (n > 0)
		{
			if (n < 65535)
			{
				return (ushort)n;
			}
			return ushort.MaxValue;
		}
		return 0;
	}

	public static short I16_QUANTIZE(double n)
	{
		return (short)((n >= 0.0) ? (n + 0.5) : (n - 0.5));
	}

	public static int I32_QUANTIZE(double n)
	{
		return (int)((n >= 0.0) ? (n + 0.5) : (n - 0.5));
	}

	public static uint U32_QUANTIZE(double n)
	{
		return (uint)((n >= 0.0) ? (n + 0.5) : 0.0);
	}

	public static short I16_FLOOR(double n)
	{
		if (!((double)(short)n > n))
		{
			return (short)n;
		}
		return (short)((short)n - 1);
	}

	public static int I32_FLOOR(double n)
	{
		if (!((double)(int)n > n))
		{
			return (int)n;
		}
		return (int)n - 1;
	}

	public static long I64_FLOOR(double n)
	{
		if (!((double)(long)n > n))
		{
			return (long)n;
		}
		return (long)n - 1;
	}
}
internal struct StreamingMedian5
{
	public int values0;

	public int values1;

	public int values2;

	public int values3;

	public int values4;

	public bool low;

	public void init()
	{
		values0 = (values1 = (values2 = (values3 = (values4 = 0))));
		low = false;
	}

	public void add(int v)
	{
		if (!low)
		{
			if (v < values2)
			{
				values4 = values3;
				values3 = values2;
				if (v < values0)
				{
					values2 = values1;
					values1 = values0;
					values0 = v;
				}
				else if (v < values1)
				{
					values2 = values1;
					values1 = v;
				}
				else
				{
					values2 = v;
				}
			}
			else
			{
				if (v < values3)
				{
					values4 = values3;
					values3 = v;
				}
				else
				{
					values4 = v;
				}
				low = true;
			}
		}
		else if (values2 < v)
		{
			values0 = values1;
			values1 = values2;
			if (values4 < v)
			{
				values2 = values3;
				values3 = values4;
				values4 = v;
			}
			else if (values3 < v)
			{
				values2 = values3;
				values3 = v;
			}
			else
			{
				values2 = v;
			}
		}
		else
		{
			if (values1 < v)
			{
				values0 = values1;
				values1 = v;
			}
			else
			{
				values0 = v;
			}
			low = false;
		}
	}

	public int get()
	{
		return values2;
	}
}
[StructLayout(LayoutKind.Explicit, Pack = 1)]
internal struct U32I32F32
{
	[FieldOffset(0)]
	public uint u32;

	[FieldOffset(0)]
	public int i32;

	[FieldOffset(0)]
	public float f32;
}
[StructLayout(LayoutKind.Explicit, Pack = 1)]
public struct U64I64F64
{
	[FieldOffset(0)]
	public ulong u64;

	[FieldOffset(0)]
	public long i64;

	[FieldOffset(0)]
	public double f64;
}
