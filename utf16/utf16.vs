// Package utf16 encodes and decodes UTF-16, the encoding of JavaScript,
// Java, Windows and JSON's \u escapes.
//
// UTF-16 in the wild may hold unpaired surrogates. CodePoints keeps them
// (a lone surrogate is its own code point); Decode, whose result is a
// UTF-8 string that can't carry one, writes U+FFFD in its place.
package utf16

/// IsHighSurrogate: U+D800...U+DBFF, the first unit of a pair.
public func IsHighSurrogate(_ u: uint16) -> bool { return u >= 0xD800 && u <= 0xDBFF }

/// IsLowSurrogate: U+DC00...U+DFFF, the second unit of a pair.
public func IsLowSurrogate(_ u: uint16) -> bool { return u >= 0xDC00 && u <= 0xDFFF }

/// Combine joins a surrogate pair into its code point; units that aren't
/// a pair give U+FFFD.
public func Combine(_ high: uint16, _ low: uint16) -> uint32 {
    if IsHighSurrogate(high) && IsLowSurrogate(low) {
        return 0x10000 + ((uint32(high) - 0xD800) << 10) + (uint32(low) - 0xDC00)
    }
    return 0xFFFD
}

/// Surrogates splits a code point above U+FFFF into its pair.
public func Surrogates(_ cp: uint32) -> (high: uint16, low: uint16) {
    let v = cp - 0x10000
    return (uint16(0xD800 + (v >> 10)), uint16(0xDC00 + (v & 0x3FF)))
}

/// Width is how many units a code point takes: 1, or 2 above U+FFFF.
public func Width(_ cp: uint32) -> int {
    return cp > 0xFFFF && cp <= 0x10FFFF ? 2 : 1
}

/// Append appends a code point's units. A surrogate code point is
/// appended as itself; one past U+10FFFF as U+FFFD.
public func Append(_ out: inout [uint16], _ cp: uint32) {
    if cp < 0x10000 {
        out.append(uint16(cp))
    } else if cp <= 0x10FFFF {
        let (h, l) = Surrogates(cp)
        out.append(h)
        out.append(l)
    } else {
        out.append(0xFFFD)
    }
}

/// FromCodePoints is the encoding of a sequence of code points.
public func FromCodePoints(_ cps: [uint32]) -> [uint16] {
    var out: [uint16] = []
    out.reserveCapacity(cps.count)
    for cp in cps { Append(&out, cp) }
    return out
}

/// DecodeAt reads the code point at u[i]: a pair is joined, anything else
/// (a lone surrogate too) is its own unit.
public func DecodeAt(_ u: [uint16], _ i: int) -> (codePoint: uint32, width: int) {
    let c = u[i]
    if IsHighSurrogate(c) && i + 1 < u.count && IsLowSurrogate(u[i + 1]) {
        return (Combine(c, u[i + 1]), 2)
    }
    return (uint32(c), 1)
}

/// CodePoints reads all of u's code points, keeping lone surrogates.
public func CodePoints(_ u: [uint16]) -> [uint32] {
    var out: [uint32] = []
    out.reserveCapacity(u.count)
    var i = 0
    while i < u.count {
        let (cp, w) = DecodeAt(u, i)
        out.append(cp)
        i += w
    }
    return out
}

/// Encode is a string's UTF-16 encoding.
public func Encode(_ s: string) -> [uint16] {
    var out: [uint16] = []
    var ascii = true
    for b in s.utf8 {
        if b >= 0x80 { ascii = false; break }
        out.append(uint16(b))
    }
    if ascii { return out }
    out = []
    for sc in s.unicodeScalars { Append(&out, sc.value) }
    return out
}

/// Decode is the string u spells; a lone surrogate becomes U+FFFD.
public func Decode(_ u: [uint16]) -> string {
    return DecodeRange(u, 0, u.count)
}

/// DecodeRange decodes u[from..<to].
public func DecodeRange(_ u: [uint16], _ from: int, _ to: int) -> string {
    return string(decoding: UTF8Bytes(u, from, to), as: UTF8.self)
}

/// UTF8Bytes is the UTF-8 encoding of u[from..<to], for writing text out
/// without making a string; a lone surrogate becomes U+FFFD.
public func UTF8Bytes(_ u: [uint16], _ from: int = 0, _ to: int = -1) -> [uint8] {
    let end = to < 0 ? u.count : to
    var b: [uint8] = []
    b.reserveCapacity(end - from)
    var i = from
    while i < end {
        var cp = uint32(u[i])
        if cp < 0x80 {
            b.append(uint8(cp))
            i += 1
            continue
        }
        if IsHighSurrogate(u[i]) && i + 1 < end && IsLowSurrogate(u[i + 1]) {
            cp = Combine(u[i], u[i + 1])
            i += 1
        } else if cp >= 0xD800 && cp <= 0xDFFF {
            cp = 0xFFFD
        }
        if cp < 0x800 {
            b.append(uint8(0xC0 | (cp >> 6)))
            b.append(uint8(0x80 | (cp & 0x3F)))
        } else if cp < 0x10000 {
            b.append(uint8(0xE0 | (cp >> 12)))
            b.append(uint8(0x80 | ((cp >> 6) & 0x3F)))
            b.append(uint8(0x80 | (cp & 0x3F)))
        } else {
            b.append(uint8(0xF0 | (cp >> 18)))
            b.append(uint8(0x80 | ((cp >> 12) & 0x3F)))
            b.append(uint8(0x80 | ((cp >> 6) & 0x3F)))
            b.append(uint8(0x80 | (cp & 0x3F)))
        }
        i += 1
    }
    return b
}
