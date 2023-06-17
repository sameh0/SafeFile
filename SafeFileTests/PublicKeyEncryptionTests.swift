//
//  PublicKeyEncryptionTests.swift
//  SafeFileTests
//
//  Created by Sameh Sayed on 3/15/23.
//

import Foundation

import CryptoKit
import Foundation
@testable import SafeFile
import XCTest

final class PublicKeyEncryptionTests: XCTestCase {
    let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("safefile_public_tests")
    var rawFile: URL {
        dirPath.appendingPathComponent("mainFile.zip")
    }

    var encryptedFile: URL {
        dirPath.appendingPathComponent("mainFile.safefile")
    }

    var decryptedFile: URL {
        dirPath.appendingPathComponent("mainFile-decrypted.zip")
    }

    var publicKey: URL {
        dirPath.appendingPathComponent("SafeFile.publicKey.txt")
    }

    var privateKey: URL {
        dirPath.appendingPathComponent("SafeFile.privateKey.txt")
    }

    let password = "123123"

    func testPublicKeyEncryption() async throws {
        XCTAssertNotNil(encryptedFile)

        var publicKeyData: Data {
            let data = try! Data(contentsOf: publicKey)
            return Data(base64Encoded: data)!
        }

        removeAllFiles(in: dirPath)
        try? FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: false)
        XCTAssertNotNil(rawFile)
        let saveUrl = URL(fileURLWithPath: dirPath.path, isDirectory: true).appendingPathComponent("mainFile.zip")
        lazy var fileUrl = URL(fileURLWithPath: Bundle(for: type(of: self)).path(forResource: "safe-file-logo-zip-file", ofType: "zip")!)
        lazy var publicKeyUrl = URL(fileURLWithPath: Bundle(for: type(of: self)).path(forResource: "SafeFile.publicKey", ofType: "txt")!)
        lazy var privateKeyUrl = URL(fileURLWithPath: Bundle(for: type(of: self)).path(forResource: "SafeFile.privateKey", ofType: "txt")!)

        try? FileManager.default.copyItem(atPath: publicKeyUrl.path, toPath: publicKey.path)
        try? FileManager.default.copyItem(atPath: privateKeyUrl.path, toPath: privateKey.path)

        try? FileManager.default.copyItem(atPath: fileUrl.path, toPath: saveUrl.path)
        print("Save url \(saveUrl.path)")

        let keychain = try! Cryptor().createWrappedKey(withKey: publicKeyData)

        let filePreparer: FilePreparer = try .init(sourcePath: rawFile, operation: .encryption)
        let header = SafeFileHeader(partSize: 1000, extension: "zip", fileVersion: fileVersion, embeddedKey: keychain.base64secondPartyPublicKey, salt: keychain.salt)
        let encryptedHeader = try SafeFileHeaderEncryptor(header: header, password: keychain.base64FirstPublicKey, operationMode: .publicKey)
        let cryptor = SafeEncryptor(filePreparer: filePreparer, encryptionKey: keychain.encryptionKey, header: encryptedHeader)
        try await cryptor.encrypt()

        guard let destinationPath = filePreparer.destinationPath else {
            fatalError()
        }

        let fileName = filePreparer.destinationPath?.lastPathComponent ?? ""
        try FileManager.default.copyItem(at: destinationPath, to: dirPath.appendingPathComponent(fileName))
    }

    func testPublicKeyDecryption() async throws {
        var privateKeyData: Data {
            let data = try! Data(contentsOf: privateKey)
            return Data(base64Encoded: data)!
        }

        let publicKey = try Cryptor().getPublicKey(privateKey: privateKeyData)
        let keyStr = publicKey.base64EncodedString()
        print(keyStr)
        guard let headerEncryptionKey = Cryptor().getPasswordHash(password: keyStr) else {
            throw MainViewModel.Errors.failedDecryption
        }

        let header = try SafeFileHeaderDecryptor(fileURL: encryptedFile, key: headerEncryptionKey)

        guard let includedPublicKey = Data(base64Encoded: header.header.embeddedKey ?? ""),
              // header.header.key?.data(using: .utf8)?.base64EncodedData(),
              let salt = header.header.salt
        else {
            return
        }

        let unwrapUserKey = try Cryptor().unWrapUserKey(chain: .init(privateKey: privateKeyData, publicKey: includedPublicKey, salt: salt))
        let filePreparer: FilePreparer = try .init(sourcePath: encryptedFile, operation: .decryption)
        filePreparer.decryptionExt(ext: header.header.extension)
        let decryptor = SafeDecryptor(filePreparer: filePreparer, decryptionKey: unwrapUserKey, header: header)
        try await decryptor.decrypt()

        guard let destinationPath = filePreparer.destinationPath else {
            fatalError()
        }
        try FileManager.default.copyItem(at: destinationPath, to: decryptedFile)

        let original = try! getSHA256(forFile: rawFile)
        let produced = try! getSHA256(forFile: decryptedFile)
        XCTAssertEqual(original, produced)
        removeAllFiles(in: dirPath)
    }

    func testPublicKeyHeaderDecryptionWithPublicKey() throws {
        var privateKeyData: Data {
            let data = try! Data(contentsOf: self.publicKey)
            return Data(base64Encoded: data)!
        }
        let decryptedFilePath = encryptedFile
            .deletingPathExtension()
            .appendingPathExtension("zip")

        try? FileManager.default.removeItem(atPath: decryptedFilePath.path)

        let publicKey = try Cryptor().getPublicKey(privateKey: privateKeyData)
        let keyStr = publicKey.base64EncodedString()
        print(keyStr)
        guard let headerEncryptionKey = Cryptor().getPasswordHash(password: keyStr) else {
            throw MainViewModel.Errors.failedDecryption
        }

        let header = try? SafeFileHeaderDecryptor(fileURL: encryptedFile, key: headerEncryptionKey)
        XCTAssertNil(header)
    }
}
