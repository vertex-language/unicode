// Generates tables.vs from the Unicode Character Database in ucd/.
//
//     vsc run gen
//
// Run it from the repository's root after replacing ucd/ with a new
// version's files; it writes tables.vs there.
package main

import "fs"

let version = "17.0.0"

// MARK: reading UCD files

/// fields reads a UCD file's data lines: comments stripped, split on ;,
/// each field trimmed. Blank lines are skipped.
func fields(_ name: string) throws -> [[string]] {
    let text = try fs.ReadText(fs.Path("ucd/" + name))
    var out: [[string]] = []
    for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
        var bytes: [uint8] = []
        for b in string(line).utf8 {
            if b == 0x23 { break }
            bytes.append(b)
        }
        var parts: [string] = []
        var cur: [uint8] = []
        var any = false
        for b in bytes {
            if b == 0x3B {
                parts.append(trim(cur))
                cur = []
            } else {
                cur.append(b)
                if b != 0x20 && b != 0x09 && b != 0x0D { any = true }
            }
        }
        parts.append(trim(cur))
        if any { out.append(parts) }
    }
    return out
}

func trim(_ b: [uint8]) -> string {
    var s = 0
    var e = b.count
    while s < e && (b[s] == 0x20 || b[s] == 0x09 || b[s] == 0x0D) { s += 1 }
    while e > s && (b[e - 1] == 0x20 || b[e - 1] == 0x09 || b[e - 1] == 0x0D) { e -= 1 }
    var out: [uint8] = []
    var i = s
    while i < e { out.append(b[i]); i += 1 }
    return string(decoding: out, as: UTF8.self)
}

func hex(_ s: string) -> uint32 {
    var v: uint32 = 0
    for c in s.utf8 {
        var d: uint32 = 0
        if c >= 0x30 && c <= 0x39 { d = uint32(c - 0x30) } else if c >= 0x41 && c <= 0x46 { d = uint32(c - 0x41 + 10) } else if c >= 0x61 && c <= 0x66 { d = uint32(c - 0x61 + 10) } else { continue }
        v = v * 16 + d
    }
    return v
}

/// codeRange reads "0041" or "0041..005A".
func codeRange(_ s: string) -> (uint32, uint32) {
    var first: [uint8] = []
    var second: [uint8] = []
    var dots = 0
    for c in s.utf8 {
        if c == 0x2E { dots += 1; continue }
        if dots == 0 { first.append(c) } else { second.append(c) }
    }
    let lo = hex(string(decoding: first, as: UTF8.self))
    if second.isEmpty { return (lo, lo) }
    return (lo, hex(string(decoding: second, as: UTF8.self)))
}

/// codes reads a space-separated list of code points.
func codes(_ s: string) -> [uint32] {
    var out: [uint32] = []
    for part in s.split(separator: " ", omittingEmptySubsequences: true) {
        out.append(hex(string(part)))
    }
    return out
}

// MARK: range sets

/// propertyRanges collects every binary property named in a file into
/// sorted, merged range sets, in the order the file names them.
func propertyRanges(_ file: string) throws -> [(string, [uint32])] {
    var order: [string] = []
    var raw: [string: [uint32]] = [:]
    for f in try fields(file) {
        // Enumerated properties (Indic_Conjunct_Break) have a third field.
        if f.count != 2 { continue }
        let name = f[1]
        let (lo, hi) = codeRange(f[0])
        var list = raw[name] ?? []
        if list.isEmpty { order.append(name) }
        list.append(lo)
        list.append(hi)
        raw[name] = list
    }
    var out: [(string, [uint32])] = []
    for name in order { out.append((name, merge(raw[name]!))) }
    return out
}

/// merge sorts flat ranges and joins the ones that touch or overlap.
func merge(_ flat: [uint32]) -> [uint32] {
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

// MARK: output

final class Writer {
    var text: string = ""

    func line(_ s: string) { text += s + "\n" }

    func array(_ name: string, _ type: string, _ values: [uint32], hexFormat: bool = true) {
        text += "let \(name): [\(type)] = ["
        var i = 0
        for v in values {
            if i % 12 == 0 { text += "\n   " }
            text += " " + (hexFormat ? hexString(v) : "\(v)") + ","
            i += 1
        }
        text += "\n]\n\n"
    }
}

func hexString(_ v: uint32) -> string {
    let digits: [uint8] = [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70]
    var out: [uint8] = []
    var x = v
    if x == 0 { return "0x0" }
    while x > 0 {
        out.insert(digits[int(x & 15)], at: 0)
        x >>= 4
    }
    return "0x" + string(decoding: out, as: UTF8.self)
}

let categoryNames: [string] = ["Cn", "Lu", "Ll", "Lt", "Lm", "Lo", "Mn", "Mc", "Me", "Nd", "Nl", "No", "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po", "Sm", "Sc", "Sk", "So", "Zs", "Zl", "Zp", "Cc", "Cf", "Cs", "Co"]

func categoryIndex(_ s: string) -> uint32 {
    var i = 0
    while i < categoryNames.count {
        if categoryNames[i] == s { return uint32(i) }
        i += 1
    }
    return 0
}

func pairs(_ w: Writer, _ name: string, _ list: [(uint32, uint32)]) {
    var from: [uint32] = []
    var to: [uint32] = []
    for (a, b) in list {
        from.append(a)
        to.append(b)
    }
    w.array(name + "From", "uint32", from)
    w.array(name + "To", "uint32", to)
}

func multi(_ w: Writer, _ name: string, _ keys: [uint32], _ values: [[uint32]]) {
    var offsets: [uint32] = []
    var data: [uint32] = []
    for v in values {
        offsets.append(uint32(data.count))
        data.append(contentsOf: v)
    }
    offsets.append(uint32(data.count))
    w.array(name + "Keys", "uint32", keys)
    w.array(name + "Offsets", "uint32", offsets, hexFormat: false)
    w.array(name + "Data", "uint32", data)
}

func main() -> int32 {
    do {
        try run()
    } catch {
        print("gen: \(error)")
        return 1
    }
    return 0
}

func run() throws {
    let w = Writer()
    w.line("// Code generated by cmd/gen from the Unicode Character Database \(version) in ucd/. DO NOT EDIT.")
    w.line("")
    w.line("package unicode")
    w.line("")
    w.line("/// Version is the version of the Unicode Standard the tables follow.")
    w.line("public let Version = \"\(version)\"")
    w.line("")

    // General_Category, and the simple case mappings.
    var cat = [uint8](repeating: 0, count: 0x110000)
    var upper: [(uint32, uint32)] = []
    var lower: [(uint32, uint32)] = []
    var title: [(uint32, uint32)] = []
    var rangeStart: uint32 = 0
    for f in try fields("UnicodeData.txt") {
        let cp = hex(f[0])
        let name = f[1]
        let c = uint8(categoryIndex(f[2]))
        if name.hasSuffix(", First>") {
            rangeStart = cp
            continue
        }
        if name.hasSuffix(", Last>") {
            var x = rangeStart
            while x <= cp { cat[int(x)] = c; x += 1 }
            continue
        }
        cat[int(cp)] = c
        if !f[12].isEmpty { upper.append((cp, hex(f[12]))) }
        if !f[13].isEmpty { lower.append((cp, hex(f[13]))) }
        if !f[14].isEmpty {
            title.append((cp, hex(f[14])))
        } else if !f[12].isEmpty {
            title.append((cp, hex(f[12])))
        }
    }
    var starts: [uint32] = []
    var kinds: [uint32] = []
    var i = 0
    while i < 0x110000 {
        if i == 0 || cat[i] != cat[i - 1] {
            starts.append(uint32(i))
            kinds.append(uint32(cat[i]))
        }
        i += 1
    }
    w.line("// General_Category as runs: categoryStart[i] begins a run of categoryKind[i],")
    w.line("// indexes into GeneralCategory's cases in the order of categoryAbbreviations.")
    w.array("categoryStart", "uint32", starts)
    w.array("categoryKind", "uint8", kinds, hexFormat: false)

    w.line("// Simple (one-to-one) case mappings, sorted by code point.")
    pairs(w, "upper", upper)
    pairs(w, "lower", lower)
    pairs(w, "title", title)

    // SpecialCasing: the unconditional one-to-many mappings. The conditional
    // ones (Final_Sigma, and language-sensitive ones) are handled in code.
    var spKeys: [uint32] = []
    var spLower: [[uint32]] = []
    var spTitle: [[uint32]] = []
    var spUpper: [[uint32]] = []
    for f in try fields("SpecialCasing.txt") {
        if f.count >= 5 && !f[4].isEmpty { continue }
        spKeys.append(hex(f[0]))
        spLower.append(codes(f[1]))
        spTitle.append(codes(f[2]))
        spUpper.append(codes(f[3]))
    }
    // SpecialCasing.txt isn't in code point order; the lookups binary-search.
    var order: [int] = []
    var k = 0
    while k < spKeys.count { order.append(k); k += 1 }
    order.sort { spKeys[$0] < spKeys[$1] }
    var sk: [uint32] = []
    var sl: [[uint32]] = []
    var st: [[uint32]] = []
    var su: [[uint32]] = []
    for o in order {
        sk.append(spKeys[o])
        sl.append(spLower[o])
        st.append(spTitle[o])
        su.append(spUpper[o])
    }
    spKeys = sk
    spLower = sl
    spTitle = st
    spUpper = su
    w.line("// Full case mappings that differ from the simple ones (SpecialCasing.txt,")
    w.line("// unconditional entries): the mapping of keys[i] is data[offsets[i]..<offsets[i+1]].")
    multi(w, "specialLower", spKeys, spLower)
    multi(w, "specialTitle", spKeys, spTitle)
    multi(w, "specialUpper", spKeys, spUpper)

    // CaseFolding: C and S make simple folding, C and F full folding.
    var simpleFold: [(uint32, uint32)] = []
    var fullKeys: [uint32] = []
    var fullVals: [[uint32]] = []
    for f in try fields("CaseFolding.txt") {
        let cp = hex(f[0])
        let status = f[1]
        let m = codes(f[2])
        if status == "C" || status == "S" { simpleFold.append((cp, m[0])) }
        if status == "F" {
            fullKeys.append(cp)
            fullVals.append(m)
        }
    }
    w.line("// Simple case folding (CaseFolding.txt, statuses C and S).")
    pairs(w, "fold", simpleFold)
    w.line("// Full case folding where it differs from simple (status F).")
    multi(w, "fullFold", fullKeys, fullVals)

    // Binary properties.
    var props = try propertyRanges("PropList.txt")
    props.append(contentsOf: try propertyRanges("DerivedCoreProperties.txt"))
    props.append(contentsOf: try propertyRanges("DerivedBinaryProperties.txt"))
    props.append(contentsOf: try propertyRanges("DerivedNormalizationProps.txt"))
    props.append(contentsOf: try propertyRanges("emoji-data.txt"))
    var names: [string] = []
    w.line("// Binary properties (PropList, DerivedCoreProperties, DerivedBinaryProperties,")
    w.line("// DerivedNormalizationProps and emoji-data): each is")
    w.line("// flat [first, last, first, last, ...] ranges, named in propertyNames.")
    var n = 0
    for (name, r) in props {
        names.append(name)
        w.array("prop\(n)", "uint32", r)
        n += 1
    }
    w.text += "let propertyNames: [string] = [\n"
    for name in names { w.text += "    \"\(name)\",\n" }
    w.text += "]\n\n"
    w.text += "let propertyRanges: [[uint32]] = [\n"
    var j = 0
    while j < n { w.text += "    prop\(j),\n"; j += 1 }
    w.text += "]\n\n"

    // Aliases: every name PropertyAliases.txt gives a property we have, and
    // every name PropertyValueAliases.txt gives a general category or group.
    var aliasFrom: [string] = []
    var aliasTo: [string] = []
    for f in try fields("PropertyAliases.txt") {
        guard f.count >= 2 else { continue }
        var long = ""
        for x in f where names.contains(x) { long = x }
        if long.isEmpty { continue }
        for x in f where !x.isEmpty && x != long {
            aliasFrom.append(x)
            aliasTo.append(long)
        }
    }
    w.line("// Other names of the binary properties (PropertyAliases.txt).")
    w.text += "let propertyAliasFrom: [string] = [\n"
    for a in aliasFrom { w.text += "    \"\(a)\",\n" }
    w.text += "]\n\n"
    w.text += "let propertyAliasTo: [string] = [\n"
    for a in aliasTo { w.text += "    \"\(a)\",\n" }
    w.text += "]\n\n"
    var catFrom: [string] = []
    var catTo: [string] = []
    for f in try fields("PropertyValueAliases.txt") {
        guard f.count >= 3 && f[0] == "gc" else { continue }
        var k = 2
        while k < f.count {
            if !f[k].isEmpty {
                catFrom.append(f[k])
                catTo.append(f[1])
            }
            k += 1
        }
    }
    w.line("// Long names and other aliases of the general categories and their groups,")
    w.line("// each to its abbreviation (PropertyValueAliases.txt, gc).")
    w.text += "let categoryAliasFrom: [string] = [\n"
    for a in catFrom { w.text += "    \"\(a)\",\n" }
    w.text += "]\n\n"
    w.text += "let categoryAliasTo: [string] = [\n"
    for a in catTo { w.text += "    \"\(a)\",\n" }
    w.text += "]\n\n"

    // Scripts, with their aliases, and Script_Extensions.
    var aliasShort: [string: string] = [:]
    var aliasOrder: [(string, string)] = []
    for f in try fields("PropertyValueAliases.txt") {
        if f.count >= 3 && f[0] == "sc" {
            aliasShort[f[2]] = f[1]
            aliasOrder.append((f[1], f[2]))
        }
    }
    var scriptOf = [int32](repeating: -1, count: 0x110000)
    var scriptNames: [string] = []
    var scriptIndex: [string: int] = [:]
    for (short, long) in aliasOrder {
        _ = short
        scriptIndex[long] = scriptNames.count
        scriptNames.append(long)
    }
    for f in try fields("Scripts.txt") {
        let (lo, hi) = codeRange(f[0])
        guard let idx = scriptIndex[f[1]] else { continue }
        var c = lo
        while c <= hi { scriptOf[int(c)] = int32(idx); c += 1 }
    }
    // Code points no line names are Unknown (Zzzz).
    let unknown = scriptIndex["Unknown"] ?? 0
    var sStarts: [uint32] = []
    var sKinds: [uint32] = []
    i = 0
    while i < 0x110000 {
        if scriptOf[i] < 0 { scriptOf[i] = int32(unknown) }
        if i == 0 || scriptOf[i] != scriptOf[i - 1] {
            sStarts.append(uint32(i))
            sKinds.append(uint32(scriptOf[i]))
        }
        i += 1
    }
    w.line("// Script as runs, like General_Category; values index scriptNames.")
    w.array("scriptStart", "uint32", sStarts)
    w.array("scriptKind", "uint16", sKinds, hexFormat: false)
    w.text += "let scriptNames: [string] = [\n"
    for s in scriptNames { w.text += "    \"\(s)\",\n" }
    w.text += "]\n\n"
    w.text += "let scriptShortNames: [string] = [\n"
    for s in scriptNames { w.text += "    \"\(aliasShort[s] ?? s)\",\n" }
    w.text += "]\n\n"

    // Script_Extensions: ranges whose value is a set of scripts, as short names.
    var scxRanges: [uint32] = []
    var scxOffsets: [uint32] = []
    var scxData: [uint32] = []
    var shortIndex: [string: int] = [:]
    for (short, long) in aliasOrder { shortIndex[short] = scriptIndex[long] ?? 0 }
    for f in try fields("ScriptExtensions.txt") {
        let (lo, hi) = codeRange(f[0])
        scxRanges.append(lo)
        scxRanges.append(hi)
        scxOffsets.append(uint32(scxData.count))
        for part in f[1].split(separator: " ", omittingEmptySubsequences: true) {
            scxData.append(uint32(shortIndex[string(part)] ?? 0))
        }
    }
    scxOffsets.append(uint32(scxData.count))
    w.line("// Script_Extensions: scxRanges[2i...2i+1] have the scripts")
    w.line("// scxData[scxOffsets[i]..<scxOffsets[i+1]]; other code points have their Script.")
    w.array("scxRanges", "uint32", scxRanges)
    w.array("scxOffsets", "uint32", scxOffsets, hexFormat: false)
    w.array("scxData", "uint16", scxData, hexFormat: false)

    try fs.WriteText(fs.Path("tables.vs"), w.text)
    print("wrote tables.vs: \(starts.count) category runs, \(upper.count)/\(lower.count)/\(title.count) case pairs, \(spKeys.count) special casings, \(simpleFold.count)+\(fullKeys.count) foldings, \(names.count) properties, \(scriptNames.count) scripts, \(scxRanges.count / 2) extension ranges")
}
