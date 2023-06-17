//
//  Decryptor.swift
//  SafeFile
//
//  Created by sameh on 21/10/2022.
//

import CryptoKit
import Foundation

class SafeDecryptor {
    enum Errors: Error {
        case failedToMakeHeader
        case cantGetKey
        case failedToDecrypt
    }

    let filePreparer: FilePreparer
    var decryptionKey: SymmetricKey
    let header: SafeFileHeaderDecryptor

    init(filePreparer: FilePreparer, decryptionKey: SymmetricKey, header: SafeFileHeaderDecryptor) {
        self.filePreparer = filePreparer
        self.decryptionKey = decryptionKey
        self.header = header
    }

    func decrypt() async throws {
        let (header, startAt) = (header.header, header.size)

        let cryptor = Cryptor()

        var totalRead = startAt
        var totalWritten = 0

        guard let reader = FileReader(chunkSize: header.partSize + 28, startAt: startAt, file: filePreparer.sourcePath),
              let destinationPath = filePreparer.destinationPath
        else {
            throw Errors.failedToDecrypt
        }
        var writer = FileWriter(override: true, destination: destinationPath)
        try writer.writeFile(data: Data())
        writer.override = false

        for try await part in reader {
            totalRead += part.count
            let decryptedPart = try cryptor.decrypt(data: .init(combined: part), key: decryptionKey)
            totalWritten += decryptedPart.count
            try writer.writeFile(data: decryptedPart)

            print("RAW : \(totalRead) DECRYPTED :  \(totalWritten)")
        }
    }
}
