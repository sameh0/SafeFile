//
//  SafeFileDocument.swift
//  SafeFile
//
//  Created by Sameh Sayed on 10/16/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SafeFileDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        return [UTType(exportedAs: "com.sameh.safefile")]
    }

    init(configuration _: ReadConfiguration) throws {}

    init() {}

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: Data())
    }
}
