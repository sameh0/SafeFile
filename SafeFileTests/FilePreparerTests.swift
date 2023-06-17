//
//  FilePreparerTests.swift
//  SafeFileTests
//
//  Created by Sameh Sayed on 4/25/23.
//

@testable import SafeFile
import XCTest

class FilePreparerTests: XCTestCase {
    var filePreparer: FilePreparer!
    var sourcePath: URL!
    let fileManager = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        sourcePath = URL(fileURLWithPath: "/path/to/your/source/file.txt")
    }

    override func tearDownWithError() throws {
        filePreparer = nil
        sourcePath = nil
        try super.tearDownWithError()
    }

    func testFilePreparerInitEncryption() throws {
        filePreparer = try FilePreparer(sourcePath: sourcePath, operation: .encryption)
        XCTAssertEqual(filePreparer.sourcePath, sourcePath)
        XCTAssertNotNil(filePreparer.destinationPath)
        XCTAssertEqual(filePreparer.operation, .encryption)
        XCTAssertNotNil(filePreparer.keyPath)
    }

    func testFilePreparerForDecryption() {
        filePreparer = try? FilePreparer(sourcePath: sourcePath, operation: .decryption)
        filePreparer.decryptionExt(ext: "txt")
        let decryptedURL = filePreparer.destinationPath
        XCTAssertNotNil(decryptedURL)
        XCTAssertEqual(decryptedURL?.pathExtension, "txt")
        XCTAssertEqual(decryptedURL?.lastPathComponent, sourcePath.lastPathComponent)
    }

    func testFilePreparerForDecryptionFail() {
        filePreparer = try? FilePreparer(sourcePath: sourcePath, operation: .encryption)
        filePreparer.decryptionExt(ext: "txt")
        XCTAssertNil(filePreparer.destinationPath)
    }

    func testFilePreparerCreateTemporaryDirectoryURL() {
        filePreparer = try? FilePreparer(sourcePath: sourcePath, operation: .encryption)
        let tempDirURL = filePreparer.createTemporaryDirectoryURL()
        XCTAssertNotNil(tempDirURL)
        XCTAssertTrue(fileManager.fileExists(atPath: tempDirURL!.path))
    }
}
