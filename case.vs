package unicode

import "unicode/utf8"

// Case mapping and case folding (Unicode §3.13, UAX #44).
//
// The simple mappings map one code point to one (UnicodeData.txt); the
// full mappings may map one to several, as ß uppercases to SS
// (SpecialCasing.txt). Case folding is for comparing without regard to
// case (CaseFolding.txt).

/// pairLookup binary-searches a sorted from-table and returns the mapped
/// code point, or cp itself.
func pairLookup(_ from: [uint32], _ to: [uint32], _ cp: uint32) -> uint32 {
    var lo = 0
    var hi = from.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        let v = from[mid]
        if v == cp { return to[mid] }
        if v < cp { lo = mid + 1 } else { hi = mid - 1 }
    }
    return cp
}

/// multiLookup finds a one-to-many mapping, or nil.
func multiLookup(_ keys: [uint32], _ offsets: [uint32], _ data: [uint32], _ cp: uint32) -> [uint32]? {
    var lo = 0
    var hi = keys.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        let v = keys[mid]
        if v == cp {
            var out: [uint32] = []
            var i = int(offsets[mid])
            while i < int(offsets[mid + 1]) {
                out.append(data[i])
                i += 1
            }
            return out
        }
        if v < cp { lo = mid + 1 } else { hi = mid - 1 }
    }
    return nil
}

/// ToUpper is cp's simple uppercase mapping.
public func ToUpper(_ cp: uint32) -> uint32 {
    if cp < 0x80 { return cp >= 0x61 && cp <= 0x7A ? cp - 32 : cp }
    return pairLookup(upperFrom, upperTo, cp)
}

/// ToLower is cp's simple lowercase mapping.
public func ToLower(_ cp: uint32) -> uint32 {
    if cp < 0x80 { return cp >= 0x41 && cp <= 0x5A ? cp + 32 : cp }
    return pairLookup(lowerFrom, lowerTo, cp)
}

/// ToTitle is cp's simple titlecase mapping.
public func ToTitle(_ cp: uint32) -> uint32 {
    if cp < 0x80 { return cp >= 0x61 && cp <= 0x7A ? cp - 32 : cp }
    return pairLookup(titleFrom, titleTo, cp)
}

/// CaseFold is cp's simple case folding: the one code point that stands
/// for its case-insensitive class.
public func CaseFold(_ cp: uint32) -> uint32 {
    if cp < 0x80 { return cp >= 0x41 && cp <= 0x5A ? cp + 32 : cp }
    return pairLookup(foldFrom, foldTo, cp)
}

/// UppercaseMapping is cp's full uppercase mapping, which may be more
/// than one code point.
public func UppercaseMapping(_ cp: uint32) -> [uint32] {
    if cp >= 0x80, let m = multiLookup(specialUpperKeys, specialUpperOffsets, specialUpperData, cp) { return m }
    return [ToUpper(cp)]
}

/// LowercaseMapping is cp's full lowercase mapping, without the
/// context-dependent Final_Sigma rule (Lowercased applies it).
public func LowercaseMapping(_ cp: uint32) -> [uint32] {
    if cp >= 0x80, let m = multiLookup(specialLowerKeys, specialLowerOffsets, specialLowerData, cp) { return m }
    return [ToLower(cp)]
}

/// TitlecaseMapping is cp's full titlecase mapping.
public func TitlecaseMapping(_ cp: uint32) -> [uint32] {
    if cp >= 0x80, let m = multiLookup(specialTitleKeys, specialTitleOffsets, specialTitleData, cp) { return m }
    return [ToTitle(cp)]
}

/// CaseFoldMapping is cp's full case folding.
public func CaseFoldMapping(_ cp: uint32) -> [uint32] {
    if cp >= 0x80, let m = multiLookup(fullFoldKeys, fullFoldOffsets, fullFoldData, cp) { return m }
    return [CaseFold(cp)]
}

/// Uppercased applies the full uppercase mapping to text.
public func Uppercased(_ cps: [uint32]) -> [uint32] {
    var out: [uint32] = []
    out.reserveCapacity(cps.count)
    for cp in cps {
        if cp < 0x80 {
            out.append(cp >= 0x61 && cp <= 0x7A ? cp - 32 : cp)
        } else {
            out.append(contentsOf: UppercaseMapping(cp))
        }
    }
    return out
}

/// Lowercased applies the full lowercase mapping to text, with the
/// Final_Sigma rule: Σ becomes ς at the end of a word.
public func Lowercased(_ cps: [uint32]) -> [uint32] {
    var out: [uint32] = []
    out.reserveCapacity(cps.count)
    var i = 0
    while i < cps.count {
        let cp = cps[i]
        if cp < 0x80 {
            out.append(cp >= 0x41 && cp <= 0x5A ? cp + 32 : cp)
        } else if cp == 0x03A3 {
            out.append(isFinalSigma(cps, i) ? 0x03C2 : 0x03C3)
        } else {
            out.append(contentsOf: LowercaseMapping(cp))
        }
        i += 1
    }
    return out
}

/// CaseFolded applies full case folding to text.
public func CaseFolded(_ cps: [uint32]) -> [uint32] {
    var out: [uint32] = []
    out.reserveCapacity(cps.count)
    for cp in cps { out.append(contentsOf: CaseFoldMapping(cp)) }
    return out
}

/// isFinalSigma is the Final_Sigma condition (Unicode §3.13, table 3-17):
/// a cased letter comes before, skipping case-ignorables, and none after.
func isFinalSigma(_ cps: [uint32], _ at: int) -> bool {
    var j = at - 1
    var before = false
    while j >= 0 {
        let c = cps[j]
        if IsCaseIgnorable(c) {
            j -= 1
            continue
        }
        before = IsCased(c)
        break
    }
    if !before { return false }
    j = at + 1
    while j < cps.count {
        let c = cps[j]
        if IsCaseIgnorable(c) {
            j += 1
            continue
        }
        return !IsCased(c)
    }
    return true
}

/// EqualFold says whether two strings are equal under simple case folding.
public func EqualFold(_ a: string, _ b: string) -> bool {
    var ia = a.unicodeScalars.makeIterator()
    var ib = b.unicodeScalars.makeIterator()
    while true {
        let x = ia.next()
        let y = ib.next()
        if x == nil && y == nil { return true }
        if x == nil || y == nil { return false }
        if CaseFold(x!.value) != CaseFold(y!.value) { return false }
    }
}

/// UppercasedString, LowercasedString and CaseFoldedString are the text
/// forms for Vertex strings.
public func UppercasedString(_ s: string) -> string {
    return fromScalars(Uppercased(scalars(s)))
}

public func LowercasedString(_ s: string) -> string {
    return fromScalars(Lowercased(scalars(s)))
}

public func CaseFoldedString(_ s: string) -> string {
    return fromScalars(CaseFolded(scalars(s)))
}

func scalars(_ s: string) -> [uint32] {
    return utf8.CodePoints(s)
}

func fromScalars(_ cps: [uint32]) -> string {
    return utf8.FromCodePoints(cps)
}
