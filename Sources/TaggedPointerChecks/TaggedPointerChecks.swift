import SwiftTaggedPointer

/// Portable checks for `TaggedPointer`.
///
/// This is a plain executable instead of a test target so the same checks run
/// under Embedded Swift (which does not support test targets): each check
/// prints a failure and the program traps at the end when any check failed.
private func check(_ condition: Bool, _ message: String, failures: inout Int) {
    if !condition {
        failures += 1
        print("FAIL: \(message)")
    }
}

private func checkEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, failures: inout Int) {
    if a != b {
        failures += 1
        print("FAIL: \(message)")
    }
}

@main
struct TaggedPointerChecks {
    static func main() {
        var failures = 0
        // UInt64 locals: 8 byte aligned on every supported target, which the
        // tagged-pointer layout requires. (On 32 bit targets a plain Int is
        // only 4 byte aligned, so its address may not be taggable.)
        let x: UInt64 = 5
        withUnsafePointer(to: x) { p in
            check(UInt64(bitPatternFromTaggablePointer: p) & 0b111 == 0, "test address p is 8-aligned", failures: &failures)
            let y: UInt64 = 5
            withUnsafePointer(to: y) { p2 in
                check(UInt64(bitPatternFromTaggablePointer: p2) & 0b111 == 0, "test address p2 is 8-aligned", failures: &failures)
                var tp = TaggedPointer(p)
                let tp2 = TaggedPointer(p2)
                check(tp != tp2, "distinct pointers give distinct tagged pointers", failures: &failures)
                check(p != p2, "test pointers are distinct", failures: &failures)
                check(tp.pointer != tp2.pointer, "distinct tagged pointers expose distinct pointers", failures: &failures)
                checkEqual(tp.pointer, p, "pointer round-trips", failures: &failures)
                checkEqual(tp.tagUInt3, 0, "initial tag is 0", failures: &failures)
                checkEqual(tp.bitTag0, false, "initial bitTag0 is false", failures: &failures)
                tp.bitTag0 = true
                checkEqual(tp.tagUInt3, 1, "bitTag0 sets tag to 1", failures: &failures)
                checkEqual(tp.bitTag0, true, "bitTag0 reads back true", failures: &failures)
                checkEqual(tp.pointer, p, "pointer preserved after bitTag0", failures: &failures)
                tp.bitTag0 = false
                checkEqual(tp.tagUInt3, 0, "bitTag0 clears tag to 0", failures: &failures)
                checkEqual(tp.bitTag0, false, "bitTag0 reads back false", failures: &failures)
                tp.bitTag1 = true
                checkEqual(tp.tagUInt3, 2, "bitTag1 sets tag to 2", failures: &failures)
                checkEqual(tp.bitTag1, true, "bitTag1 reads back true", failures: &failures)
                checkEqual(tp.bitTag0, false, "bitTag0 still false", failures: &failures)
                checkEqual(tp.bitTag2, false, "bitTag2 still false", failures: &failures)
                tp.bitTag2 = true
                checkEqual(tp.tagUInt3, 6, "combined tag reads 6", failures: &failures)
                checkEqual(tp.bitTag2, true, "bitTag2 reads back true", failures: &failures)
                tp.tagUInt3 = 1
                checkEqual(tp.tagUInt3, 1, "tag writes as integer", failures: &failures)
                checkEqual(tp.bitTag0, true, "tag bit 0 visible", failures: &failures)
                checkEqual(tp.bitTag1, false, "tag bit 1 visible", failures: &failures)
                checkEqual(tp.bitTag2, false, "tag bit 2 visible", failures: &failures)
                checkEqual(tp.dataUInt16, 0, "initial data is 0", failures: &failures)
                checkEqual(tp.signBit, false, "initial sign bit is false", failures: &failures)
                checkEqual(tp.pointer, p, "pointer preserved after tag writes", failures: &failures)
                tp.signBit = true
                checkEqual(tp.tagUInt3, 1, "tag preserved after signBit write", failures: &failures)
                checkEqual(tp.dataUInt16, 0, "magnitude preserved after signBit write", failures: &failures)
                checkEqual(tp.signBit, true, "signBit reads back true", failures: &failures)
                checkEqual(tp.pointer, p, "pointer preserved after signBit write", failures: &failures)
                tp.dataUInt16 = .max
                checkEqual(tp.dataUInt16, .max, "data stores max UInt16", failures: &failures)
                checkEqual(tp.signBit, true, "signBit preserved after data write", failures: &failures)
                checkEqual(tp.pointer, p, "pointer preserved after data write", failures: &failures)
                tp.dataUInt16 = 0
                checkEqual(tp.dataUInt16, 0, "data clears to 0", failures: &failures)
                checkEqual(tp.signBit, true, "signBit preserved after data clear", failures: &failures)
                checkEqual(tp.pointer, p, "pointer preserved after data clear", failures: &failures)
                tp.dataInt17 = 37
                checkEqual(tp.dataInt17, 37, "dataInt17 stores 37", failures: &failures)
                checkEqual(tp.dataUInt16, 37, "magnitude of 37", failures: &failures)
                checkEqual(tp.signBit, false, "sign of 37", failures: &failures)
                tp.signBit = true
                checkEqual(tp.tagUInt3, 1, "tag preserved after sign flip", failures: &failures)
                checkEqual(tp.dataInt17, -38, "sign flip maps 37 to -38", failures: &failures)
                checkEqual(tp.dataUInt16, 37, "magnitude preserved after sign flip", failures: &failures)
                checkEqual(tp.signBit, true, "sign reads back true", failures: &failures)
                tp.dataInt17 = 0
                checkEqual(tp.dataInt17, 0, "dataInt17 stores 0", failures: &failures)
                checkEqual(tp.dataUInt16, 0, "magnitude of 0", failures: &failures)
                checkEqual(tp.signBit, false, "sign of 0", failures: &failures)
                tp.signBit = true
                checkEqual(tp.tagUInt3, 1, "tag preserved", failures: &failures)
                checkEqual(tp.dataInt17, -1, "sign-only value reads as -1", failures: &failures)
                checkEqual(tp.dataUInt16, 0, "magnitude of -1 is 0", failures: &failures)
                checkEqual(tp.signBit, true, "sign reads back true", failures: &failures)
                tp.dataInt17 = -5
                checkEqual(tp.dataInt17, -5, "dataInt17 stores -5", failures: &failures)
                checkEqual(tp.dataUInt16, 4, "magnitude of -5 is 4", failures: &failures)
                checkEqual(tp.signBit, true, "sign of -5", failures: &failures)
                tp.signBit = false
                checkEqual(tp.tagUInt3, 1, "tag preserved", failures: &failures)
                checkEqual(tp.dataInt17, 4, "clearing sign maps -5 to 4", failures: &failures)
                checkEqual(tp.dataUInt16, 4, "magnitude preserved", failures: &failures)
                checkEqual(tp.signBit, false, "sign reads back false", failures: &failures)
                for value: Int32 in -65536...65535 {
                    tp.dataInt17 = value
                    check(tp.dataInt17 == value, "dataInt17 round-trips", failures: &failures)
                    check(
                        tp.dataUInt16 == (value < 0 ? UInt16(-(value + 1)) : UInt16(value)),
                        "magnitude matches"
                    , failures: &failures)
                    check(tp.signBit == (value < 0), "sign matches", failures: &failures)
                    check(tp.pointer == p, "pointer preserved across data sweep", failures: &failures)
                    check(tp.bitTag0 == true, "bitTag0 preserved across data sweep", failures: &failures)
                    check(tp.bitTag1 == false, "bitTag1 preserved across data sweep", failures: &failures)
                    check(tp.bitTag2 == false, "bitTag2 preserved across data sweep", failures: &failures)
                    check(tp.tagUInt3 == 1, "tag preserved across data sweep", failures: &failures)
                }
                // Tag sweep: every tag value preserves pointer and data.
                tp.dataInt17 = 12345
                for tag: UInt8 in 0...7 {
                    tp.tagUInt3 = tag
                    checkEqual(tp.tagUInt3, tag, "tag round-trips", failures: &failures)
                    checkEqual(tp.pointer, p, "pointer preserved across tag sweep", failures: &failures)
                    checkEqual(tp.dataInt17, 12345, "data preserved across tag sweep", failures: &failures)
                }
                tp.dataUInt16 = .zero
                tp.signBit = false
                tp.tagUInt3 = 0
                let z: UInt64 = 5
                withUnsafePointer(to: z) { p3 in
                    check(UInt64(bitPatternFromTaggablePointer: p3) & 0b111 == 0, "test address p3 is 8-aligned", failures: &failures)
                    checkEqual(tp.pointer, p, "pointer before reassignment", failures: &failures)
                    checkEqual(tp.dataUInt16, 0, "data before reassignment", failures: &failures)
                    checkEqual(tp.signBit, false, "sign before reassignment", failures: &failures)
                    checkEqual(tp.tagUInt3, 0, "tag before reassignment", failures: &failures)
                    tp.pointer = p3
                    checkEqual(tp.pointer, p3, "pointer reassignment sticks", failures: &failures)
                    checkEqual(tp.dataUInt16, 0, "data preserved after reassignment", failures: &failures)
                    checkEqual(tp.signBit, false, "sign preserved after reassignment", failures: &failures)
                    checkEqual(tp.tagUInt3, 0, "tag preserved after reassignment", failures: &failures)
                    tp.pointer = p2
                    checkEqual(tp.pointer, p2, "second pointer reassignment sticks", failures: &failures)
                    checkEqual(tp.dataUInt16, 0, "data preserved", failures: &failures)
                    checkEqual(tp.signBit, false, "sign preserved", failures: &failures)
                    checkEqual(tp.tagUInt3, 0, "tag preserved", failures: &failures)
                }
            }
        }

        checkEqual(
            MemoryLayout<TaggedPointer<UnsafeRawPointer>>.size,
            MemoryLayout<UInt64>.size,
            "TaggedPointer is 64 bits on every platform"
        , failures: &failures)

        // Nil pointer round-trips.
        let nilTagged = TaggedPointer<UnsafeRawPointer>(nil)
        check(nilTagged.pointer == nil, "nil pointer round-trips", failures: &failures)
        checkEqual(TaggedPointer.rawStorage(of: nilTagged), 0, "nil storage is zero", failures: &failures)

        // Simulated addresses, including 32 bit patterns with the high bit
        // set and the largest 44 bit guts value. Fake pointers let us cover
        // bit patterns the host stack will never hand out.
        let gutsMask: UInt64 = 0x0000_7FFF_FFFF_FFF8
        let dataBits: UInt64 = 0xFFFF_8000_0000_0000
        for bits: UInt64 in [0x8, 0x1234_5678, 0x8000_0000, 0xFFFF_FFF8, 0x0000_7FFF_FFFF_FFF8] {
            var tp = TaggedPointer(FakePointer(bits: bits))
            checkEqual(tp.pointer?.bits ?? .max, bits, "simulated pointer round-trips", failures: &failures)
            tp.tagUInt3 = 5
            tp.dataUInt16 = .max
            tp.signBit = true
            checkEqual(tp.pointer?.bits ?? .max, bits, "simulated pointer preserved", failures: &failures)
            checkEqual(tp.tagUInt3, 5, "tag preserved with simulated pointer", failures: &failures)
            checkEqual(tp.dataUInt16, .max, "data preserved with simulated pointer", failures: &failures)
            checkEqual(
                TaggedPointer.rawStorage(of: tp),
                dataBits | (bits & gutsMask) | 5,
                "raw storage layout matches"
            , failures: &failures)
        }

        // Fully saturated storage.
        var saturated = TaggedPointer(FakePointer(bits: 0x0000_7FFF_FFFF_FFF8))
        saturated.tagUInt3 = 7
        saturated.dataUInt16 = .max
        saturated.signBit = true
        checkEqual(
            TaggedPointer.rawStorage(of: saturated),
            .max,
            "saturated tagged pointer is all ones"
        , failures: &failures)

        if failures == 0 {
            print("PASS: all TaggedPointer checks passed")
        } else {
            print("FAILURES: \(failures)")
            fatalError("TaggedPointer checks failed")
        }
    }
}

struct FakePointer: TaggablePointer {
    var bits: UInt64

    var bitPatternAsUInt64: UInt64 {
        bits
    }

    init?(bitPattern: UInt64) {
        self.bits = bitPattern
    }

    init(bits: UInt64) {
        self.bits = bits
    }
}
