//
//  FileWriter.swift
//  SafeFile
//
//  Created by sameh on 21/10/2022.
//

import Foundation

struct FileWriter {
    var override: Bool
    let url: URL

    init(override: Bool, destination: URL) {
        self.override = override
        url = destination
    }

    func writeFile(data: Data) throws {
        if let fileHandle = try? FileHandle(forWritingTo: url),
           !override
        {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try data.write(to: url, options: .atomicWrite)
        }
    }
}
