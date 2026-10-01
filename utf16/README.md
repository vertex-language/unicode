# unicode/utf16

Encodes and decodes UTF-16, the encoding of JavaScript, Java, Windows and JSON's \u escapes. UTF-16 in the wild may hold unpaired surrogates.

```vertex
import "unicode/utf16"
```

## Functions

- `func IsHighSurrogate(_ u: uint16) -> bool`: IsHighSurrogate: U+D800...U+DBFF, the first unit of a pair.
- `func IsLowSurrogate(_ u: uint16) -> bool`: IsLowSurrogate: U+DC00...U+DFFF, the second unit of a pair.
- `func Combine(_ high: uint16, _ low: uint16) -> uint32`: Combine joins a surrogate pair into its code point; units that aren't a pair give U+FFFD.
- `func Surrogates(_ cp: uint32) -> (high: uint16, low: uint16)`: Surrogates splits a code point above U+FFFF into its pair.
- `func Width(_ cp: uint32) -> int`: Width is how many units a code point takes: 1, or 2 above U+FFFF.
- `func Append(_ out: inout [uint16], _ cp: uint32)`: Append appends a code point's units. A surrogate code point is appended as itself; one past U+10FFFF as U+FFFD.
- `func FromCodePoints(_ cps: [uint32]) -> [uint16]`: FromCodePoints is the encoding of a sequence of code points.
- `func DecodeAt(_ u: [uint16], _ i: int) -> (codePoint: uint32, width: int)`: DecodeAt reads the code point at u[i]: a pair is joined, anything else (a lone surrogate too) is its own unit.
- `func CodePoints(_ u: [uint16]) -> [uint32]`: CodePoints reads all of u's code points, keeping lone surrogates.
- `func Encode(_ s: string) -> [uint16]`: Encode is a string's UTF-16 encoding.
- and 3 more

Part of the [`unicode`](https://github.com/vertex-language/unicode) repository.
