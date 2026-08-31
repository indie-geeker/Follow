using System.Buffers.Binary;
using System.IO.Compression;

namespace Follow.Core.Models;

/// <summary>
/// Bounded binary representation for raw Chromaprint frames stored in PostgreSQL bytea.
/// The frame count is stored separately so corrupt or mismatched payloads fail closed.
/// </summary>
public static class AudioFingerprintPayloadCodec
{
    public const int MaximumFrameCount = 16_384;
    public const int MaximumPayloadBytes = 256 * 1024;

    public static byte[] Encode(IReadOnlyList<uint> frames)
    {
        ArgumentNullException.ThrowIfNull(frames);
        if (frames.Count > MaximumFrameCount)
            throw new ArgumentOutOfRangeException(nameof(frames));

        using var output = new MemoryStream();
        using (var compressed = new BrotliStream(output, CompressionLevel.SmallestSize, leaveOpen: true))
        {
            Span<byte> buffer = stackalloc byte[sizeof(uint)];
            foreach (var frame in frames)
            {
                BinaryPrimitives.WriteUInt32LittleEndian(buffer, frame);
                compressed.Write(buffer);
            }
        }

        if (output.Length > MaximumPayloadBytes)
            throw new InvalidDataException("Compressed fingerprint payload exceeds the configured bound.");
        return output.ToArray();
    }

    public static uint[] Decode(byte[] payload, int frameCount)
    {
        ArgumentNullException.ThrowIfNull(payload);
        if (frameCount < 0 || frameCount > MaximumFrameCount)
            throw new ArgumentOutOfRangeException(nameof(frameCount));
        if (payload.Length > MaximumPayloadBytes)
            throw new InvalidDataException("Compressed fingerprint payload exceeds the configured bound.");

        var rawLength = checked(frameCount * sizeof(uint));
        var raw = new byte[rawLength];
        try
        {
            using var input = new MemoryStream(payload, writable: false);
            using var compressed = new BrotliStream(input, CompressionMode.Decompress);
            compressed.ReadExactly(raw);
            if (compressed.ReadByte() != -1)
                throw new InvalidDataException("Fingerprint payload contains more frames than declared.");
        }
        catch (EndOfStreamException exception)
        {
            throw new InvalidDataException("Fingerprint payload contains fewer frames than declared.", exception);
        }

        var frames = new uint[frameCount];
        for (var index = 0; index < frames.Length; index++)
        {
            frames[index] = BinaryPrimitives.ReadUInt32LittleEndian(
                raw.AsSpan(index * sizeof(uint), sizeof(uint)));
        }
        return frames;
    }
}
