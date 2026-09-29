// Checks unicode/norm against every line of ucd/NormalizationTest.txt,
// the conformance test UAX #15 publishes: for each c1;c2;c3;c4;c5,
//
//     c2 == NFC(c1) == NFC(c2) == NFC(c3),  c4 == NFC(c4) == NFC(c5)
//     c3 == NFD(c1) == NFD(c2) == NFD(c3),  c5 == NFD(c4) == NFD(c5)
//     c4 == NFKC(c1..c5),                   c5 == NFKD(c1..c5)
//
// and every code point not listed in part 1 is unchanged by all four.
//
//     vsc run test-norm
package main

import (
    "fs"
    "unicode/norm"
)

func parse(_ field: string) -> [uint32] {
    var out: [uint32] = []
    for part in field.split(separator: " ", omittingEmptySubsequences: true) {
        var v: uint32 = 0
        for c in string(part).utf8 {
            var d: uint32 = 0
            if c >= 48 && c <= 57 { d = uint32(c - 48) } else { d = uint32(c - 55) }
            v = v * 16 + d
        }
        out.append(v)
    }
    return out
}

func main() -> int32 {
    guard let text = try? fs.ReadText(fs.Path("ucd/NormalizationTest.txt")) else {
        print("test-norm: run from the repository root")
        return 1
    }
    var lines = 0
    var failures = 0
    var part1: [bool] = [bool](repeating: false, count: 0x110000)
    var inPart1 = false
    for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
        let line = string(raw)
        if line.hasPrefix("#") { continue }
        if line.hasPrefix("@") {
            inPart1 = line.hasPrefix("@Part1")
            continue
        }
        let cols = line.split(separator: ";", omittingEmptySubsequences: false)
        if cols.count < 5 { continue }
        var c: [[uint32]] = []
        var k = 0
        while k < 5 { c.append(parse(string(cols[k]))); k += 1 }
        if inPart1 { part1[int(c[0][0])] = true }
        lines += 1
        var ok = true
        for i in [0, 1, 2] {
            if norm.Normalize(c[i], .nfc) != c[1] { ok = false }
            if norm.Normalize(c[i], .nfd) != c[2] { ok = false }
        }
        for i in [3, 4] {
            if norm.Normalize(c[i], .nfc) != c[3] { ok = false }
            if norm.Normalize(c[i], .nfd) != c[4] { ok = false }
        }
        for i in [0, 1, 2, 3, 4] {
            if norm.Normalize(c[i], .nfkc) != c[3] { ok = false }
            if norm.Normalize(c[i], .nfkd) != c[4] { ok = false }
        }
        if !ok {
            failures += 1
            if failures <= 10 { print("FAIL  \(line)") }
        }
    }
    var singles = 0
    var cp: uint32 = 0
    while cp < 0x110000 {
        if !part1[int(cp)] && !(cp >= 0xD800 && cp <= 0xDFFF) {
            let x: [uint32] = [cp]
            if norm.Normalize(x, .nfc) != x || norm.Normalize(x, .nfd) != x || norm.Normalize(x, .nfkc) != x || norm.Normalize(x, .nfkd) != x {
                failures += 1
                if failures <= 10 { print("FAIL  U+\(cp) should be unchanged") }
            }
            singles += 1
        }
        cp += 1
    }
    print("\(lines) test lines and \(singles) unlisted code points: \(failures) failures")
    return failures == 0 ? 0 : 1
}
