import Foundation
import Compression

/// Tiny gzip writer using Apple's `Compression` framework for the deflate
/// payload, with a hand-rolled gzip header + CRC32 + ISIZE trailer.
///
/// Output is a single-member RFC 1952 gzip stream — readable by
/// `/usr/bin/gunzip` and standard library tools without modification.
/// We keep this in SceneCore (no external dependencies) so unit tests
/// can verify round-trip in pure Swift.
public enum GzipWriter {
    public enum Error: Swift.Error {
        case deflateFailed
    }

    public static func compress(_ data: Data) throws -> Data {
        var out = Data()
        out.append(contentsOf: gzipHeader)
        let deflated = try rawDeflate(data)
        out.append(deflated)
        let crc = crc32(data)
        out.append(uint32LE(crc))
        out.append(uint32LE(UInt32(truncatingIfNeeded: data.count)))
        return out
    }

    private static let gzipHeader: [UInt8] = [
        0x1F, 0x8B,             // gzip magic
        0x08,                   // compression method = DEFLATE
        0x00,                   // flags = none
        0x00, 0x00, 0x00, 0x00, // mtime = 0 (unknown — we don't leak file metadata)
        0x00,                   // XFL
        0xFF                    // OS = unknown
    ]

    private static func rawDeflate(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }
        // Allocate a destination buffer with headroom — small inputs can
        // expand slightly under deflate.
        let dstSize = max(64, data.count + (data.count / 16) + 64)
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
        defer { dst.deallocate() }
        let written = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_encode_buffer(
                dst, dstSize, base, data.count, nil, COMPRESSION_ZLIB
            )
        }
        guard written > 0 else { throw Error.deflateFailed }
        return Data(bytes: dst, count: written)
    }

    private static func uint32LE(_ value: UInt32) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: 4)
    }

    // MARK: - CRC32

    private static let crc32Table: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for n in 0..<256 {
            var c = UInt32(n)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            table[n] = c
        }
        return table
    }()

    public static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for byte in data {
            c = crc32Table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return c ^ 0xFFFFFFFF
    }
}
