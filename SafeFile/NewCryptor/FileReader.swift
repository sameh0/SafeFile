//
//  Reader.swift
//  SafeFile
//
//  Created by sameh on 21/10/2022.
//

import Foundation

struct FileReader {
    let chunkSize: Int
    let startAt: Int
    let file: URL

    private let fileHandle: FileHandle

    init?(chunkSize: Int, startAt: Int, file: URL) {
        self.chunkSize = chunkSize
        self.startAt = startAt
        self.file = file
        guard let fileHandle = try? FileHandle(forReadingFrom: file) else { return nil }
        self.fileHandle = fileHandle
    }

    private lazy var offset = startAt

    mutating func readFile() -> Data? {
        if offset > 0 {
            fileHandle.seek(toFileOffset: UInt64(offset))
        }
        let data = fileHandle.readData(ofLength: chunkSize)
        offset += chunkSize
        return data.isEmpty ? nil : data
    }

    func readPiece() throws -> Data? {
        guard let fileHandle = try? FileHandle(forReadingFrom: file) else { return nil }
        try fileHandle.seek(toOffset: UInt64(startAt))
        let data = fileHandle.readData(ofLength: chunkSize)
        fileHandle.closeFile()
        return data
    }
}

extension FileReader: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Data

    mutating func next() async throws -> Element? {
        let data = readFile()
        if let data {
            return data
        } else {
            fileHandle.closeFile()
            return nil
        }
    }

    func makeAsyncIterator() -> FileReader {
        self
    }
}
