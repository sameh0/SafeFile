//
//  Encryptor.swift
//  SafeFile
//
//  Created by sameh on 21/10/2022.
//

import CryptoKit
import Foundation

class SafeEncryptor {
    let header: SafeFileHeaderEncryptor
    let encryptionKey: SymmetricKey

    enum Errors: Error {
        case failedToMakeHeader, failedToEncrypt
    }

    let filePreparer: FilePreparer

    init(filePreparer: FilePreparer, encryptionKey: SymmetricKey, header: SafeFileHeaderEncryptor) {
        self.filePreparer = filePreparer
        self.encryptionKey = encryptionKey
        self.header = header
    }

    func encrypt() async throws {
        // Header
        guard let destinationPath = filePreparer.destinationPath else { return }
        var writer = FileWriter(override: true, destination: destinationPath)
        guard let reader = FileReader(chunkSize: header.header.partSize, startAt: 0, file: filePreparer.sourcePath) else {
            throw Errors.failedToEncrypt
        }
        try writer.writeFile(data: header.encryptedHeader)

        // File
        let cryptor = Cryptor()
        var totalRead = 0
        var totalWritten = 0
        writer = FileWriter(override: false, destination: destinationPath)

        for try await part in reader {
            totalRead += part.count
            guard let encryptedPart = try cryptor.encrypt(data: part, key: encryptionKey).combined else {
                fatalError()
            }
            totalWritten += encryptedPart.count
            try writer.writeFile(data: encryptedPart)
            print("RAW : \(totalRead) ENCRYPTED :  \(totalWritten)")
        }
    }
}
