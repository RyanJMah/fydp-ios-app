//
//  GuidingLite_MDNS.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2024-02-07.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import Darwin

extension UInt16 {
    var bigEndianBytes: [UInt8] {
        return [UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}

class MDNSQuery: NSObject
{
    let multicastAddr = "224.0.0.251"
    let multicastPort: UInt16 = 5353

    func mdnsQuery(name: String) -> Data {
        var header = Data([0x00, 0x00])
        var question = Data()

        for label in name.split(separator: ".") {
            question.append(UInt8(label.count))
            question.append(contentsOf: label.utf8)
        }

        // 00 01 for A records
        question.append(contentsOf: [0x00, 0x01])

        // Hardcoded bytes for QCLASS and UNICAST-RESPONSE
        question.append(contentsOf: [0x00, 0x01, 0x00, 0x01])

        // Hardcoded transaction ID
        let transId: UInt16 = 0x0000

        var pkt = Data()
        pkt.append(contentsOf: transId.bigEndianBytes)
        pkt.append(contentsOf: header)
        pkt.append(contentsOf: [0x00, 0x01])
        pkt.append(contentsOf: [0x00, 0x00])
        pkt.append(contentsOf: [0x00, 0x00])
        pkt.append(contentsOf: [0x00, 0x00])
        pkt.append(question)

        return pkt
    }

    override init()
    {
        super.init()

        let query = mdnsQuery(name: SERVER_MDNS_HOSTNAME)

        // UDP socket, send to multicast address 224.0.0.251

        let sock = socket(AF_INET, SOCK_DGRAM, 0)

        guard sock != -1 else {
            fatalError("Failed to create socket")
        }

        var addr = sockaddr_in()

        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = multicastPort.bigEndian
        inet_pton(AF_INET, multicastAddr, &addr.sin_addr)

        let sent = query.withUnsafeBytes { queryPointer in
            withUnsafePointer(to: &addr) { addrPointer in
                addrPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addrSockPtr in
                    sendto(sock, queryPointer.baseAddress, query.count, 0, addrSockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        print(addr)

        guard sent != -1 else {
            let error = String(cString: strerror(errno))
            fatalError("Failed to send data: \(error)")
        }


        var buffer = [UInt8](repeating: 0, count: 1024)
        let size = recv(sock, &buffer, buffer.count, 0)
        guard size != -1 else {
            fatalError("Failed to receive data")
        }

        let receivedData = Data(bytes: buffer, count: size)
        print(receivedData)
    }
}
