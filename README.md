# unicode

[![package: vs-package](https://img.shields.io/badge/package-vs--package-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language)
[![unicode: 17.0](https://img.shields.io/badge/unicode-17.0-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://www.unicode.org/versions/Unicode17.0.0/)
[![encodings: utf8 | utf16](https://img.shields.io/badge/encodings-utf8%20%7C%20utf16-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language/unicode)

The Unicode Character Database's properties of code points, and the UTF-8
and UTF-16 encodings, in pure Vertex. The tables are generated from the
UCD's own files, checked in under `ucd/`, so every answer can be traced to
the line it came from.

---

## Packages

| Package | What it is |
| :--- | :--- |
| **`unicode`** | Code point properties: `Category` (General_Category, with `IsLetter`, `IsNumber`, `IsDigit`, `IsMark`, `IsPunctuation`, `IsSymbol`, `IsSeparator`, `IsControl`), the binary properties (`IsWhitespace`, `IsAlphabetic`, `IsUppercase`, `IsLowercase`, `IsCased`, `IsIDStart`, `IsIDContinue`, and all 70 by any name through `Property`), scripts (`Script`, `ScriptExtensions`, `ScriptRanges`), and case: simple (`ToUpper`, `ToLower`, `ToTitle`, `CaseFold`), full (`UppercaseMapping`, `LowercaseMapping`, `TitlecaseMapping`, `CaseFoldMapping`), and over text (`Uppercased`, `Lowercased` with Final_Sigma, `CaseFolded`, `EqualFold`). |
| **`unicode/norm`** | Normalization (UAX #15): `Normalize(cps, .nfc)` for NFC, NFD, NFKC and NFKD, `NormalizeString`, `IsNormalized`, and the parts: `Decompose`, `Compose`, `CombiningClass`. |
| **`unicode/utf8`** | UTF-8: `Append`, `Width`, `DecodeAt`, `Decode` (bytes to a string, lossily), `Encode`, `CodePoints`, `IsValid`. |
| **`unicode/utf16`** | UTF-16: `Encode` (a string to units), `Decode` (units to a string), `CodePoints` (keeping lone surrogates), `FromCodePoints`, `Append`, `Width`, `DecodeAt`, `Combine`, `Surrogates`, `IsHighSurrogate`, `IsLowSurrogate`. |

A code point is a `uint32`. Malformed input never stops a decoder: it
reads as U+FFFD (`unicode.ReplacementCharacter`), and a decoder always
moves forward.

---

## Quick Start

```vertex
import (
    "unicode"
    "unicode/norm"
    "unicode/utf8"
    "unicode/utf16"
)

unicode.Category(0x3B1)                 // .lowercaseLetter (α)
unicode.IsIDStart(0x2118)               // true: ℘ is Other_ID_Start
unicode.Script(0x5D0)                   // "Hebrew"
unicode.UppercasedString("straße")      // "STRASSE"
unicode.LowercasedString("ΟΔΟΣ")        // "οδος": the final Σ becomes ς
unicode.Property("Extended_Pictographic")!.Contains(0x1F600)   // true
norm.NormalizeString("e\u{301}", .nfc)  // "é" as one code point

let units = utf16.Encode("a😀")         // [0x61, 0xD83D, 0xDE00]
let text = utf16.Decode(units)          // "a😀"
var bytes: [uint8] = []
utf8.Append(&bytes, 0x20AC)             // [0xE2, 0x82, 0xAC]
utf8.Decode(bytes)                      // "€"
```

---

## The tables

`cmd/gen` reads the UCD files in `ucd/` and writes `tables.vs`: General_Category
and Script as runs, the binary properties as sorted ranges, the case mappings
and foldings as sorted pairs. It writes `norm/tables.vs` too: the combining
classes, both kinds of decomposition, and the primary composites (Hangul is
arithmetic, in code). Lookups are binary searches, with ASCII answered
without one.

| File | Gives |
| :--- | :--- |
| `UnicodeData.txt` | General_Category; the simple case mappings; combining classes and decompositions |
| `SpecialCasing.txt` | the full case mappings (the unconditional ones; Final_Sigma is in code) |
| `CaseFolding.txt` | simple and full case folding |
| `PropList.txt`, `DerivedCoreProperties.txt`, `DerivedBinaryProperties.txt`, `DerivedNormalizationProps.txt`, `emoji-data.txt` | the binary properties; Full_Composition_Exclusion |
| `NormalizationTest.txt` | not read by `gen`: the conformance test `test-norm` runs |
| `Scripts.txt`, `ScriptExtensions.txt` | Script and Script_Extensions |
| `PropertyAliases.txt`, `PropertyValueAliases.txt` | the other names of properties, categories and scripts |

To move to a new Unicode version, replace the files in `ucd/` with that
version's from `https://www.unicode.org/Public/<version>/ucd/`, set `version`
in `cmd/gen`, and run it:

```bash
vsc run gen
vsc run check
```

---

## Testing

```bash
vsc run check
vsc run test-norm
```

`check` checks each kind of answer against facts from the UCD files: categories
inside First/Last ranges, Other_ID_Start, Final_Sigma, ß's full mappings,
script extensions, overlong and surrogate UTF-8, and lone UTF-16 surrogates.
`test-norm` runs all of UAX #15's conformance test, `NormalizationTest.txt`:
every line in all four forms, and every code point it doesn't list, which
must come back unchanged.

---

## License

[MIT](LICENSE). The files in `ucd/` are the Unicode Consortium's, under the
[Unicode License v3](https://www.unicode.org/license.txt).
