// Package unicode is the Unicode Character Database's properties of code
// points: general category, the binary properties (White_Space,
// Alphabetic, ID_Start, ...), scripts, and case mapping and folding.
//
// A code point is a uint32 from 0 to 0x10FFFF. The tables are generated
// from the UCD files in ucd/ by cmd/gen; Version says which Unicode.
//
// The encodings live beside it: unicode/utf8 and unicode/utf16.
package unicode

/// MaxCodePoint is the largest code point, U+10FFFF.
public let MaxCodePoint: uint32 = 0x10FFFF

/// ReplacementCharacter is U+FFFD, what malformed input decodes to.
public let ReplacementCharacter: uint32 = 0xFFFD

/// IsValid says whether cp is a code point that can be encoded: in range
/// and not a surrogate.
public func IsValid(_ cp: uint32) -> bool {
    return cp <= MaxCodePoint && !IsSurrogate(cp)
}

/// IsSurrogate says whether cp is in U+D800...U+DFFF, the range UTF-16
/// reserves for pairs.
public func IsSurrogate(_ cp: uint32) -> bool {
    return cp >= 0xD800 && cp <= 0xDFFF
}

// MARK: general category

/// GeneralCategory is a code point's General_Category (UAX #44).
public enum GeneralCategory: Equatable {
    case unassigned            // Cn
    case uppercaseLetter       // Lu
    case lowercaseLetter       // Ll
    case titlecaseLetter       // Lt
    case modifierLetter        // Lm
    case otherLetter           // Lo
    case nonspacingMark        // Mn
    case spacingMark           // Mc
    case enclosingMark         // Me
    case decimalNumber         // Nd
    case letterNumber          // Nl
    case otherNumber           // No
    case connectorPunctuation  // Pc
    case dashPunctuation       // Pd
    case openPunctuation       // Ps
    case closePunctuation      // Pe
    case initialPunctuation    // Pi
    case finalPunctuation      // Pf
    case otherPunctuation      // Po
    case mathSymbol            // Sm
    case currencySymbol        // Sc
    case modifierSymbol        // Sk
    case otherSymbol           // So
    case spaceSeparator        // Zs
    case lineSeparator         // Zl
    case paragraphSeparator    // Zp
    case control               // Cc
    case format                // Cf
    case surrogate             // Cs
    case privateUse            // Co

    /// Abbreviation is the two-letter short name, as in "Lu".
    public var Abbreviation: string {
        return categoryAbbreviations[Index]
    }

    /// Index is the category's position in the generated tables.
    public var Index: int {
        switch self {
        case .unassigned: return 0
        case .uppercaseLetter: return 1
        case .lowercaseLetter: return 2
        case .titlecaseLetter: return 3
        case .modifierLetter: return 4
        case .otherLetter: return 5
        case .nonspacingMark: return 6
        case .spacingMark: return 7
        case .enclosingMark: return 8
        case .decimalNumber: return 9
        case .letterNumber: return 10
        case .otherNumber: return 11
        case .connectorPunctuation: return 12
        case .dashPunctuation: return 13
        case .openPunctuation: return 14
        case .closePunctuation: return 15
        case .initialPunctuation: return 16
        case .finalPunctuation: return 17
        case .otherPunctuation: return 18
        case .mathSymbol: return 19
        case .currencySymbol: return 20
        case .modifierSymbol: return 21
        case .otherSymbol: return 22
        case .spaceSeparator: return 23
        case .lineSeparator: return 24
        case .paragraphSeparator: return 25
        case .control: return 26
        case .format: return 27
        case .surrogate: return 28
        case .privateUse: return 29
        }
    }

    /// FromIndex is the category at a table index.
    public static func FromIndex(_ i: int) -> GeneralCategory {
        return allCategories[i]
    }
}

let allCategories: [GeneralCategory] = [
    .unassigned, .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
    .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber,
    .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation,
    .finalPunctuation, .otherPunctuation, .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol,
    .spaceSeparator, .lineSeparator, .paragraphSeparator, .control, .format, .surrogate, .privateUse,
]

let categoryAbbreviations: [string] = ["Cn", "Lu", "Ll", "Lt", "Lm", "Lo", "Mn", "Mc", "Me", "Nd", "Nl", "No", "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po", "Sm", "Sc", "Sk", "So", "Zs", "Zl", "Zp", "Cc", "Cf", "Cs", "Co"]

/// categoryIndex is the table index of cp's category.
func categoryIndex(_ cp: uint32) -> int {
    if cp > MaxCodePoint { return 0 }
    return int(categoryKind[runIndex(categoryStart, cp)])
}

/// runIndex finds the run containing cp: the last start at or below it.
func runIndex(_ starts: [uint32], _ cp: uint32) -> int {
    var lo = 0
    var hi = starts.count - 1
    while lo < hi {
        let mid = (lo + hi + 1) / 2
        if starts[mid] <= cp { lo = mid } else { hi = mid - 1 }
    }
    return lo
}

/// Category is cp's General_Category.
public func Category(_ cp: uint32) -> GeneralCategory {
    return allCategories[categoryIndex(cp)]
}

/// IsLetter: L (Lu, Ll, Lt, Lm, Lo).
public func IsLetter(_ cp: uint32) -> bool {
    if cp < 0x80 { return (cp | 0x20) >= 0x61 && (cp | 0x20) <= 0x7A }
    let c = categoryIndex(cp)
    return c >= 1 && c <= 5
}

/// IsMark: M (Mn, Mc, Me).
public func IsMark(_ cp: uint32) -> bool {
    let c = categoryIndex(cp)
    return c >= 6 && c <= 8
}

/// IsNumber: N (Nd, Nl, No).
public func IsNumber(_ cp: uint32) -> bool {
    if cp < 0x80 { return cp >= 0x30 && cp <= 0x39 }
    let c = categoryIndex(cp)
    return c >= 9 && c <= 11
}

/// IsDigit: Nd, a decimal digit in any script.
public func IsDigit(_ cp: uint32) -> bool {
    if cp < 0x80 { return cp >= 0x30 && cp <= 0x39 }
    return categoryIndex(cp) == 9
}

/// IsPunctuation: P (Pc, Pd, Ps, Pe, Pi, Pf, Po).
public func IsPunctuation(_ cp: uint32) -> bool {
    let c = categoryIndex(cp)
    return c >= 12 && c <= 18
}

/// IsSymbol: S (Sm, Sc, Sk, So).
public func IsSymbol(_ cp: uint32) -> bool {
    let c = categoryIndex(cp)
    return c >= 19 && c <= 22
}

/// IsSeparator: Z (Zs, Zl, Zp).
public func IsSeparator(_ cp: uint32) -> bool {
    let c = categoryIndex(cp)
    return c >= 23 && c <= 25
}

/// IsControl: Cc.
public func IsControl(_ cp: uint32) -> bool {
    return categoryIndex(cp) == 26
}

/// IsAssigned: anything but Cn.
public func IsAssigned(_ cp: uint32) -> bool {
    return categoryIndex(cp) != 0
}

// MARK: binary properties

/// PropertySet is the code points that have one binary property, as
/// sorted ranges.
public struct PropertySet {
    /// Ranges is flat [first, last, first, last, ...], ascending.
    public let Ranges: [uint32]

    public init(ranges: [uint32]) {
        self.Ranges = ranges
    }

    /// Contains says whether cp has the property.
    public func Contains(_ cp: uint32) -> bool {
        return inRanges(Ranges, cp)
    }
}

/// inRanges binary-searches flat [lo, hi] pairs.
func inRanges(_ r: [uint32], _ cp: uint32) -> bool {
    var lo = 0
    var hi = r.count / 2 - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if cp < r[mid * 2] {
            hi = mid - 1
        } else if cp > r[mid * 2 + 1] {
            lo = mid + 1
        } else {
            return true
        }
    }
    return false
}

func propertyIndex(_ name: string) -> int {
    var i = 0
    while i < propertyNames.count {
        if propertyNames[i] == name { return i }
        i += 1
    }
    return -1
}

/// Property is the set for a binary property by any of its names: long
/// ("White_Space"), short ("WSpace") or other alias ("space"). Nil if
/// there is no such binary property.
public func Property(_ name: string) -> PropertySet? {
    var i = propertyIndex(name)
    if i < 0 {
        var a = 0
        while a < propertyAliasFrom.count {
            if propertyAliasFrom[a] == name {
                i = propertyIndex(propertyAliasTo[a])
                break
            }
            a += 1
        }
    }
    if i < 0 { return nil }
    return PropertySet(ranges: propertyRanges[i])
}

/// PropertyNames lists the binary properties Property knows.
public var PropertyNames: [string] { return propertyNames }

let whiteSpaceRanges = propertyRanges[propertyIndex("White_Space")]
let alphabeticRanges = propertyRanges[propertyIndex("Alphabetic")]
let uppercaseRanges = propertyRanges[propertyIndex("Uppercase")]
let lowercaseRanges = propertyRanges[propertyIndex("Lowercase")]
let casedRanges = propertyRanges[propertyIndex("Cased")]
let caseIgnorableRanges = propertyRanges[propertyIndex("Case_Ignorable")]
let idStartRanges = propertyRanges[propertyIndex("ID_Start")]
let idContinueRanges = propertyRanges[propertyIndex("ID_Continue")]

/// IsWhitespace is the White_Space property.
public func IsWhitespace(_ cp: uint32) -> bool {
    if cp < 0x80 { return cp == 0x20 || (cp >= 0x09 && cp <= 0x0D) }
    return inRanges(whiteSpaceRanges, cp)
}

/// IsAlphabetic is the Alphabetic property: letters, and marks and
/// numbers that behave as letters.
public func IsAlphabetic(_ cp: uint32) -> bool {
    if cp < 0x80 { return (cp | 0x20) >= 0x61 && (cp | 0x20) <= 0x7A }
    return inRanges(alphabeticRanges, cp)
}

/// IsUppercase is the Uppercase property (Lu and Other_Uppercase).
public func IsUppercase(_ cp: uint32) -> bool {
    if cp < 0x80 { return cp >= 0x41 && cp <= 0x5A }
    return inRanges(uppercaseRanges, cp)
}

/// IsLowercase is the Lowercase property (Ll and Other_Lowercase).
public func IsLowercase(_ cp: uint32) -> bool {
    if cp < 0x80 { return cp >= 0x61 && cp <= 0x7A }
    return inRanges(lowercaseRanges, cp)
}

/// IsCased is the Cased property.
public func IsCased(_ cp: uint32) -> bool {
    return inRanges(casedRanges, cp)
}

/// IsCaseIgnorable is the Case_Ignorable property.
public func IsCaseIgnorable(_ cp: uint32) -> bool {
    return inRanges(caseIgnorableRanges, cp)
}

/// IsIDStart is ID_Start (UAX #31): what may begin an identifier.
public func IsIDStart(_ cp: uint32) -> bool {
    if cp < 0x80 { return (cp | 0x20) >= 0x61 && (cp | 0x20) <= 0x7A }
    return inRanges(idStartRanges, cp)
}

/// IsIDContinue is ID_Continue (UAX #31): what may follow in one.
public func IsIDContinue(_ cp: uint32) -> bool {
    if cp < 0x80 { return ((cp | 0x20) >= 0x61 && (cp | 0x20) <= 0x7A) || (cp >= 0x30 && cp <= 0x39) || cp == 0x5F }
    return inRanges(idContinueRanges, cp)
}

// MARK: scripts

/// Script is cp's Script property, by its long name ("Latin", "Greek",
/// "Common", "Unknown").
public func Script(_ cp: uint32) -> string {
    if cp > MaxCodePoint { return "Unknown" }
    return scriptNames[int(scriptKind[runIndex(scriptStart, cp)])]
}

/// ScriptExtensions is cp's Script_Extensions, as long names: the scripts
/// a shared character is used with.
public func ScriptExtensions(_ cp: uint32) -> [string] {
    var lo = 0
    var hi = scxRanges.count / 2 - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if cp < scxRanges[mid * 2] {
            hi = mid - 1
        } else if cp > scxRanges[mid * 2 + 1] {
            lo = mid + 1
        } else {
            var out: [string] = []
            var j = int(scxOffsets[mid])
            while j < int(scxOffsets[mid + 1]) {
                out.append(scriptNames[int(scxData[j])])
                j += 1
            }
            return out
        }
    }
    return [Script(cp)]
}

/// ScriptName resolves a script's long or short name ("Greek" or "Grek")
/// to its long name, or nil.
public func ScriptName(_ name: string) -> string? {
    var i = 0
    while i < scriptNames.count {
        if scriptNames[i] == name || scriptShortNames[i] == name { return scriptNames[i] }
        i += 1
    }
    return nil
}

/// ScriptRanges is the set of code points of one script (by long name),
/// or with extensions, the ones whose Script_Extensions include it.
public func ScriptRanges(_ name: string, extensions: bool = false) -> PropertySet {
    var idx = -1
    var i = 0
    while i < scriptNames.count {
        if scriptNames[i] == name { idx = i; break }
        i += 1
    }
    var out: [uint32] = []
    if idx < 0 { return PropertySet(ranges: out) }
    var r = 0
    while r < scriptStart.count {
        let end: uint32 = r + 1 < scriptStart.count ? scriptStart[r + 1] - 1 : MaxCodePoint
        if int(scriptKind[r]) == idx {
            out.append(scriptStart[r])
            out.append(end)
        }
        r += 1
    }
    if !extensions { return PropertySet(ranges: out) }
    // Remove the ranges Script_Extensions overrides, then add the ones that
    // name this script.
    var result: [uint32] = []
    var k = 0
    while k + 1 < out.count {
        var lo = out[k]
        let hi = out[k + 1]
        var e = 0
        while e * 2 + 1 < scxRanges.count && lo <= hi {
            let elo = scxRanges[e * 2]
            let ehi = scxRanges[e * 2 + 1]
            if ehi >= lo && elo <= hi {
                if elo > lo {
                    result.append(lo)
                    result.append(elo - 1)
                }
                lo = ehi + 1
            }
            e += 1
        }
        if lo <= hi {
            result.append(lo)
            result.append(hi)
        }
        k += 2
    }
    var e = 0
    while e * 2 + 1 < scxRanges.count {
        var j = int(scxOffsets[e])
        while j < int(scxOffsets[e + 1]) {
            if int(scxData[j]) == idx {
                result.append(scxRanges[e * 2])
                result.append(scxRanges[e * 2 + 1])
                break
            }
            j += 1
        }
        e += 1
    }
    return PropertySet(ranges: sortRanges(result))
}

func sortRanges(_ flat: [uint32]) -> [uint32] {
    var pairs: [(uint32, uint32)] = []
    var i = 0
    while i + 1 < flat.count {
        pairs.append((flat[i], flat[i + 1]))
        i += 2
    }
    pairs.sort { $0.0 < $1.0 }
    var out: [uint32] = []
    for (lo, hi) in pairs {
        if !out.isEmpty && lo <= out[out.count - 1] + 1 {
            if hi > out[out.count - 1] { out[out.count - 1] = hi }
        } else {
            out.append(lo)
            out.append(hi)
        }
    }
    return out
}

/// CategoryAbbreviation resolves a general category's or group's name
/// ("Letter", "Lu", "Uppercase_Letter", "digit") to its abbreviation, or nil.
public func CategoryAbbreviation(_ name: string) -> string? {
    for a in categoryAbbreviations where a == name { return a }
    var i = 0
    while i < categoryAliasFrom.count {
        if categoryAliasFrom[i] == name { return categoryAliasTo[i] }
        i += 1
    }
    for g in ["L", "LC", "M", "N", "P", "S", "Z", "C"] where g == name { return g }
    return nil
}

/// CategoryRanges is the set of code points in a general category, or in
/// a group of them (L, M, N, P, S, Z, C, or LC), by any of its names.
public func CategoryRanges(_ name: string) -> PropertySet? {
    guard let abbreviation = CategoryAbbreviation(name) else { return nil }
    var want: [int] = []
    var i = 0
    while i < categoryAbbreviations.count {
        let a = categoryAbbreviations[i]
        if a == abbreviation || (abbreviation.count == 1 && a.hasPrefix(abbreviation)) {
            want.append(i)
        }
        i += 1
    }
    if abbreviation == "LC" { want = [1, 2, 3] }
    if want.isEmpty { return nil }
    var out: [uint32] = []
    var r = 0
    while r < categoryStart.count {
        if want.contains(int(categoryKind[r])) {
            let end: uint32 = r + 1 < categoryStart.count ? categoryStart[r + 1] - 1 : MaxCodePoint
            if !out.isEmpty && out[out.count - 1] + 1 == categoryStart[r] {
                out[out.count - 1] = end
            } else {
                out.append(categoryStart[r])
                out.append(end)
            }
        }
        r += 1
    }
    return PropertySet(ranges: out)
}
