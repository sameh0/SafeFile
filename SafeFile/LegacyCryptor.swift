//
//  VideoCryptor.swift
//  SafeFile
//
//  Created by Sameh sayed on 3/8/21.
//  Copyright © 2021 SafeFile. All rights reserved.
//

import CryptoKit
import Foundation

/**
 Each file undergoes encryption using a randomly generated password. This password is then wrapped with my own password and stored as a wrapped blob. Consequently, even if the file is discovered without my key, it remains essentially useless.
 */

class LegacyCryptor {
    var password: String
    let partSize: Int

    var totalRead = 0
    var totalWritten = 0

    enum Errors: Error {
        case failedDecryption
    }

    init(password: String, partSize: Int = 50 * 1000 * 1000) {
        self.password = password
        self.partSize = partSize
    }

    func encryptpointer(key: SymmetricKey, file: URL, writeTo: URL, completion: () -> Void) throws {
        totalRead = 0
        totalWritten = 0
        let cryptor = Cryptor()
        let type = file.pathExtension

        guard
            let fileType = (type + String(repeating: " ", count: max(0, 100 - type.count))).data(using: .utf8),
            let encryptedPart = try cryptor.encrypt(data: fileType, key: key).combined
        else {
            fatalError()
        }
        try? writeToFile(writeTo: writeTo, data: encryptedPart, forceOverride: true)

        try readFile(chunkSize: partSize, startAt: 0, file: file, completion: { currentData in
            do {
                guard let encryptedPart = try cryptor.encrypt(data: currentData, key: key).combined else {
                    fatalError()
                }
                self.totalRead += currentData.count
                self.totalWritten += encryptedPart.count
                try? writeToFile(writeTo: writeTo, data: encryptedPart, forceOverride: false)
            } catch {
                print(error)
            }
            print("RAW : \(totalRead) ENCRYPTED :  \(totalWritten)")
        }, finishedHandler: completion)
    }

    func decryptPointer(file: URL, key: Data, writeTo: URL, completion: (_ fileUrl: URL) -> Void, progressHandler: (_ progress: Int) -> Void) throws
    {
        totalRead = 0
        totalWritten = 0
        let partSize = self.partSize + 28
        let totalPartsCount = file.fileSize / UInt64(partSize)
        var currentPartCount = 0
        var percent = 0
        let cryptor = Cryptor()
        var firstTime = true
        let unWrappedKey = try cryptor.unWrapUserKey(withPassword: password, key: key)
        var writeTo = writeTo

        if let extEncrypted = readUntil(place: 128, file: file),
           let extData = try? cryptor.decrypt(data: .init(combined: extEncrypted), key: unWrappedKey),
           let extString = String(data: extData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces)
        {
            totalRead += 128
            totalWritten += 128
            writeTo.appendPathExtension(extString)
        }

        try readFile(chunkSize: partSize, startAt: 128, file: file, completion: { currentData in
            self.totalRead += currentData.count
            do {
                let decryptedPart = try cryptor.decrypt(data: .init(combined: currentData), key: unWrappedKey)

                self.totalWritten += decryptedPart.count

                try writeToFile(writeTo: writeTo, data: decryptedPart, forceOverride: firstTime)
                firstTime = false
            } catch {
                print(error)

                throw Errors.failedDecryption
            }

            currentPartCount += 1
            if totalPartsCount > 0 {
                percent = Int((Double(currentPartCount) / Double(totalPartsCount)) * 100)
            }
            if percent < 95 {
                progressHandler(percent)
            }
            print("Encrypted : \(totalRead) Decrypted :  \(totalWritten)")
        }, finishedHandler: {
            completion(writeTo)
        })
    }

    private func readUntil(place: Int, file: URL) -> Data? {
        guard let fileHandle = try? FileHandle(forReadingFrom: file) else { return nil }
        let data = fileHandle.readData(ofLength: place)
        fileHandle.closeFile()
        return data
    }

    private func readFile(chunkSize: Int, startAt: Int, file: URL, completion: (_ part: Data) throws -> Void, finishedHandler: () -> Void) throws
    {
        guard let fileHandle = try? FileHandle(forReadingFrom: file) else { return }
        var offset = startAt
        if offset > 0 {
            fileHandle.seek(toFileOffset: UInt64(offset))
        }
        var data = fileHandle.readData(ofLength: chunkSize)
        try completion(data)
        while !data.isEmpty {
            try autoreleasepool {
                offset += chunkSize
                fileHandle.seek(toFileOffset: UInt64(offset))
                data = fileHandle.readData(ofLength: chunkSize)
                if data.isEmpty {
                    finishedHandler()
                } else {
                    try completion(data)
                }
            }
        }
        fileHandle.closeFile()
    }

    private func writeToFile(writeTo: URL, data: Data, forceOverride: Bool) throws {
        if let fileHandle = try? FileHandle(forWritingTo: writeTo), !forceOverride {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try data.write(to: writeTo, options: .atomicWrite)
        }
    }
}

private extension URL {
    var attributes: [FileAttributeKey: Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }

    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }

    var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
}

extension SymmetricKey {
    // MARK: Custom Initializers

    /// Creates a `SymmetricKey` from a Base64-encoded `String`.
    ///
    /// - Parameter base64EncodedString: The Base64-encoded string from which to generate the `SymmetricKey`.
    init?(base64EncodedString: String) {
        guard let data = Data(base64Encoded: base64EncodedString) else {
            return nil
        }

        self.init(data: data)
    }

    // MARK: - Instance Methods

    /// Serializes a `SymmetricKey` to a Base64-encoded `String`.
    func serialize() -> String {
        return withUnsafeBytes { body in
            Data(body).base64EncodedString()
        }
    }
}
