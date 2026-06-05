import Foundation
import XCTest
@testable import LocaleShared

final class DNSPacketTests: XCTestCase {
    func testARecordResponseForMappedHost() {
        let query = makeQuery(identifier: 0x1234, hostname: "API.Company.Internal.", type: DNSRecordType.a.rawValue)
        let packet = DNSPacket(query)

        XCTAssertEqual(packet?.identifier, 0x1234)
        XCTAssertEqual(packet?.question.hostname, "api.company.internal")

        let response = packet?.response(for: "10.1.2.3")
        let bytes = [UInt8](response ?? Data())

        XCTAssertEqual(readUInt16(bytes, at: 0), 0x1234)
        XCTAssertEqual(readUInt16(bytes, at: 4), 1)
        XCTAssertEqual(readUInt16(bytes, at: 6), 1)
        XCTAssertEqual(Array(bytes.suffix(4)), [10, 1, 2, 3])
    }

    func testWrongAddressFamilyReturnsNoAnswerResponse() {
        let query = makeQuery(identifier: 0x5678, hostname: "api.company.internal", type: DNSRecordType.aaaa.rawValue)
        let response = DNSPacket(query)?.response(for: "10.1.2.3")
        let bytes = [UInt8](response ?? Data())

        XCTAssertEqual(readUInt16(bytes, at: 0), 0x5678)
        XCTAssertEqual(readUInt16(bytes, at: 4), 1)
        XCTAssertEqual(readUInt16(bytes, at: 6), 0)
    }

    private func makeQuery(identifier: UInt16, hostname: String, type: UInt16) -> Data {
        var bytes: [UInt8] = []
        appendUInt16(identifier, to: &bytes)
        appendUInt16(0x0100, to: &bytes)
        appendUInt16(1, to: &bytes)
        appendUInt16(0, to: &bytes)
        appendUInt16(0, to: &bytes)
        appendUInt16(0, to: &bytes)

        for label in hostname.trimmingCharacters(in: CharacterSet(charactersIn: ".")).split(separator: ".") {
            let labelBytes = Array(label.utf8)
            bytes.append(UInt8(labelBytes.count))
            bytes.append(contentsOf: labelBytes)
        }
        bytes.append(0)
        appendUInt16(type, to: &bytes)
        appendUInt16(1, to: &bytes)
        return Data(bytes)
    }

    private func appendUInt16(_ value: UInt16, to bytes: inout [UInt8]) {
        bytes.append(UInt8((value >> 8) & 0xFF))
        bytes.append(UInt8(value & 0xFF))
    }

    private func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        guard offset + 1 < bytes.count else { return 0 }
        return (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
    }
}
