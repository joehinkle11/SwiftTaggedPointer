//
//  SwiftTaggedPointer.swift
//
//
//  Created by Joseph Hinkle on 10/25/23.
//
// This file can be used by itself or you can use the Swift Package.
//
// We assume that:
//  1. The provided pointers are 8 byte aligned
//  2. The program is running in user space (not kernel space)
//  3. The program is running on a 64 bit system
//  4. The program is running on a little endian system
//  5. The OS is not using the top 16 bits of pointers (which is true for all current OSes)
//
// The result is the following layout:
//  1. The top 17 bits are always 0
//  2. The next 44 bits are all the significant bits of the pointer
//  3. The bottom 3 bits are the tag
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

/// A pointer that stores a 3 bit tag and a 17 bit integer within a pointer.
/// You can either use the tag as a 3 bit integer (represented as UInt8 `tagAsUInt8`) or as 3 individual bits (`bitTag0`, `bitTag1`, `bitTag2`).
/// You can either use the data as a 17 bit signed integer (`data17`) or as a 16 bit unsigned integer (`dataUInt16`).
/// You can also directly access the sign bit of the data (`signBit`).
/// ```
/// Memory layout visualized:
///            Raw storage:  |-----------------------------64 bits----------------------------|
///  TaggedPointer anatomy:  |-------17 bits-------|------44 bits-------|--------3 bits-------|
///                          | custom 17 bit data  |    pointer data    |  custom 3 bit tag   |
///                          |                     |    `getPointer`    |                     | 
///                          |                     |    `setPointer`    |                     |
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
public struct TaggedPointer<P : _Pointer>: Equatable {
    
    #if !DEBUG
    @usableFromInline
    @_alwaysEmitIntoClient
    #endif
    internal var _storage: Int
    
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public init(_ pointer: P?) {
        assert(MemoryLayout<Self>.size == MemoryLayout<UInt64>.size)
        self._storage = 0
        self.setPointer(pointer)
    }
    
    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public func getPointer(_ type: P.Type = P.self) -> P? {
        assert(MemoryLayout<P>.size == MemoryLayout<UInt64>.size)
        assert(MemoryLayout<Self>.size == MemoryLayout<UInt64>.size)
        // Make pointer canonical by setting top 17 bits to 0 and bottom 3 bits to 0
        return P(bitPattern: _storage & canonicalPointerGutsMask)
    }

    #if !DEBUG
    @inline(__always)
    @inlinable
    @_alwaysEmitIntoClient
    #endif
    public mutating func setPointer(_ pointer: P?) {
        assert(MemoryLayout<P>.size == MemoryLayout<UInt64>.size)
        assert(Int(bitPattern: pointer) & canonicalPointerGutsMaskNegated == 0)
        // Clear pointer guts
        _storage &= canonicalPointerGutsMaskNegated
        // Set pointer guts
        _storage |= Int(bitPattern: pointer)
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
            assert(Int(newValue) & bottom3BitsMaskNegated == 0)
            // Clear tag
            _storage &= bottom3BitsMaskNegated
            // Set tag
            _storage |= Int(newValue)
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
            return UInt16(bitPattern: Int16(_storage >> 48))
        }
        set {
            assert(Int(bitPattern: UInt(newValue)) << 48 & top16BitsMaskNegated == 0)
            // Clear data
            _storage &= top16BitsMaskNegated
            // Set data
            _storage |= Int(bitPattern: UInt(newValue)) << 48
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
                assert(Int(bitPattern: UInt(-newValue - 1)) << 48 & top16BitsMaskNegated == 0)
                // Set sign bit
                _storage |= signBitMask
                // Set magnitude
                _storage |= Int(bitPattern: UInt(-newValue - 1)) << 48
            } else {
                assert(Int(bitPattern: UInt(newValue)) << 48 & top16BitsMaskNegated == 0)
                // Set magnitude
                _storage |= Int(bitPattern: UInt(newValue)) << 48
            }
        }
    }
}

extension TaggedPointer: Sendable where P: Sendable {}

// Constants
@_alwaysEmitIntoClient
private let canonicalPointerGutsMask: Int = Int(bitPattern: 0b0000000000000000011111111111111111111111111111111111111111111000 as UInt)
@_alwaysEmitIntoClient
private let canonicalPointerGutsMaskNegated: Int = ~canonicalPointerGutsMask
@_alwaysEmitIntoClient
private let bottom3BitsMask: Int = Int(bitPattern: 0b111 as UInt)
@_alwaysEmitIntoClient
private let bottom3BitsMaskNegated: Int = ~bottom3BitsMask
@_alwaysEmitIntoClient
private let top17BitsMask: Int = Int(bitPattern: 0b1111111111111111100000000000000000000000000000000000000000000000 as UInt)
@_alwaysEmitIntoClient
private let top17BitsMaskNegated: Int = ~top17BitsMask
@_alwaysEmitIntoClient
private let top16BitsMask: Int = Int(bitPattern: 0b1111111111111111000000000000000000000000000000000000000000000000 as UInt)
@_alwaysEmitIntoClient
private let top16BitsMaskNegated: Int = ~top16BitsMask
@_alwaysEmitIntoClient
private let signBitMask: Int = Int(bitPattern: 0b100000000000000000000000000000000000000000000000 as UInt)
@_alwaysEmitIntoClient
private let signBitMaskNegated: Int = ~signBitMask


// Compile time asserts
#if _endian(big)
#error("This code assumes little endian")
#endif



