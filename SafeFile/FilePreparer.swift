//
//  FilePreparer.swift
//  SafeFile
//
//  Created by Sameh Sayed on 4/29/23.
//

import Foundation

class FilePreparer {
    let sourcePath: URL
    private(set) var destinationPath: URL?
    let operation: OperationType
    private(set) var keyPath: URL?

    enum Errors: Error {
        case failed
    }

    init(sourcePath: URL, operation: OperationType) throws {
        self.sourcePath = sourcePath
        self.operation = operation
        destinationPath = nil

        guard let tempDir = createTemporaryDirectoryURL() else {
            throw Errors.failed
        }
        destinationPath = tempDir

        let fileName = sourcePath.lastPathComponent
        destinationPath?.appendPathComponent(fileName)

        destinationPath = destinationPath?
            .deletingPathExtension()
            .appendingPathExtension("safefile")

        // Only used when extreme is true
        keyPath = destinationPath?
            .deletingPathExtension()
            .appendingPathExtension("safefile-key")
            .appendingPathExtension("txt")

        if operation == .decryption {
            destinationPath = destinationPath?
                .deletingPathExtension()
        }
    }

    func decryptionExt(ext: String) {
        if operation == .encryption {
            destinationPath = nil
        }

        destinationPath = destinationPath?
            .appendingPathExtension(ext)
    }

    func createTemporaryDirectoryURL() -> URL? {
        let fileManager = FileManager.default
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let uniqueSubdirectoryName = UUID().uuidString
        let uniqueSubdirectoryURL = tempDirectoryURL.appendingPathComponent(uniqueSubdirectoryName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: uniqueSubdirectoryURL, withIntermediateDirectories: true, attributes: nil)
            return uniqueSubdirectoryURL
        } catch {
            print("Error creating temporary directory: \(error)")
            return nil
        }
    }
}
