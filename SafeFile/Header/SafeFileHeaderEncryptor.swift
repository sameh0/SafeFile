//
//  SafeFileEncryptedHeaderMaker.swift
//  SafeFile
//
//  Created by Sameh Sayed on 3/11/23.
//

import CryptoKit
import Foundation

struct SafeFileHeaderEncryptor {
    let header: SafeFileHeader
    var encryptedHeader: Data

    enum Errors: Error {
        case unsupportConfigs
        case failedToMakeHeader
    }

    init(header: SafeFileHeader, password: String? = nil, key: SymmetricKey? = nil, operationMode: OperationMode) throws {
        let cryptor = Cryptor()
        if
            header.embeddedKey != nil,
            let password,
            !password.isEmpty,
            let key = cryptor.getPasswordHash(password: password)
        {
            encryptedHeader = try header.encrypt(with: key)
        } else if header.embeddedKey == nil,
                  let key = key
        {
            encryptedHeader = try header.encrypt(with: key)
        } else {
            throw Errors.unsupportConfigs
        }
        self.header = header
        encryptedHeader = try makeMetaData(operationMode: operationMode) + encryptedHeader
    }

    private func makeMetaData(operationMode: OperationMode) throws -> Data {
        let headerSize = encryptedHeader.count
        let strHeaderSize = String(headerSize)
        guard headerSize > 0,
              let metaData = SafeFileMetaData(encryptionMethod: operationMode, headerSize: strHeaderSize).data
        else {
            throw Errors.failedToMakeHeader
        }
        return metaData
    }
}
