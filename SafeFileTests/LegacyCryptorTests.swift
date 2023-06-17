//
//  SafeFileTests.swift
//  SafeFileTests
//
//  Created by Sameh Sayed on 10/19/22.
//

import CryptoKit
@testable import SafeFile
import XCTest

final class LegacyCryptorTests: XCTestCase {
    let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("safeLetterTests")

    override func setUpWithError() throws {
        try? FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: false)
    }

    let password = "123123"
    let fileName = "safe-file-logo-zip-file"
    lazy var fileUrl = URL(fileURLWithPath: Bundle(for: type(of: self)).path(forResource: fileName, ofType: "zip")!)

    func testEncryption() {
        XCTAssertNotNil(fileUrl)

        let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path

        let saveUrl = URL(fileURLWithPath: dirPath, isDirectory: true).appendingPathComponent("encrypted").appendingPathExtension("safefile")

        print("Save url \(saveUrl.path)")
        guard
            let key = try? Cryptor().createWrappedKey(withPassword: password),
            !password.isEmpty
        else {
            XCTFail("Failed to create key")
            return
        }
        let cryptor = LegacyCryptor(password: password, partSize: 1000)

        let keyStr = key.wrappedKey
        let realKey = keyStr.base64EncodedString()

        XCTAssertNotNil(realKey)
        do {
            try realKey.write(to: saveUrl
                .deletingPathExtension()
                .appendingPathExtension("key")
                .appendingPathExtension("txt"), atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to write key \(error)")
        }

        do {
            let exp = expectation(description: "file encrypted")
            try cryptor.encryptpointer(key: key.encryptionKey, file: fileUrl, writeTo: saveUrl) {
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10)
        } catch {
            XCTFail("Failed to save encrpyted file \(error)")
        }
    }

    func testDecryption() {
        let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let keyUrl = dirPath.appendingPathComponent(try! FileManager.default.contentsOfDirectory(atPath: dirPath.path).first {
            $0.contains(".key")
        }!)
        let encryptedFile = dirPath.appendingPathComponent(try! FileManager.default.contentsOfDirectory(atPath: dirPath.path).first {
            $0.contains(".safefile")
        }!)

        print(keyUrl)
        print(encryptedFile)

        XCTAssertNotNil(keyUrl)
        XCTAssertNotNil(encryptedFile)

        let cryptor = LegacyCryptor(password: password, partSize: 1000)

        let _kstr = try! String(contentsOf: keyUrl, encoding: .utf8)
        print(_kstr)
        let key = Data(base64Encoded: _kstr)
        let exp = expectation(description: "file encrypted")

        try! cryptor.decryptPointer(file: encryptedFile, key: key!, writeTo: encryptedFile.deletingPathExtension(), completion: { newFileUrl in
            let newFileData = try! Data(contentsOf: newFileUrl)
            let mainFileData = try! Data(contentsOf: fileUrl)
            XCTAssertEqual(newFileData, mainFileData)
            exp.fulfill()
        }, progressHandler: { _ in
            //
        })
        wait(for: [exp], timeout: 10)
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
}
