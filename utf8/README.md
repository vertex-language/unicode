# unicode/utf8

Encodes and decodes UTF-8 (RFC 3629), the encoding of Vertex's strings. Decoding is lossy: malformed input, a surrogate or an overlong form reads as U+FFFD, one byte wide, so a decoder always moves forward.

```vertex
import "unicode/utf8"
```

## Functions

- `func Width(_ cp: uint32) -> int`: Width is how many bytes a code point takes: 1 to 4. A surrogate or a value past U+10FFFF takes 3, the width of U+FFFD, which is written in its place.
- `func Append(_ out: inout [uint8], _ cp: uint32)`: Append appends a code point's encoding. A surrogate or a value past U+10FFFF, which UTF-8 can't carry, appends U+FFFD.
- `func Encode(_ cps: [uint32]) -> [uint8]`: Encode is the encoding of a sequence of code points.
- `func FromCodePoints(_ cps: [uint32]) -> string`: FromCodePoints is a string of code points.
- `func DecodeAt(_ b: [uint8], _ i: int) -> (codePoint: uint32, width: int)`: DecodeAt reads the code point whose encoding starts at b[i], and how many bytes it took.
- `func CodePoints(_ s: string) -> [uint32]`: CodePoints are a string's code points.
- `func DecodeCodePoints(_ b: [uint8]) -> [uint32]`: DecodeCodePoints reads all of b's code points.
- `func IsValid(_ b: [uint8], _ from: int = 0, _ to: int = -1) -> bool`: IsValid says whether b[from..<to] is well-formed UTF-8.
- `func Decode(_ b: [uint8], _ from: int = 0, _ to: int = -1) -> string`: Decode is the string b[from..<to] spells, made without first copying the span into an array of its own.

Part of the [`unicode`](https://github.com/vertex-language/unicode) repository.
