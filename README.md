# Swift Tagged Pointer

[Tagged pointers](https://en.wikipedia.org/wiki/Tagged_pointer) in Swift!

### Pointers on 64-bit Systems like iOS and MacOS only need 44 bits!

This means we have an extra 20 bits to play with! With this library, you can make that easy with the Swift type `TaggedPointer<>`.

### Usage

```swift
let x = 5
withUnsafePointer(to: x) { p in
    var tp = TaggedPointer(p)
    tp.bitTag0 = true
    tp.bitTag1 = true
    tp.bitTag2 = true
    tp.dataInt17 = 23
    assert(tp.pointer == p)
}
```

You can also see the [tests](https://github.com/joehinkle11/SwiftTaggedPointer/blob/main/Tests/SwiftTaggedPointerTests/SwiftTaggedPointerTests.swift) as an example.

### Pointer Layout

Here's how a pointer looks layed out in memory.
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
      .upToNextMajor(from: "1.0.0") // or `.upToNextMinor
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
