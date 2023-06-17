//
//  DataManager.swift
//  SafeFile
//
//  Created by Sameh Sayed on 3/11/23.
//

import AppKit
import Combine
import CryptoKit
import Foundation

class DataManager {
    let operationMode: OperationMode
    let operationType: OperationType
    let password: String
    let filePreparer: FilePreparer

    @Published var isLoading = false
    @Published var realKey = ""

    init(fileUrl: URL, password: String, operationMode: OperationMode, operationType: OperationType) throws {
        self.operationMode = operationMode
        self.password = password
        self.operationType = operationType
        filePreparer = try .init(sourcePath: fileUrl, operation: operationType)
    }

    func encryptWithPublicKey(path: String) async throws {
        let publicKeyPath = URL(fileURLWithPath: path)
        let publicKeyData = try Data(contentsOf: publicKeyPath)

        guard let firstPartyPublicKey = Data(base64Encoded: publicKeyData) else {
            throw MainViewModel.Errors.failedEncryption
        }
        let keychain = try Cryptor().createWrappedKey(withKey: firstPartyPublicKey)

        isLoading = true

        let header = SafeFileHeader(partSize: SafeFileHeader.partSize, extension: filePreparer.sourcePath.pathExtension, fileVersion: fileVersion, embeddedKey: keychain.base64secondPartyPublicKey, salt: keychain.salt)
        let encryptedHeader = try SafeFileHeaderEncryptor(header: header, password: keychain.base64FirstPublicKey, operationMode: operationMode)
        let cryptor = SafeEncryptor(filePreparer: filePreparer, encryptionKey: keychain.encryptionKey, header: encryptedHeader)
        try await cryptor.encrypt()
    }

    func decryptWithPublicKey(path: String) async throws -> URL? {
        let filePath = URL(fileURLWithPath: path)
        let dataForPath = try Data(contentsOf: filePath)
        guard
            !path.isEmpty,
            let privateKeyData = Data(base64Encoded: dataForPath)
        else {
            throw MainViewModel.Errors.failedDecryption
        }
        let publicKey = try Cryptor().getPublicKey(privateKey: privateKeyData)
        let keyStr = publicKey.base64EncodedString()
        guard let headerEncryptionKey = Cryptor().getPasswordHash(password: keyStr) else {
            throw MainViewModel.Errors.failedDecryption
        }

        let header = try SafeFileHeaderDecryptor(fileURL: filePreparer.sourcePath, key: headerEncryptionKey)
        filePreparer.decryptionExt(ext: header.header.extension)
        guard let includedPublicKey = Data(base64Encoded: header.header.embeddedKey ?? ""),
              let salt = header.header.salt
        else {
            return nil
        }

        let unwrapUserKey = try Cryptor().unWrapUserKey(chain: .init(privateKey: privateKeyData, publicKey: includedPublicKey, salt: salt))
        let decryptor = SafeDecryptor(filePreparer: filePreparer, decryptionKey: unwrapUserKey, header: header)

        await MainActor.run {
            isLoading = true
        }

        try await Task {
            try await decryptor.decrypt()
        }
        .result
        .get()

        return filePreparer.destinationPath
    }

    func encrypt(isExtreme: Bool) async throws -> (URL?, URL?)? {
        guard let key = try? Cryptor().createWrappedKey(withPassword: password),
              !password.isEmpty,
              let keySavePath = filePreparer.keyPath
        else {
            throw MainViewModel.Errors.failedEncryption
        }

        await MainActor.run {
            isLoading = true
            realKey = key.base64WrappedKey
        }
        var wrappedKey: String? = realKey

        if isExtreme {
            try realKey.write(to: keySavePath, atomically: true, encoding: .utf8)
            wrappedKey = nil
        }

        let header = SafeFileHeader(partSize: SafeFileHeader.partSize, extension: filePreparer.sourcePath.pathExtension, fileVersion: fileVersion, embeddedKey: wrappedKey, salt: nil)
        let encryptedHeader = try SafeFileHeaderEncryptor(header: header, password: password, key: key.encryptionKey, operationMode: operationMode)
        let cryptor = SafeEncryptor(filePreparer: filePreparer, encryptionKey: key.encryptionKey, header: encryptedHeader)
        try await cryptor.encrypt()
        return (filePreparer.destinationPath, isExtreme ? filePreparer.keyPath : nil)
    }

    func decrypt(isExtreme _: Bool) async throws -> URL? {
        guard !password.isEmpty
        else {
            throw MainViewModel.Errors.failedDecryption
        }

        var header: SafeFileHeaderDecryptor?

        let encryptionKey: SymmetricKey? = try {
            if let fileKey = getKey(),
               let keyData = Data(base64Encoded: fileKey)
            {
                return try Cryptor().unWrapUserKey(withPassword: password, key: keyData)
            } else if let headerEncryptionKey = Cryptor().getPasswordHash(password: password) {
                // key in header - isExtreme = false
                header = try .init(fileURL: filePreparer.sourcePath, key: headerEncryptionKey)
                if let keyData = Data(base64Encoded: header?.header.embeddedKey ?? "") {
                    return try Cryptor().unWrapUserKey(withPassword: password, key: keyData)
                }
            }
            return nil
        }()

        guard let encryptionKey else {
            throw MainViewModel.Errors.failedDecryption
        }

        if header == nil {
            header = try .init(fileURL: filePreparer.sourcePath, key: encryptionKey)
        }

        if let ext = header?.header.extension {
            filePreparer.decryptionExt(ext: ext)
        }

        let decryptor = SafeDecryptor(filePreparer: filePreparer, decryptionKey: encryptionKey, header: header!)
        await MainActor.run {
            isLoading = true
        }

        try await Task {
            try await decryptor.decrypt()
        }
        .value

        return filePreparer.destinationPath
    }

    func getKey() -> String? {
        guard let fileKey = filePreparer.keyPath else {
            return nil
        }

        let strKey = try? String(contentsOf: fileKey, encoding: .utf8)
        let realKey = strKey ?? realKey

        if realKey.isEmpty {
            return nil
        }

        return realKey
    }

    deinit {
        print("dinited")
    }
}
