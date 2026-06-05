import Foundation
import Darwin

public enum DNSRecordType: UInt16 {
    case a = 1
    case aaaa = 28
    case any = 255
}

public struct DNSQuestion: Sendable {
    public let hostname: String
    public let type: UInt16
    public let qclass: UInt16
    public let questionBytes: [UInt8]
}

public struct DNSPacket: Sendable {
    private let bytes: [UInt8]
    public let identifier: UInt16
    public let flags: UInt16
    public let question: DNSQuestion

    public init?(_ data: Data) {
        let bytes = Array(data)
        guard bytes.count >= 12 else { return nil }
        guard DNSPacket.readUInt16(bytes, at: 4) == 1 else { return nil }

        var cursor = 12
        guard let hostname = DNSPacket.readName(bytes, cursor: &cursor),
              cursor + 4 <= bytes.count else {
            return nil
        }

        let type = DNSPacket.readUInt16(bytes, at: cursor)
        let qclass = DNSPacket.readUInt16(bytes, at: cursor + 2)
        cursor += 4

        self.bytes = bytes
        self.identifier = DNSPacket.readUInt16(bytes, at: 0)
        self.flags = DNSPacket.readUInt16(bytes, at: 2)
        self.question = DNSQuestion(
            hostname: LocaleDNSHostMapping.normalize(hostname),
            type: type,
            qclass: qclass,
            questionBytes: Array(bytes[12..<cursor])
        )
    }

    public func response(for ipAddress: String, ttl: UInt32 = 30) -> Data? {
        guard question.qclass == 1 else { return nil }

        let recordType: DNSRecordType
        let rdata: [UInt8]
        if let ipv4 = DNSPacket.ipv4Bytes(ipAddress),
           question.type == DNSRecordType.a.rawValue || question.type == DNSRecordType.any.rawValue {
            recordType = .a
            rdata = ipv4
        } else if let ipv6 = DNSPacket.ipv6Bytes(ipAddress),
                  question.type == DNSRecordType.aaaa.rawValue || question.type == DNSRecordType.any.rawValue {
            recordType = .aaaa
            rdata = ipv6
        } else {
            return noAnswerResponse()
        }

        var response = responseHeader(answerCount: 1)
        response.append(contentsOf: question.questionBytes)
        response.append(0xC0)
        response.append(0x0C)
        DNSPacket.appendUInt16(recordType.rawValue, to: &response)
        DNSPacket.appendUInt16(1, to: &response)
        DNSPacket.appendUInt32(ttl, to: &response)
        DNSPacket.appendUInt16(UInt16(rdata.count), to: &response)
        response.append(contentsOf: rdata)
        return Data(response)
    }

    public func noAnswerResponse() -> Data {
        var response = responseHeader(answerCount: 0)
        response.append(contentsOf: question.questionBytes)
        return Data(response)
    }

    private func responseHeader(answerCount: UInt16) -> [UInt8] {
        var response: [UInt8] = []
        DNSPacket.appendUInt16(identifier, to: &response)
        let recursionDesired = flags & 0x0100
        DNSPacket.appendUInt16(0x8000 | 0x0080 | recursionDesired, to: &response)
        DNSPacket.appendUInt16(1, to: &response)
        DNSPacket.appendUInt16(answerCount, to: &response)
        DNSPacket.appendUInt16(0, to: &response)
        DNSPacket.appendUInt16(0, to: &response)
        return response
    }

    private static func readName(_ bytes: [UInt8], cursor: inout Int) -> String? {
        var labels: [String] = []
        var jumped = false
        var localCursor = cursor
        var seenPointers = Set<Int>()

        while localCursor < bytes.count {
            let length = Int(bytes[localCursor])

            if length == 0 {
                localCursor += 1
                if !jumped {
                    cursor = localCursor
                }
                return labels.joined(separator: ".")
            }

            if length & 0xC0 == 0xC0 {
                guard localCursor + 1 < bytes.count else { return nil }
                let pointer = ((length & 0x3F) << 8) | Int(bytes[localCursor + 1])
                guard pointer < bytes.count, !seenPointers.contains(pointer) else { return nil }
                seenPointers.insert(pointer)
                if !jumped {
                    cursor = localCursor + 2
                }
                localCursor = pointer
                jumped = true
                continue
            }

            guard length & 0xC0 == 0,
                  localCursor + 1 + length <= bytes.count else {
                return nil
            }

            let labelBytes = bytes[(localCursor + 1)..<(localCursor + 1 + length)]
            guard let label = String(bytes: labelBytes, encoding: .utf8) else { return nil }
            labels.append(label)
            localCursor += 1 + length
        }

        return nil
    }

    private static func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
    }

    private static func appendUInt16(_ value: UInt16, to bytes: inout [UInt8]) {
        bytes.append(UInt8((value >> 8) & 0xFF))
        bytes.append(UInt8(value & 0xFF))
    }

    private static func appendUInt32(_ value: UInt32, to bytes: inout [UInt8]) {
        bytes.append(UInt8((value >> 24) & 0xFF))
        bytes.append(UInt8((value >> 16) & 0xFF))
        bytes.append(UInt8((value >> 8) & 0xFF))
        bytes.append(UInt8(value & 0xFF))
    }

    private static func ipv4Bytes(_ value: String) -> [UInt8]? {
        var address = in_addr()
        let result = value.withCString { inet_pton(AF_INET, $0, &address) }
        guard result == 1 else { return nil }
        return withUnsafeBytes(of: address) { Array($0) }
    }

    private static func ipv6Bytes(_ value: String) -> [UInt8]? {
        var address = in6_addr()
        let result = value.withCString { inet_pton(AF_INET6, $0, &address) }
        guard result == 1 else { return nil }
        return withUnsafeBytes(of: address) { Array($0) }
    }
}
