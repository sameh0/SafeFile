//
//  SafeFileApp.swift
//  SafeFile
//
//  Created by Sameh Sayed on 10/9/22.
//

import SwiftUI
@main
struct SafeFileApp: App {
    var body: some Scene {
        if #available(macOS 13.0, *) {
            return DocumentGroup(newDocument: SafeFileDocument()) { file in
                MainUI(vm: .init(file: file.fileURL))
                    .fixedSize()
            }
            .defaultSize(width: 400, height: 1500)
            .windowResizability(WindowResizability.contentSize)
        } else {
            return DocumentGroup(newDocument: SafeFileDocument()) { file in
                MainUI(vm: .init(file: file.fileURL))
            }
        }
    }
}
