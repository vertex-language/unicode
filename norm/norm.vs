// Package norm is Unicode normalization (UAX #15): the canonical and
// compatibility decompositions and compositions, NFD, NFC, NFKD and NFKC.
package norm

import "unicode/utf8"

/// Form is a normalization form.
public enum Form {
    /// Canonical decomposition.
    case nfd
    /// Canonical decomposition, then canonical composition.
    case nfc
    /// Compatibility decomposition.
    case nfkd
    /// Compatibility decomposition, then canonical composition.
    case nfkc
}

// Hangul syllables decompose and compose by arithmetic (§3.12).
let sBase: uint32 = 0xAC00
let lBase: uint32 = 0x1100
let vBase: uint32 = 0x1161
let tBase: uint32 = 0x11A7
let lCount: uint32 = 19
let vCount: uint32 = 21
let tCount: uint32 = 28
let nCount: uint32 = vCount * tCount
let sCount: uint32 = lCount * nCount

func search(_ keys: [uint32], _ cp: uint32) -> int {
    var lo = 0
    var hi = keys.count
    while lo < hi {
        let mid = (lo + hi) / 2
        if keys[mid] < cp { lo = mid + 1 } else { hi = mid }
    }
    return lo < keys.count && keys[lo] == cp ? lo : -1
}

/// CombiningClass is a code point's Canonical_Combining_Class.
public func CombiningClass(_ cp: uint32) -> uint8 {
    let i = search(cccFrom, cp)
    return i < 0 ? 0 : uint8(cccTo[i])
}

func appendDecomposed(_ cp: uint32, compat: bool, _ out: inout [uint32]) {
    if cp >= sBase && cp < sBase + sCount {
        let s = cp - sBase
        out.append(lBase + s / nCount)
        out.append(vBase + (s % nCount) / tCount)
        let t = s % tCount
        if t != 0 { out.append(tBase + t) }
        return
    }
    var i = search(canonicalKeys, cp)
    if i >= 0 {
        var k = int(canonicalOffsets[i])
        while k < int(canonicalOffsets[i + 1]) {
            appendDecomposed(canonicalData[k], compat: compat, &out)
            k += 1
        }
        return
    }
    if compat {
        i = search(compatibilityKeys, cp)
        if i >= 0 {
            var k = int(compatibilityOffsets[i])
            while k < int(compatibilityOffsets[i + 1]) {
                appendDecomposed(compatibilityData[k], compat: true, &out)
                k += 1
            }
            return
        }
    }
    out.append(cp)
}

/// Decompose is the full canonical (or compatibility) decomposition, in
/// canonical order.
public func Decompose(_ cps: [uint32], compat: bool) -> [uint32] {
    var out: [uint32] = []
    out.reserveCapacity(cps.count)
    for cp in cps { appendDecomposed(cp, compat: compat, &out) }
    reorder(&out)
    return out
}

/// reorder puts each run of non-starters in combining class order, stably.
func reorder(_ cps: inout [uint32]) {
    var i = 0
    while i < cps.count {
        if CombiningClass(cps[i]) == 0 {
            i += 1
            continue
        }
        var j = i
        while j < cps.count && CombiningClass(cps[j]) != 0 { j += 1 }
        if j - i > 1 {
            // Insertion sort: runs are short.
            var a = i + 1
            while a < j {
                let x = cps[a]
                let cx = CombiningClass(x)
                var b = a
                while b > i && CombiningClass(cps[b - 1]) > cx {
                    cps[b] = cps[b - 1]
                    b -= 1
                }
                cps[b] = x
                a += 1
            }
        }
        i = j
    }
}

/// primaryComposite is the composite of a starter and a following code
/// point, or nil.
func primaryComposite(_ a: uint32, _ b: uint32) -> uint32? {
    if a >= lBase && a < lBase + lCount && b >= vBase && b < vBase + vCount {
        return sBase + ((a - lBase) * vCount + (b - vBase)) * tCount
    }
    if a >= sBase && a < sBase + sCount && (a - sBase) % tCount == 0 && b > tBase && b < tBase + tCount {
        return a + (b - tBase)
    }
    let key = (uint64(a) << 21) | uint64(b)
    var lo = 0
    var hi = composePairs.count
    while lo < hi {
        let mid = (lo + hi) / 2
        if composePairs[mid] < key { lo = mid + 1 } else { hi = mid }
    }
    if lo < composePairs.count && composePairs[lo] == key { return composeResult[lo] }
    return nil
}

/// Compose is the canonical composition of a decomposed sequence.
public func Compose(_ cps: [uint32]) -> [uint32] {
    var out = cps
    if out.isEmpty { return out }
    var starter = -1
    var lastClass: int = -1
    var write = 0
    var read = 0
    while read < out.count {
        let cp = out[read]
        let cc = int(CombiningClass(cp))
        if starter >= 0 && (lastClass < cc || (lastClass == 0 && write == starter + 1)) {
            if let comp = primaryComposite(out[starter], cp) {
                out[starter] = comp
                read += 1
                continue
            }
        }
        if cc == 0 {
            starter = write
            lastClass = 0
        } else {
            lastClass = cc
        }
        out[write] = cp
        write += 1
        read += 1
    }
    while out.count > write { out.removeLast() }
    return out
}

/// Normalize puts code points in a normalization form.
public func Normalize(_ cps: [uint32], _ form: Form) -> [uint32] {
    switch form {
    case .nfd: return Decompose(cps, compat: false)
    case .nfkd: return Decompose(cps, compat: true)
    case .nfc: return Compose(Decompose(cps, compat: false))
    case .nfkc: return Compose(Decompose(cps, compat: true))
    }
}

/// NormalizeString is Normalize over a string's code points.
public func NormalizeString(_ s: string, _ form: Form) -> string {
    return utf8.FromCodePoints(Normalize(utf8.CodePoints(s), form))
}

/// IsNormalized says whether code points are already in a form.
public func IsNormalized(_ cps: [uint32], _ form: Form) -> bool {
    // Pure ASCII is in every form.
    var ascii = true
    for cp in cps where cp >= 0x80 { ascii = false; break }
    if ascii { return true }
    return Normalize(cps, form) == cps
}
