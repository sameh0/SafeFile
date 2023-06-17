//
//  NewEncryptorTests.swift
//  SafeFileTests
//
//  Created by sameh on 21/10/2022.
//

import CryptoKit
import Foundation
@testable import SafeFile
import XCTest

final class NewEncryptorTests: XCTestCase {
    let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("new_encryptor_tests")

    var rawFile: URL {
        dirPath.appendingPathComponent("mainFile.zip")
    }

    var encryptedFile: URL {
        dirPath.appendingPathComponent("mainFile.safefile")
    }

    lazy var fileUrl = URL(fileURLWithPath: Bundle(for: type(of: self)).path(forResource: "safe-file-logo-zip-file", ofType: "zip")!)
    lazy var saveUrl = URL(fileURLWithPath: dirPath.path, isDirectory: true).appendingPathComponent("mainFile.zip")

    let password = "123123"
    var decryptedFile: URL {
        dirPath.appendingPathComponent("mainFile-decrypted.zip")
    }

    func testNewEncryptionWithOutKey() async throws {
        XCTAssertNotNil(encryptedFile)

        removeAllFiles(in: dirPath)
        try? FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: false)
        XCTAssertNotNil(rawFile)
        try? FileManager.default.copyItem(atPath: fileUrl.path, toPath: saveUrl.path)

        let key = try! Cryptor().createWrappedKey(withPassword: "123123")
        let header = SafeFileHeader(partSize: 1000, extension: "zip", fileVersion: fileVersion, embeddedKey: key.wrappedKey.base64EncodedString(), salt: nil)
        let encryptedHeader = try SafeFileHeaderEncryptor(header: header, password: password, key: key.encryptionKey, operationMode: .normal(extreme: false))
        let filePreparer: FilePreparer = try .init(sourcePath: rawFile, operation: .encryption)
        let cryptor = SafeEncryptor(filePreparer: filePreparer, encryptionKey: key.encryptionKey, header: encryptedHeader)
        try await cryptor.encrypt()
        guard let destinationPath = filePreparer.destinationPath else {
            fatalError()
        }
        let fileName = filePreparer.destinationPath?.lastPathComponent ?? ""
        try FileManager.default.copyItem(at: destinationPath, to: dirPath.appendingPathComponent(fileName))
    }

    func testNewDecryptionWithOutKey() async throws {
        XCTAssertNotNil(encryptedFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedFile.path))

        var header: SafeFileHeaderDecryptor?

        let encryptionKey: SymmetricKey? = try {
            if let headerEncryptionKey = Cryptor().getPasswordHash(password: password) {
                // key in header - isExtreme = false
                header = try .init(fileURL: encryptedFile, key: headerEncryptionKey)
                if let keyData = Data(base64Encoded: header?.header.embeddedKey ?? "") {
                    return try Cryptor().unWrapUserKey(withPassword: password, key: keyData)
                }
            }
            return nil
        }()

        guard let encryptionKey else {
            throw MainViewModel.Errors.failedDecryption
        }

        if header == nil {
            header = try .init(fileURL: encryptedFile, key: encryptionKey)
        }
        let filePreparer: FilePreparer = try .init(sourcePath: encryptedFile, operation: .decryption)
        filePreparer.decryptionExt(ext: header?.header.extension ?? "")
        let decryptor = SafeDecryptor(filePreparer: filePreparer, decryptionKey: encryptionKey, header: header!)
        try await decryptor.decrypt()

        guard let destinationPath = filePreparer.destinationPath else {
            fatalError()
        }
        let decryptedFileName = filePreparer.destinationPath?.lastPathComponent ?? ""
        try FileManager.default.copyItem(at: destinationPath, to: decryptedFile)

        let original = try! getSHA256(forFile: rawFile)
        let produced = try! getSHA256(forFile: dirPath.appendingPathComponent(decryptedFileName))
        XCTAssertEqual(original, produced)
        removeAllFiles(in: dirPath)
    }
}

func getSHA256(forFile url: URL) throws -> SHA256.Digest {
    let handle = try FileHandle(forReadingFrom: url)
    var hasher = SHA256()
    while autoreleasepool(invoking: {
        let nextChunk = handle.readData(ofLength: SHA256.blockByteCount)
        guard !nextChunk.isEmpty else { return false }
        hasher.update(data: nextChunk)
        return true
    }) {}
    let digest = hasher.finalize()
    return digest
}
