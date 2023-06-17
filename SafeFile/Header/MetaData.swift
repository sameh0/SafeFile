//
//  MetaData.swift
//  SafeFile
//
//  Created by Sameh Sayed on 3/11/23.
//

import Foundation

struct MetaDataManager {
    let fileUrl: URL

    func get() throws -> (Int, SafeFileMetaData)? {
        if let legacySize = try? getLegacySize(),
           Int(legacySize) != nil
        {
            return (10, SafeFileMetaData(encryptionMethod: nil, headerSize: legacySize))
        }

        let reader = FileReader(chunkSize: SafeFileMetaData.reservedSpace, startAt: 0, file: fileUrl)
        guard let data = try reader?.readPiece() else {
            return nil
        }
        if let newData = SafeFileMetaData.make(data: data) {
            return (SafeFileMetaData.reservedSpace, newData)
        }

        return nil
    }

    private func getLegacySize() throws -> String? {
        let reader = FileReader(chunkSize: 10, startAt: 0, file: fileUrl)
        guard let data = try reader?.readPiece() else {
            return nil
        }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespaces)
    }
}

struct SafeFileMetaData: Codable {
    let encryptionMethod: OperationMode?
    let headerSize: String
    var headerSizeInt: Int {
        Int(headerSize.trimmingCharacters(in: .whitespaces)) ?? -1
    }

    static let reservedSpace = 1024

    var data: Data? {
        guard let encoded = encode() else {
            return nil
        }
        let space = UInt8(ascii: " ")
        return encoded + Data(repeating: space, count: max(0, Self.reservedSpace - encoded.count))
    }

    static func make(data: Data) -> Self? {
        let space = UInt8(ascii: " ")

        let headerData = data.filter {
            $0 != space
        }

        return headerData.getObject()
    }
}
