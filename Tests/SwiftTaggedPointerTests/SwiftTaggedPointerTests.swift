import XCTest
import SwiftTaggedPointer

final class SwiftTaggedPointerTests: XCTestCase {
    func testExample() throws {
        let x = 5
        withUnsafePointer(to: x) { p in
            let y = 5
            withUnsafePointer(to: y) { p2 in
                var tp = TaggedPointer(p)
                let tp2 = TaggedPointer(p2)
                XCTAssertNotEqual(tp, tp2)
                XCTAssertNotEqual(p, p2)
                XCTAssertNotEqual(tp.getPointer(), tp2.getPointer())
                XCTAssertEqual(p, tp.getPointer())
                XCTAssertEqual(tp.tagUInt3, 0)
                XCTAssertEqual(tp.bitTag0, false)
                tp.bitTag0 = true
                XCTAssertEqual(tp.tagUInt3, 1)
                XCTAssertEqual(tp.bitTag0, true)
                XCTAssertEqual(p, tp.getPointer())
                XCTAssertEqual(tp.bitTag0, true)
                tp.bitTag0 = false
                XCTAssertEqual(tp.tagUInt3, 0)
                XCTAssertEqual(tp.bitTag0, false)
                tp.bitTag1 = true
                XCTAssertEqual(tp.tagUInt3, 2)
                XCTAssertEqual(tp.bitTag1, true)
                XCTAssertEqual(tp.bitTag0, false)
                XCTAssertEqual(tp.bitTag2, false)
                tp.bitTag2 = true
                XCTAssertEqual(tp.tagUInt3, 6)
                XCTAssertEqual(tp.bitTag2, true)
                tp.tagUInt3 = 1
                XCTAssertEqual(tp.tagUInt3, 1)
                XCTAssertEqual(tp.bitTag0, true)
                XCTAssertEqual(tp.bitTag1, false)
                XCTAssertEqual(tp.bitTag2, false)
                XCTAssertEqual(tp.dataUInt16, 0)
                XCTAssertEqual(tp.signBit, false)
                XCTAssertEqual(p, tp.getPointer())
                tp.signBit = true
                XCTAssertEqual(tp.tagUInt3, 1)
                XCTAssertEqual(tp.dataUInt16, 0)
                XCTAssertEqual(tp.signBit, true)
                XCTAssertEqual(p, tp.getPointer())
                tp.dataUInt16 = .max
                XCTAssertEqual(tp.dataUInt16, .max)
                XCTAssertEqual(tp.signBit, true)
                XCTAssertEqual(p, tp.getPointer())
                tp.dataUInt16 = 0
                XCTAssertEqual(tp.dataUInt16, 0)
                XCTAssertEqual(tp.signBit, true)
                XCTAssertEqual(p, tp.getPointer())
                tp.dataInt17 = 37
                XCTAssertEqual(tp.dataInt17, 37)
                XCTAssertEqual(tp.dataUInt16, 37)
                XCTAssertEqual(tp.signBit, false)
                tp.signBit = true
                XCTAssertEqual(tp.tagUInt3, 1)
                XCTAssertEqual(tp.dataInt17, -38)
                XCTAssertEqual(tp.dataUInt16, 37)
                XCTAssertEqual(tp.signBit, true)
                tp.dataInt17 = 0
                XCTAssertEqual(tp.dataInt17, 0)
                XCTAssertEqual(tp.dataUInt16, 0)
                XCTAssertEqual(tp.signBit, false)
                tp.signBit = true
                XCTAssertEqual(tp.tagUInt3, 1)
                XCTAssertEqual(tp.dataInt17, -1)
                XCTAssertEqual(tp.dataUInt16, 0)
                XCTAssertEqual(tp.signBit, true)
                tp.dataInt17 = -5
                XCTAssertEqual(tp.dataInt17, -5)
                XCTAssertEqual(tp.dataUInt16, 4)
                XCTAssertEqual(tp.signBit, true)
                tp.signBit = false
                XCTAssertEqual(tp.tagUInt3, 1)
                XCTAssertEqual(tp.dataInt17, 4)
                XCTAssertEqual(tp.dataUInt16, 4)
                XCTAssertEqual(tp.signBit, false)
                for uint17: Int32 in -65536...65535 {
                    tp.dataInt17 = uint17
                    guard tp.dataInt17 == uint17 else {
                        XCTFail()
                        return
                    }
                    guard tp.dataUInt16 == (uint17 < 0 ? UInt16(-(uint17 + 1)) : UInt16(uint17)) else {
                        XCTFail()
                        return
                    }
                    guard tp.signBit == (uint17 < 0) else {
                        XCTFail()
                        return
                    }
                    guard p == tp.getPointer() else {
                        XCTFail()
                        return
                    }
                    guard tp.bitTag0 == true else {
                        XCTFail()
                        return
                    }
                    guard tp.bitTag1 == false else {
                        XCTFail()
                        return
                    }
                    guard tp.bitTag2 == false else {
                        XCTFail()
                        return
                    }
                    guard tp.tagUInt3 == 1 else {
                        XCTFail()
                        return
                    }
                }
            }
        }
    }
}
