//
//  CryptorTestsWithKey.swift
//  SafeFileTests
//
//  Created by Sameh Sayed on 3/15/23.
//

import CryptoKit
import Foundation
@testable import SafeFile
import XCTest

final class CryptorTestsWithKey: XCTestCase {
    let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("safefile_key_tests")

    var rawFile: URL {
        dirPath.appendingPathComponent("mainFile.zip")
    }

    var encryptedFile: URL {
        dirPath.appendingPathComponent("mainFile.safefile")
    }

    var decryptedFile: URL {
        dirPath.appendingPathComponent("mainFile-decrypted.zip")
    }

    let password = "123123"

    func testEncryptionWithKey() async throws {
        XCTAssertNotNil(encryptedFile)
        print("Save url \(encryptedFile.path)")
        let keyUrl = encryptedFile
            .appendingPathExtension("key")
            .appendingPathExtension("txt")

        removeAllFiles(in: dirPath)
        try? FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: false)
        XCTAssertNotNil(rawFile)
        let saveUrl = URL(fileURLWithPath: dirPath.path, isDirectory: true).appendingPathComponent("mainFile.zip")
        lazy var fileUrl = URL(fileURLWithPath: Bundle(for: type(of: self)).path(forResource: "safe-file-logo-zip-file", ofType: "zip")!)
        try? FileManager.default.copyItem(atPath: fileUrl.path, toPath: saveUrl.path)
        print("Save url \(saveUrl.path)")

        let key = try! Cryptor().createWrappedKey(withPassword: "123123")

        let keyStr = key.wrappedKey
        let realKey = keyStr.base64EncodedString()

        XCTAssertNotNil(realKey)

        do {
            try realKey.write(to: keyUrl, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to write key \(error)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: keyUrl.path))
        let filePreparer: FilePreparer = try .init(sourcePath: rawFile, operation: .encryption)
        let header = SafeFileHeader(partSize: 1000, extension: "zip", fileVersion: fileVersion, embeddedKey: nil, salt: nil)
        let encryptedHeader = try SafeFileHeaderEncryptor(header: header, password: password, key: key.encryptionKey, operationMode: .normal(extreme: false))

        let cryptor = SafeEncryptor(filePreparer: filePreparer, encryptionKey: key.encryptionKey, header: encryptedHeader)
        try await cryptor.encrypt()
        guard let destinationPath = filePreparer.destinationPath else {
            fatalError()
        }
        let fileName = filePreparer.destinationPath?.lastPathComponent ?? ""
        try FileManager.default.copyItem(at: destinationPath, to: dirPath.appendingPathComponent(fileName))
    }

    func testNewDecryption() async throws {
        let keyUrl = dirPath.appendingPathComponent(try! FileManager.default.contentsOfDirectory(atPath: dirPath.path).first {
            $0.contains(".key")
        }!)

        var header: SafeFileHeaderDecryptor?

        let encryptionKey: SymmetricKey? = try {
            let fileKey = try Data(contentsOf: keyUrl)
            if let keyData = Data(base64Encoded: fileKey) {
                return try Cryptor().unWrapUserKey(withPassword: password, key: keyData)
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

        let decryptor = SafeDecryptor(filePreparer: filePreparer, decryptionKey: encryptionKey, header: header!)
        try await decryptor.decrypt()

        guard let destinationPath = filePreparer.destinationPath else {
            fatalError()
        }

        try FileManager.default.copyItem(at: destinationPath, to: decryptedFile)

        let original = try! getSHA256(forFile: rawFile)
        let produced = try! getSHA256(forFile: decryptedFile)
        XCTAssertEqual(original, produced)
    }
}

func removeAllFiles(in folderURL: URL) {
    let fileManager = FileManager.default
    guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
    try? contents.forEach(fileManager.removeItem(at:))
}
