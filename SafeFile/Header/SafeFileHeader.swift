//
//  File.swift
//  SafeFile
//
//  Created by sameh on 21/10/2022.
//

import CryptoKit
import Foundation

struct SafeFileHeader: Codable {
    static let partSize: Int = 50 * 1000 * 1000
    let partSize: Int
    let `extension`: String
    let fileVersion: String
    let embeddedKey: String?
    let salt: String?
    enum Errors: Error {
        case failedToEcryptHeader
    }

    func encrypt(with key: SymmetricKey) throws -> Data {
        let cryptor = Cryptor()
        guard let encodedSelf = encode() else {
            throw Errors.failedToEcryptHeader
        }
        guard let data = try cryptor.encrypt(data: encodedSelf, key: key).combined else {
            throw Errors.failedToEcryptHeader
        }
        return data
    }

    static func decrypt(data: Data, key: SymmetricKey) throws -> Self? {
        let cryptor = Cryptor()
        let decryptedHeader = try cryptor.decrypt(data: .init(combined: data), key: key)
        return decryptedHeader.getObject()
    }
}
