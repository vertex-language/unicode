// Package utf8 encodes and decodes UTF-8 (RFC 3629), the encoding of
// Vertex's strings.
//
// Decoding is lossy: malformed input, a surrogate or an overlong form
// reads as U+FFFD, one byte wide, so a decoder always moves forward.
package utf8

/// Width is how many bytes a code point takes: 1 to 4. A surrogate or a
/// value past U+10FFFF takes 3, the width of U+FFFD, which is written
/// in its place.
public func Width(_ cp: uint32) -> int {
    if cp < 0x80 { return 1 }
    if cp < 0x800 { return 2 }
    if cp < 0x10000 || cp > 0x10FFFF { return 3 }
    return 4
}

/// Append appends a code point's encoding. A surrogate or a value past
/// U+10FFFF, which UTF-8 can't carry, appends U+FFFD.
public func Append(_ out: inout [uint8], _ cp: uint32) {
    var c = cp
    if (c >= 0xD800 && c <= 0xDFFF) || c > 0x10FFFF { c = 0xFFFD }
    if c < 0x80 {
        out.append(uint8(c))
    } else if c < 0x800 {
        out.append(uint8(0xC0 | (c >> 6)))
        out.append(uint8(0x80 | (c & 0x3F)))
    } else if c < 0x10000 {
        out.append(uint8(0xE0 | (c >> 12)))
        out.append(uint8(0x80 | ((c >> 6) & 0x3F)))
        out.append(uint8(0x80 | (c & 0x3F)))
    } else {
        out.append(uint8(0xF0 | (c >> 18)))
        out.append(uint8(0x80 | ((c >> 12) & 0x3F)))
        out.append(uint8(0x80 | ((c >> 6) & 0x3F)))
        out.append(uint8(0x80 | (c & 0x3F)))
    }
}

/// Encode is the encoding of a sequence of code points.
public func Encode(_ cps: [uint32]) -> [uint8] {
    var out: [uint8] = []
    out.reserveCapacity(cps.count)
    for cp in cps { Append(&out, cp) }
    return out
}

/// FromCodePoints is a string of code points.
public func FromCodePoints(_ cps: [uint32]) -> string {
    return string(decoding: Encode(cps), as: UTF8.self)
}

/// DecodeAt reads the code point whose encoding starts at b[i], and how
/// many bytes it took.
public func DecodeAt(_ b: [uint8], _ i: int) -> (codePoint: uint32, width: int) {
    let n = b.count
    let c0 = uint32(b[i])
    if c0 < 0x80 { return (c0, 1) }
    if c0 < 0xC2 || c0 > 0xF4 { return (0xFFFD, 1) }
    if c0 < 0xE0 {
        if i + 1 >= n || !isContinuation(b[i + 1]) { return (0xFFFD, 1) }
        return (((c0 & 0x1F) << 6) | (uint32(b[i + 1]) & 0x3F), 2)
    }
    if c0 < 0xF0 {
        if i + 2 >= n || !isContinuation(b[i + 1]) || !isContinuation(b[i + 2]) { return (0xFFFD, 1) }
        let cp = ((c0 & 0x0F) << 12) | ((uint32(b[i + 1]) & 0x3F) << 6) | (uint32(b[i + 2]) & 0x3F)
        if cp < 0x800 || (cp >= 0xD800 && cp <= 0xDFFF) { return (0xFFFD, 1) }
        return (cp, 3)
    }
    if i + 3 >= n || !isContinuation(b[i + 1]) || !isContinuation(b[i + 2]) || !isContinuation(b[i + 3]) { return (0xFFFD, 1) }
    let cp = ((c0 & 0x07) << 18) | ((uint32(b[i + 1]) & 0x3F) << 12) | ((uint32(b[i + 2]) & 0x3F) << 6) | (uint32(b[i + 3]) & 0x3F)
    if cp < 0x10000 || cp > 0x10FFFF { return (0xFFFD, 1) }
    return (cp, 4)
}

func isContinuation(_ b: uint8) -> bool {
    return b & 0xC0 == 0x80
}

/// CodePoints are a string's code points.
public func CodePoints(_ s: string) -> [uint32] {
    var out: [uint32] = []
    for sc in s.unicodeScalars { out.append(sc.value) }
    return out
}

/// DecodeCodePoints reads all of b's code points.
public func DecodeCodePoints(_ b: [uint8]) -> [uint32] {
    var out: [uint32] = []
    out.reserveCapacity(b.count)
    var i = 0
    while i < b.count {
        let (cp, w) = DecodeAt(b, i)
        out.append(cp)
        i += w
    }
    return out
}

/// IsValid says whether b[from..<to] is well-formed UTF-8.
public func IsValid(_ b: [uint8], _ from: int = 0, _ to: int = -1) -> bool {
    let end = to < 0 ? b.count : to
    var i = from
    while i < end {
        if b[i] < 0x80 {
            i += 1
            continue
        }
        let (cp, w) = DecodeAt(b, i)
        if cp == 0xFFFD && w == 1 { return false }
        if i + w > end { return false }
        i += w
    }
    return true
}

/// Decode is the string b[from..<to] spells, made without first copying
/// the span into an array of its own. Malformed input decodes lossily.
public func Decode(_ b: [uint8], _ from: int = 0, _ to: int = -1) -> string {
    let end = to < 0 ? b.count : to
    if from >= end { return "" }
    if !IsValid(b, from, end) {
        var out: [uint8] = []
        var i = from
        while i < end {
            let (cp, w) = DecodeAt(b, i)
            Append(&out, cp)
            i += w
        }
        return string(decoding: out, as: UTF8.self)
    }
    return b.withUnsafeBytes { bp in
        stringFromUTF8(bp.baseAddress! + from, int64(end - from))
    }
}

// The runtime makes a string from a span of valid UTF-8 (stdlib ABI).
// vsc_TODO: String(decoding: b[from..<to], as: UTF8.self) should do this.
@_silgen_name("vertex_string_from_utf8")
func stringFromUTF8(_ ptr: UnsafeRawPointer, _ count: int64) -> string
