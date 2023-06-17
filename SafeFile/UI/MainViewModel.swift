//
//  MainViewModel.swift
//  SafeFile
//
//  Created by sameh on 21/10/2022.
//

import AppKit
import Combine
import Foundation
import SwiftUI

enum OperationMode: Equatable, CaseIterable, Identifiable, Codable {
    var id: String {
        name
    }

    static var allCases: [OperationMode] {
        [.legacy, publicKey, .normal(extreme: false)]
    }

    case legacy, publicKey
    case normal(extreme: Bool)

    var name: String {
        switch self {
        case .legacy:
            return "Legacy Mode"
        case .publicKey:
            return "PublicKey Mode"
        case let .normal(extreme):
            return extreme ? "Extreme Mode" : "Regular"
        }
    }
}

enum OperationType {
    case encryption
    case decryption

    var options: [OperationMode] {
        switch self {
        case .encryption:
            return [.legacy, .normal(extreme: false), .publicKey]
        case .decryption:
            return [.publicKey, .normal(extreme: false), .legacy]
        }
    }
}

class MainViewModel: ObservableObject {
    @Published var fileUrl: URL?
    @Published var saveUrl: URL?
    @Published var extremeKeyPath: URL?

    @Published var password: String = ""
    @Published var realKey = ""
    @Published var encryptionKeyUrl = ""

    @Published var shouldPresentError = false
    @Published var isLoading = false
    @Published var showStartOver = false
    @Published var errorMessage = ""
    var inDecryptionMode: Bool {
        return operationType == .decryption
    }

    @Published var operationMode: OperationMode = .normal(extreme: false)
    @Published var operationType = OperationType.encryption

    func resetUI() {
        showStartOver = false
        fileUrl = nil
        password = ""
        saveUrl = nil
        realKey = ""
        extremeKeyPath = nil
    }

    @Published var keysReady = false
    var keys: PairOfKeys?

    func getQRCodeDate(text: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        let data = text.data(using: .ascii, allowLossyConversion: false)
        filter.setValue(data, forKey: "inputMessage")
        guard let ciimage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciimage.transformed(by: transform)
        let rep = NSCIImageRep(ciImage: scaledCIImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }

    func generateKeyPair() {
        keys = Cryptor().generateKeyPair()
        keysReady = true
    }

    var shouldShowRealKey: Bool {
        if case let OperationMode.normal(extreme: extreme) = operationMode,
           extreme
        {
            return false
        }
        if operationMode == .publicKey {
            return false
        }
        return true
    }

    var showExtremeModeToggle: Bool {
        if case OperationMode.normal(extreme: _) = operationMode,
           operationType == .encryption
        {
            return true
        }
        return false
    }

    var cancallables: AnyCancellable?

    var filePath: String {
        fileUrl?.path ?? ""
    }

    var showActionButton: Bool {
        fileUrl != nil &&
            ![password.isEmpty, encryptionKeyUrl.isEmpty].allSatisfy { $0 == true } &&
            saveUrl == nil
    }

    var anyCancellable: [AnyCancellable] = []

    var dataManager: DataManager? {
        guard let fileUrl,
              let dm = try? DataManager(fileUrl: fileUrl, password: password, operationMode: operationMode, operationType: operationType)
        else { return nil }
        anyCancellable.append(
            dm.$isLoading
                .receive(on: DispatchQueue.main)
                .sink {
                    self.isLoading = $0
                })
        return dm
    }

    init(file: URL?) {
        fileUrl = file
        cancallables =
            $fileUrl.sink(receiveValue: {
                self.operationType = $0?.pathExtension == "safefile" ? .decryption : .encryption
                // Detecting key automatically
                if self.operationType == .decryption,
                   let key = self.dataManager?.getKey()
                {
                    self.realKey = key
                }
            })
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

    func onEncrypt() async {
        await MainActor.run {
            self.saveUrl = createTemporaryDirectoryURL()
        }

        do {
            switch operationMode {
            case .legacy:
                try await encryptUsingLegacy()
            default:
                try await encrypt()
            }
            await MainActor.run {
                self.showStartOver = true
            }
        } catch {
            print(error)
            await MainActor.run {
                self.errorMessage = Errors.failedEncryption.localizedDescription
                self.shouldPresentError = true
                self.isLoading = false
            }
        }
    }

    func onDecrypt() async {
        await MainActor.run {
            self.saveUrl = createTemporaryDirectoryURL()
        }

        do {
            switch operationMode {
            case .legacy:
                try await decryptUsingLegacy()
            default:
                try await decrypt()
            }
            await MainActor.run {
                self.showStartOver = true
            }
        } catch {
            print(error)
            await MainActor.run {
                self.errorMessage = Errors.failedDecryption.localizedDescription
                self.shouldPresentError = true
                self.isLoading = false
            }
        }
    }

    private func encryptUsingLegacy() async throws {
        guard let fileUrl,
              let saveUrl,
              let key = try? Cryptor().createWrappedKey(withPassword: password),
              !password.isEmpty
        else {
            throw Errors.failedEncryption
        }
        let keyStr = key.wrappedKey
        let cryptor = LegacyCryptor(password: password)

        await MainActor.run {
            isLoading = true
            realKey = keyStr.base64EncodedString()
        }
        try realKey.write(to: saveUrl
            .deletingPathExtension()
            .appendingPathExtension("key")
            .appendingPathExtension("txt"), atomically: true, encoding: .utf8)
        try cryptor.encryptpointer(key: key.encryptionKey, file: fileUrl, writeTo: saveUrl) {
            DispatchQueue.main.async {
                self.isLoading = false
                NSWorkspace.shared.selectFile(saveUrl.path, inFileViewerRootedAtPath: "")
            }
        }
    }

    private func decryptUsingLegacy() async throws {
        let cryptor = LegacyCryptor(password: password)
        guard let fileUrl else { return }
        guard
            !password.isEmpty,
            !realKey.isEmpty,
            let d = Data(base64Encoded: realKey)
        else {
            throw Errors.failedDecryption
        }
        await MainActor.run {
            isLoading = true
        }

        Task(priority: .userInitiated) {
            do {
                try cryptor.decryptPointer(file: fileUrl, key: d, writeTo: fileUrl.deletingPathExtension(), completion: { _ in
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }, progressHandler: { _ in
                })
            } catch {
                throw Errors.failedDecryption
            }
        }
//        try DispatchQueue.global(qos: .userInteractive).sync {
//
//        }
    }

    private func encrypt() async throws {
        guard let dataManager = self.dataManager else {
            throw Errors.failedEncryption
        }

        switch operationMode {
        case .publicKey:
            try await dataManager.encryptWithPublicKey(path: encryptionKeyUrl)
        case let .normal(extreme: extreme):
            guard let (filePath, KeyPath) = try await dataManager.encrypt(isExtreme: extreme) else {
                return
            }
            await MainActor.run {
                self.saveUrl = filePath
                self.extremeKeyPath = KeyPath
            }
        default:
            throw Errors.failedEncryption
        }
        await MainActor.run {
            self.isLoading = false
            NSWorkspace.shared.selectFile(saveUrl?.path, inFileViewerRootedAtPath: "")
        }
    }

    private func decrypt() async throws {
        guard let dataManager = self.dataManager else {
            throw Errors.failedDecryption
        }

        dataManager.realKey = realKey
        switch operationMode {
        case .publicKey:
            let url = try await dataManager.decryptWithPublicKey(path: encryptionKeyUrl)
            await MainActor.run {
                self.saveUrl = url
            }
        case let .normal(extreme):
            let url = try await dataManager.decrypt(isExtreme: extreme)
            await MainActor.run {
                self.saveUrl = url
            }
        default:
            throw Errors.failedDecryption
        }
        await MainActor.run {
            self.isLoading = false
        }
    }
}

extension MainViewModel {
    enum Errors: Error {
        case failedEncryption
        case failedDecryption
        case noSaveLocation

        var localizedDescription: String {
            switch self {
            case .noSaveLocation:
                return "Please choose location to save"
            case .failedDecryption:
                return "Decryption failed, make sure you are using the correct options"
            case .failedEncryption:
                return "Encryption failed, make sure you are using the correct options"
            }
        }
    }
}
