//
//  SafeFileHeaderDecryptor.swift
//  SafeFile
//
//  Created by Sameh Sayed on 3/11/23.
//

import CryptoKit
import Foundation

struct SafeFileHeaderDecryptor {
    let header: SafeFileHeader
    let encryptedHeader: Data
    var size: Int {
        header.fileVersion == "1" ?
            10 + encryptedHeader.count :
            SafeFileMetaData.reservedSpace + encryptedHeader.count
    }

    enum Errors: Error {
        case failedToMakeHeader
    }

    init(fileURL: URL, key: SymmetricKey) throws {
        guard let (metaSize, metaData) = try MetaDataManager(fileUrl: fileURL).get(),
              metaData.headerSizeInt > 0
        else {
            throw Errors.failedToMakeHeader
        }

        let reader = FileReader(chunkSize: metaData.headerSizeInt, startAt: metaSize, file: fileURL)
        guard let encryptedHeaderData = try reader?.readPiece() else {
            throw Errors.failedToMakeHeader
        }
        encryptedHeader = encryptedHeaderData

        guard let header = try SafeFileHeader.decrypt(data: encryptedHeader, key: key) else {
            throw Errors.failedToMakeHeader
        }

        self.header = header
    }
}
