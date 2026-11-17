//
//  SwiftTaggedPointer.swift
//
//
//  Created by Joseph Hinkle on 10/25/23.
//
// This file can be used by itself or you can use the Swift Package.
//
// Storage is always a 64 bit unsigned integer, regardless of the platform's
// native word size. On 32 bit platforms (including WebAssembly) a valid
// pointer value fits in the low 32 bits, so it occupies the low end of the
// pointer-guts field while the upper guts bits stay 0. All bit manipulation
// uses logical integer shifts and masks, so the layout does not depend on
// the platform's endianness.
//
// We assume that:
//  1. The provided pointers are 8 byte aligned (note: on 32 bit targets `Int`
//     is only 4 byte aligned, so prefer 8 byte aligned pointees such as `UInt64`)
//  2. The program is running in user space (not kernel space)
//  3. The OS is not using the top 16 bits of pointers (which is true for all current OSes)
//
// The result is the following layout:
//  1. The top 17 bits hold custom data (a 16 bit magnitude plus a sign bit)
//  2. The next 44 bits hold all the significant bits of the pointer
//  3. The bottom 3 bits hold the tag
//
// The layout visualized:
//                 Raw storage:  |-----------------------------64 bits----------------------------|
//             Pointer anatomy:  |--16 bits--|------1 bit-----|---- 44 bits ---|------3 bits------|
//                               |unused bits|is kernel space?|the pointer guts|alignment artifact|
//                               |   all 0s  |       0        |      ???       |      all 0s      |
//                 Raw storage:  |-----------------------------64 bits----------------------------|
//  Simplified Pointer anatomy:  |-----17 bits-----|--------------44 bits--------------|--3 bits--|
//                               |     all 0s      |    significant bits of pointer    |  all 0s  |
//                               |----------------------------------------------------------------|
//
// Some explanation:
//  The top 16 bits are always 0 because the OS assumes that memory never goes above what a 48 bit pointer
//  can address (48 bits gives you 256 TB of memory). The kernel space flag is 1 when the pointer is in kernel
//  space and 0 when the pointer is in user space. We assume that the program is running in user space. The
//  bottom 3 bits are always 0 because the pointers are 8 byte aligned, i.e. the first address would be 0x0,
//  then 0x8, then 0x10, etc. If you convert the pointer hex value to binary, you will see that the bottom 3
//  bits are always 0.
//
//  On 32 bit platforms the pointer value never reaches above bit 31, so the same masks work unchanged: the
//  pointer occupies the low end of the guts field and the remaining guts bits (32-46) stay 0.
//

/// A pointer that stores a 3 bit tag and a 17 bit integer within a pointer.
/// You can either use the tag as a 3 bit integer (represented as UInt8 `tagAsUInt8`) or as 3 individual bits (`bitTag0`, `bitTag1`, `bitTag2`).
/// You can either use the data as a 17 bit signed integer (`data17`) or as a 16 bit unsigned integer (`dataUInt16`).
/// You can also directly access the sign bit of the data (`signBit`).
/// ```
/// Memory layout visualized:
///            Raw storage:  |-----------------------------64 bits----------------------------|
///  TaggedPointer anatomy:  |-------17 bits-------|------44 bits-------|--------3 bits-------|
///                          | custom 17 bit data  |    pointer data    |  custom 3 bit tag   |
///                          |                     |      `pointer`     |                     |
///                          |----------------------------------------------------------------|
///
///                          |-----------------------------64 bits----------------------------|
///                          |--------61 bits-------|-----------------3 bits------------------|
///                          |                      |               `tagUInt3`                |
///                          |                      |----1 bit----|----1 bit----|----1 bit----|
///                          |                      |   `bitTag2` |  `bitTag1`  |  `bitTag0`  |
///                          |----------------------------------------------------------------|
///
///                          |-----------------------------64 bits----------------------------|
///                          |------------17 bits----------|--------------47 bits-------------|
///                          |          `dataInt17`        |                                  |
///                          |-----16 bits-----|---1 bit---|                                  |
///                          |   magnitude     | `signBit` |                                  |
///                          |----------------------------------------------------------------|
///
///                          |-----------------------------64 bits----------------------------|
///                          |-----16 bits-----|---------------------48 bits------------------|
///                          |   `dataUInt16`  |                                              |
///                          |   `dataInt16`   |                                              |
///                          |----------------------------------------------------------------|
/// ```
public struct TaggedPointer<P: TaggablePointer>: Equatable, Sendable {

    #if !DEBUG
    @usableFromInline
    @_alwaysEmitIntoClient
    #endif
    internal var _storage: UInt64

    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public static func rawStorage(of taggedPointer: Self) -> UInt64 {
        return taggedPointer._storage
    }

    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public init(_ pointer: consuming P?) {
        assert(MemoryLayout<Self>.size == MemoryLayout<UInt64>.size)
        self._storage = 0
        self.pointer = pointer
    }

    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public var pointer: P? {
        borrowing _read {
            assert(MemoryLayout<Self>.size == MemoryLayout<UInt64>.size)
            // Make pointer canonical by keeping only the 44 guts bits
            yield P(bitPattern: _storage & canonicalPointerGutsMask)
        }
        mutating _modify {
            assert(MemoryLayout<Self>.size == MemoryLayout<UInt64>.size)
            var pointer: P? = P(bitPattern: _storage & canonicalPointerGutsMask)
            yield &pointer
            let bits = UInt64(bitPatternFromTaggablePointer: pointer)
            assert(bits & canonicalPointerGutsMaskNegated == 0, "Invalid pointer guts: pointers must be 8 byte aligned user-space addresses")
            // Clear pointer guts
            _storage &= canonicalPointerGutsMaskNegated
            // Set pointer guts
            _storage |= bits
        }
    }

    /// The 3 bit tag
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public var tagUInt3: UInt8 {
        get {
            return UInt8(_storage & bottom3BitsMask)
        }
        set {
            assert(UInt64(newValue) & bottom3BitsMaskNegated == 0)
            // Clear tag
            _storage &= bottom3BitsMaskNegated
            // Set tag
            _storage |= UInt64(newValue)
        }
    }

    /// The first bottom bit of the tag
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public var bitTag0: Bool {
        get {
            return _storage & 0b1 != 0
        }
        set {
            if newValue {
                _storage |= 0b1
            } else {
                _storage &= ~0b1
            }
        }
    }

    /// The second to bottom bit of the tag
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public var bitTag1: Bool {
        get {
            return _storage & 0b10 != 0
        }
        set {
            if newValue {
                _storage |= 0b10
            } else {
                _storage &= ~0b10
            }
        }
    }

    /// The third bottom bit of the tag
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public var bitTag2: Bool {
        get {
            return _storage & 0b100 != 0
        }
        set {
            if newValue {
                _storage |= 0b100
            } else {
                _storage &= ~0b100
            }
        }
    }

    /// The 16 bit unsigned integer
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public var dataUInt16: UInt16 {
        get {
            return UInt16(truncatingIfNeeded: _storage >> 48)
        }
        set {
            // Clear data
            _storage &= top16BitsMaskNegated
            // Set data
            _storage |= UInt64(newValue) << 48
        }
    }

    /// The sign bit (which corresponds to `dataInt17`).
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public var signBit: Bool {
        get {
            return _storage & signBitMask != 0
        }
        set {
            if newValue {
                _storage |= signBitMask
            } else {
                _storage &= signBitMaskNegated
            }
        }
    }

    /// The 17 bit signed integer. The magnitude of this integer is stored in `dataUInt16`.
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public var dataInt17: Int32 {
        get {
            return self.signBit ? -Int32(dataUInt16) - 1 : Int32(dataUInt16)
        }
        set {
            assert(newValue >= -65536 && newValue <= 65535)
            // Clear data
            _storage &= top17BitsMaskNegated
            if newValue < 0 {
                // Set sign bit
                _storage |= signBitMask
                // Set magnitude
                _storage |= UInt64(-newValue - 1) << 48
            } else {
                // Set magnitude
                _storage |= UInt64(newValue) << 48
            }
        }
    }
}

// Constants
@_alwaysEmitIntoClient
private let canonicalPointerGutsMask: UInt64 = 0b0000000000000000011111111111111111111111111111111111111111111000
@_alwaysEmitIntoClient
private let canonicalPointerGutsMaskNegated: UInt64 = ~canonicalPointerGutsMask
@_alwaysEmitIntoClient
private let bottom3BitsMask: UInt64 = 0b111
@_alwaysEmitIntoClient
private let bottom3BitsMaskNegated: UInt64 = ~bottom3BitsMask
@_alwaysEmitIntoClient
private let top17BitsMask: UInt64 = 0b1111111111111111100000000000000000000000000000000000000000000000
@_alwaysEmitIntoClient
private let top17BitsMaskNegated: UInt64 = ~top17BitsMask
@_alwaysEmitIntoClient
private let top16BitsMask: UInt64 = 0b1111111111111111000000000000000000000000000000000000000000000000
@_alwaysEmitIntoClient
private let top16BitsMaskNegated: UInt64 = ~top16BitsMask
@_alwaysEmitIntoClient
private let signBitMask: UInt64 = 0b100000000000000000000000000000000000000000000000
@_alwaysEmitIntoClient
private let signBitMaskNegated: UInt64 = ~signBitMask


/// A pointer that can be stored in a `TaggedPointer`.
///
/// The bit pattern is expressed as a `UInt64` so the same conformance works on
/// 32 bit and 64 bit platforms: 32 bit addresses zero-extend into the low
/// end of the value.
public protocol TaggablePointer {
    init?(bitPattern: UInt64)
    var bitPatternAsUInt64: UInt64 { borrowing get }
}

extension UnsafePointer: TaggablePointer {
    public init?(bitPattern value: UInt64) {
        self.init(bitPattern: Int(bitPattern: UInt(truncatingIfNeeded: value)))
    }
    public var bitPatternAsUInt64: UInt64 {
        UInt64(UInt(bitPattern: Int(bitPattern: self)))
    }
}

extension UnsafeMutablePointer: TaggablePointer {
    public init?(bitPattern value: UInt64) {
        self.init(bitPattern: Int(bitPattern: UInt(truncatingIfNeeded: value)))
    }
    public var bitPatternAsUInt64: UInt64 {
        UInt64(UInt(bitPattern: Int(bitPattern: self)))
    }
}

extension UnsafeRawPointer: TaggablePointer {
    public init?(bitPattern value: UInt64) {
        self.init(bitPattern: Int(bitPattern: UInt(truncatingIfNeeded: value)))
    }
    public var bitPatternAsUInt64: UInt64 {
        UInt64(UInt(bitPattern: Int(bitPattern: self)))
    }
}

extension UnsafeMutableRawPointer: TaggablePointer {
    public init?(bitPattern value: UInt64) {
        self.init(bitPattern: Int(bitPattern: UInt(truncatingIfNeeded: value)))
    }
    public var bitPatternAsUInt64: UInt64 {
        UInt64(UInt(bitPattern: Int(bitPattern: self)))
    }
}

extension OpaquePointer: TaggablePointer {
    public init?(bitPattern value: UInt64) {
        self.init(bitPattern: Int(bitPattern: UInt(truncatingIfNeeded: value)))
    }
    public var bitPatternAsUInt64: UInt64 {
        UInt64(UInt(bitPattern: Int(bitPattern: self)))
    }
}

extension UInt64 {
    public init<P: TaggablePointer>(bitPatternFromTaggablePointer pointer: P?) {
        switch pointer {
        case .none:
            self = 0
        case .some(let pointer):
            self = pointer.bitPatternAsUInt64
        }
    }
}
