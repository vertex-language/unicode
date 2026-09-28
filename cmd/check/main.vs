// The unicode repository's checks: properties, case mapping and the
// encodings, against facts from the UCD files.
//
//     vsc run check
package main

import (
    "unicode"
    "unicode/utf8"
    "unicode/utf16"
)

var failures = 0

func check(_ ok: bool, _ msg: string) {
    if ok {
        print("ok    \(msg)")
    } else {
        print("FAIL  \(msg)")
        failures += 1
    }
}

func same(_ a: [uint32], _ b: [uint32]) -> bool {
    if a.count != b.count { return false }
    var i = 0
    while i < a.count {
        if a[i] != b[i] { return false }
        i += 1
    }
    return true
}

func main() -> int32 {
    check(unicode.Version == "17.0.0", "Version is 17.0.0")

    // General_Category.
    check(unicode.Category(0x41) == .uppercaseLetter, "category: A is Lu")
    check(unicode.Category(0x3B1) == .lowercaseLetter, "category: α is Ll")
    check(unicode.Category(0x1C5) == .titlecaseLetter, "category: ǅ is Lt")
    check(unicode.Category(0x4E00) == .otherLetter, "category: 一 (in a First/Last range) is Lo")
    check(unicode.Category(0x0301) == .nonspacingMark, "category: U+0301 is Mn")
    check(unicode.Category(0x0660) == .decimalNumber, "category: Arabic-Indic zero is Nd")
    check(unicode.Category(0x2028) == .lineSeparator, "category: U+2028 is Zl")
    check(unicode.Category(0x20AC) == .currencySymbol, "category: € is Sc")
    check(unicode.Category(0xD800) == .surrogate, "category: U+D800 is Cs")
    check(unicode.Category(0xE000) == .privateUse, "category: U+E000 is Co")
    check(unicode.Category(0x0378) == .unassigned, "category: U+0378 is Cn")
    check(unicode.Category(0x10FFFF) == .unassigned, "category: U+10FFFF is Cn")
    check(unicode.Category(0x1F600) == .otherSymbol, "category: 😀 is So")
    check(unicode.Category(0x41).Abbreviation == "Lu", "category: Abbreviation")
    check(unicode.IsLetter(0x5D0) && !unicode.IsLetter(0x30), "IsLetter: Hebrew alef, not a digit")
    check(unicode.IsDigit(0x0967) && !unicode.IsDigit(0x2167), "IsDigit: Devanagari one, not Roman numeral eight")
    check(unicode.IsNumber(0x2167), "IsNumber: Roman numeral eight (Nl)")
    check(unicode.IsPunctuation(0x00BF) && unicode.IsSymbol(0x2211), "IsPunctuation ¿, IsSymbol ∑")

    // Binary properties.
    check(unicode.IsWhitespace(0x20) && unicode.IsWhitespace(0xA0) && unicode.IsWhitespace(0x3000) && unicode.IsWhitespace(0x85), "IsWhitespace: space, NBSP, ideographic space, NEL")
    check(!unicode.IsWhitespace(0x200B) && !unicode.IsWhitespace(0xFEFF), "IsWhitespace: not ZWSP or BOM")
    check(unicode.IsIDStart(0x24) == false && unicode.IsIDStart(0x3B1) && unicode.IsIDStart(0x2118), "IsIDStart: not $, α, ℘ (Other_ID_Start)")
    check(unicode.IsIDContinue(0x0301) && unicode.IsIDContinue(0xB7) && !unicode.IsIDContinue(0x2D), "IsIDContinue: U+0301, middle dot, not -")
    check(unicode.IsAlphabetic(0x0345) && unicode.IsUppercase(0x2160) && unicode.IsLowercase(0xAA), "IsAlphabetic, IsUppercase Ⅰ, IsLowercase ª")
    check(unicode.IsCased(0x3A3) && unicode.IsCaseIgnorable(0x27), "IsCased Σ, IsCaseIgnorable apostrophe")
    if let ws = unicode.Property("White_Space") {
        check(ws.Contains(0x2029) && !ws.Contains(0x41), "Property: White_Space by name")
    } else {
        check(false, "Property: White_Space by name")
    }
    check(unicode.Property("No_Such_Property") == nil, "Property: unknown name is nil")
    if let a = unicode.Property("Alpha"), let s = unicode.Property("space"), let e = unicode.Property("Extended_Pictographic"), let m = unicode.Property("Bidi_M") {
        check(a.Contains(0x41) && s.Contains(0x20) && e.Contains(0x1F600) && m.Contains(0x28), "Property: short names, aliases, emoji and Bidi_Mirrored")
    } else {
        check(false, "Property: short names, aliases, emoji and Bidi_Mirrored")
    }
    check(unicode.CategoryAbbreviation("Uppercase_Letter") == "Lu" && unicode.CategoryAbbreviation("digit") == "Nd" && unicode.CategoryAbbreviation("Letter") == "L", "CategoryAbbreviation: long names and aliases")
    check(unicode.PropertyNames.count > 50, "PropertyNames: all of PropList and DerivedCoreProperties")

    // Scripts.
    check(unicode.Script(0x41) == "Latin" && unicode.Script(0x3B1) == "Greek" && unicode.Script(0x30) == "Common", "Script: Latin, Greek, Common")
    check(unicode.Script(0x0378) == "Unknown", "Script: unassigned is Unknown")
    check(unicode.ScriptName("Grek") == "Greek" && unicode.ScriptName("Greek") == "Greek" && unicode.ScriptName("Nope") == nil, "ScriptName: short and long")
    let scx = unicode.ScriptExtensions(0x3099)
    check(scx.contains("Hiragana") && scx.contains("Katakana"), "ScriptExtensions: U+3099 is Hiragana and Katakana")
    check(unicode.ScriptExtensions(0x41) == ["Latin"], "ScriptExtensions: default is the Script")
    let greek = unicode.ScriptRanges("Greek")
    check(greek.Contains(0x3B1) && !greek.Contains(0x41), "ScriptRanges: Greek")
    let greekX = unicode.ScriptRanges("Greek", extensions: true)
    check(greekX.Contains(0x0342) && greekX.Contains(0x3B1), "ScriptRanges: Greek with extensions")
    if let lu = unicode.CategoryRanges("Lu"), let l = unicode.CategoryRanges("L") {
        check(lu.Contains(0x41) && !lu.Contains(0x61) && l.Contains(0x61), "CategoryRanges: Lu and L")
    } else {
        check(false, "CategoryRanges: Lu and L")
    }

    // Case.
    check(unicode.ToUpper(0x61) == 0x41 && unicode.ToLower(0x41) == 0x61, "ToUpper, ToLower ASCII")
    check(unicode.ToUpper(0x3B1) == 0x391 && unicode.ToLower(0x391) == 0x3B1, "ToUpper, ToLower Greek")
    check(unicode.ToUpper(0xDF) == 0xDF, "ToUpper: ß has no simple uppercase")
    check(unicode.ToTitle(0x1C6) == 0x1C5, "ToTitle: ǆ → ǅ")
    check(same(unicode.UppercaseMapping(0xDF), [0x53, 0x53]), "UppercaseMapping: ß → SS")
    check(same(unicode.LowercaseMapping(0x130), [0x69, 0x307]), "LowercaseMapping: İ → i̇")
    check(same(unicode.TitlecaseMapping(0xFB01), [0x46, 0x69]), "TitlecaseMapping: ﬁ → Fi")
    check(unicode.CaseFold(0x41) == 0x61 && unicode.CaseFold(0x3C2) == 0x3C3 && unicode.CaseFold(0x1E9E) == 0xDF, "CaseFold: A, ς, ẞ")
    check(same(unicode.CaseFoldMapping(0xDF), [0x73, 0x73]), "CaseFoldMapping: ß → ss")
    check(unicode.LowercasedString("ΟΔΟΣ ΣΑΣ") == "οδος σας", "LowercasedString: Final_Sigma")
    check(unicode.LowercasedString("Σ") == "σ", "LowercasedString: a lone Σ is not final")
    check(unicode.UppercasedString("straße") == "STRASSE", "UppercasedString: ß")
    check(unicode.CaseFoldedString("Straße") == "strasse", "CaseFoldedString")
    check(unicode.EqualFold("Hello ΣΑΣ", "hELLO σας") && !unicode.EqualFold("a", "b"), "EqualFold")

    // utf8.
    var b: [uint8] = []
    utf8.Append(&b, 0x24)
    utf8.Append(&b, 0xA2)
    utf8.Append(&b, 0x20AC)
    utf8.Append(&b, 0x10348)
    check(b == [0x24, 0xC2, 0xA2, 0xE2, 0x82, 0xAC, 0xF0, 0x90, 0x8D, 0x88], "utf8: Append of 1 to 4 bytes")
    check(utf8.Width(0x7F) == 1 && utf8.Width(0x7FF) == 2 && utf8.Width(0xFFFF) == 3 && utf8.Width(0x10000) == 4, "utf8: Width")
    check(same(utf8.DecodeCodePoints(b), [0x24, 0xA2, 0x20AC, 0x10348]), "utf8: Decode")
    let bad: [uint8] = [0x61, 0xC0, 0xAF, 0xED, 0xA0, 0x80, 0x62]
    check(!utf8.IsValid(bad) && utf8.IsValid(b), "utf8: IsValid rejects overlongs and surrogates")
    check(same(utf8.DecodeCodePoints(bad), [0x61, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0x62]), "utf8: Decode replaces each bad byte")
    check(utf8.Decode(b, 1, 6) == "¢€", "utf8: Decode of a span")
    check(utf8.Decode(bad, 0, 3) == "a\u{FFFD}\u{FFFD}", "utf8: Decode of malformed bytes is lossy")
    var s: [uint8] = []
    utf8.Append(&s, 0xD800)
    check(s == [0xEF, 0xBF, 0xBD], "utf8: Append of a surrogate writes U+FFFD")

    // utf16.
    let u = utf16.Encode("aé😀")
    check(u == [0x61, 0xE9, 0xD83D, 0xDE00], "utf16: Encode splits U+1F600")
    check(utf16.Decode(u) == "aé😀", "utf16: Decode round-trips")
    let (h, l) = utf16.Surrogates(0x10437)
    check(h == 0xD801 && l == 0xDC37 && utf16.Combine(h, l) == 0x10437, "utf16: Surrogates and Combine")
    check(utf16.Combine(0xD801, 0x41) == 0xFFFD, "utf16: Combine of a non-pair")
    let lone: [uint16] = [0x61, 0xD800, 0x62]
    check(same(utf16.CodePoints(lone), [0x61, 0xD800, 0x62]), "utf16: CodePoints keeps a lone surrogate")
    check(utf16.Decode(lone) == "a\u{FFFD}b", "utf16: Decode replaces a lone surrogate")
    check(utf16.FromCodePoints([0x41, 0x1F600]).count == 3 && utf16.Width(0x1F600) == 2, "utf16: FromCodePoints, Width")
    let (cp, w) = utf16.DecodeAt(u, 2)
    check(cp == 0x1F600 && w == 2, "utf16: DecodeAt reads a pair")

    if failures > 0 {
        print("\(failures) failed")
        return 1
    }
    print("all passed")
    return 0
}
