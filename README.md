# Swift Tagged Pointer

[Tagged pointers](https://en.wikipedia.org/wiki/Tagged_pointer) in Swift!

Storage is always a 64 bit unsigned integer, so this works on any platform.

### Pointers on 64-bit Systems like iOS and MacOS only need 44 bits!

This means we have an extra 20 bits to play with! With this library, you can make that easy with the Swift type `TaggedPointer<>`.

On 32-bit systems (including WebAssembly), the whole address fits in the low 32 bits of that same 64 bit storage, so the exact same layout keeps working — with even more spare bits.

### Usage

```swift
let x: UInt64 = 5
withUnsafePointer(to: x) { p in
    var tp = TaggedPointer(p)
    tp.bitTag0 = true
    tp.bitTag1 = true
    tp.bitTag2 = true
    tp.dataInt17 = 23
    assert(tp.pointer == p)
}
```

Note: the pointed-to address must be 8 byte aligned. On 32-bit targets a plain `Int` is only 4 byte aligned, so prefer 8 byte aligned pointees such as `UInt64` or `Double`.

You can also see the [checks](https://github.com/joehinkle11/SwiftTaggedPointer/blob/main/Sources/TaggedPointerChecks/TaggedPointerChecks.swift) as an example.

### Pointer Layout

Here's how a pointer layed out in memory.
```
               Raw storage:  |-----------------------------64 bits----------------------------|
           Pointer anatomy:  |--16 bits--|------1 bit-----|---- 44 bits ---|------3 bits------|
                             |unused bits|is kernel space?|the pointer guts|alignment artifact|
                             |   all 0s  |       0        |      ???       |      all 0s      |
               Raw storage:  |-----------------------------64 bits----------------------------|
Simplified Pointer anatomy:  |-----17 bits-----|--------------44 bits--------------|--3 bits--|
                             |     all 0s      |    significant bits of pointer    |  all 0s  |
                             |----------------------------------------------------------------|
```
The top 16 bits are always 0 because the OS assumes that memory never goes above what a 48 bit pointer can address (48 bits gives you 256 TB of memory). The kernel space flag is 1 when the pointer is in kernel space and 0 when the pointer is in user space. We assume that the program is running in user space. The bottom 3 bits are always 0 because the pointers are 8 byte aligned, i.e. the first address would be 0x0, then 0x8, then 0x10, etc. If you convert the pointer hex value to binary, you will see that the bottom 3 bits are always 0.

On 32-bit platforms the address never reaches above bit 31, so it simply occupies the low end of the pointer-guts field while the upper guts bits stay 0. No separate layout is needed.

###  `TaggedPointer<>` Layout

`TaggedPointer<>` exploits the extra bits in a pointer to let you cram in your own data and bit flags.
```
          Raw storage:  |-----------------------------64 bits----------------------------|
TaggedPointer anatomy:  |-------17 bits-------|------44 bits-------|--------3 bits-------|
                        | custom 17 bit data  |    pointer data    |  custom 3 bit tag   |
                        |                     |      `pointer`     |                     |
                        |----------------------------------------------------------------|

                        |-----------------------------64 bits----------------------------|
                        |--------61 bits-------|-----------------3 bits------------------|
                        |                      |               `tagUInt3`                |
                        |                      |----1 bit----|----1 bit----|----1 bit----|
                        |                      |   `bitTag2` |  `bitTag1`  |  `bitTag0`  |
                        |----------------------------------------------------------------|

                        |-----------------------------64 bits----------------------------|
                        |------------17 bits----------|--------------47 bits-------------|
                        |          `dataInt17`        |                                  |
                        |-----16 bits-----|---1 bit---|                                  |
                        |   magnitude     | `signBit` |                                  |
                        |----------------------------------------------------------------|

                        |-----------------------------64 bits----------------------------|
                        |-----16 bits-----|---------------------48 bits------------------|
                        |   `dataUInt16`  |                                              |
                        |   `dataInt16`   |                                              |
                        |----------------------------------------------------------------|
```
You can either use the tag as a 3 bit integer (represented as UInt8 `tagAsUInt8`) or as 3 individual bits (`bitTag0`, `bitTag1`, `bitTag2`). You can either use the data as a 17 bit signed integer (`data17`) or as a 16 bit unsigned integer (`dataUInt16`). You can also directly access the sign bit of the data (`signBit`).

### Portability

- The backing storage is `UInt64` on every platform, and all bit manipulation uses logical integer shifts and masks, so the layout does not depend on the platform's word size or endianness.
- What is still assumed: 8 byte aligned addresses, user-space addresses, and an OS that leaves the top 16 pointer bits unused.
- On platforms without native 64-bit registers (32-bit, WebAssembly), the 64-bit operations compile to multi-instruction sequences, so tagging costs a little more there. It still works.
- Breaking changes from the `Int`-based version: `TaggablePointer` now uses `UInt64` bit patterns, and `TaggedPointer.rawStorage(of:)` returns `UInt64`.

### Checks

There is no test target: test targets are not supported in Embedded Swift, so the checks live in the `TaggedPointerChecks` executable target and run everywhere, including `wasm-embedded`.

Run everything locally with:

```sh
./Scripts/check-all.sh
```

This runs the checks on the host, on `wasm`, and on `wasm-embedded`. It needs a Swift 6.4 toolchain with the matching Wasm SDKs installed (see the [WebAssembly getting-started guide](https://www.swift.org/documentation/articles/wasm-getting-started.html)) plus `wasmtime` on `PATH` to execute the wasm binaries; override the SDK IDs with `WASM_SDK` / `WASM_EMBEDDED_SDK` if yours differ.

Note: the `wasm-embedded` run prints benign "data race detected" runtime warnings for every `withUnsafePointer` scope. That is an artifact of the Embedded Swift SDK, not a failure — the script only requires a zero exit code plus the `PASS` marker.

### Install

You can simply copy the implementation (it's one file) [here](https://github.com/joehinkle11/SwiftTaggedPointer/blob/main/Sources/SwiftTaggedPointer/SwiftTaggedPointer.swift), or you can add it as a Swift Package.

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "MyPackage",
  dependencies: [
    .package(
      url: "https://github.com/joehinkle11/SwiftTaggedPointer.git", 
      .upToNextMajor(from: "2.0.0") // or `.upToNextMinor
    )
  ],
  targets: [
    .target(
      name: "MyTarget",
      dependencies: [
        .product(name: "SwiftTaggedPointer", package: "SwiftTaggedPointer")
      ]
    )
  ]
)
```
