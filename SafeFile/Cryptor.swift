//
//  Cryptor.swift
//  SafeFile
//
//  Created by Sameh Sayed on 7/7/22.
//

import CryptoKit
import Foundation

protocol CryptorChain {
    var encryptionKey: SymmetricKey { get }
}

struct PairOfKeys {
    let publicKey: Data
    let privateKey: Data
}

struct KeybasedChain: CryptorChain {
    let encryptionKey: SymmetricKey
    let secondPartyPublicKey: Data // embedded
    let firstPartyPublicKey: Data
    let salt: String

    var base64FirstPublicKey: String {
        firstPartyPublicKey.base64EncodedString()
    }

    var base64secondPartyPublicKey: String {
        secondPartyPublicKey.base64EncodedString()
    }
}

struct PassbasedChain: CryptorChain {
    let encryptionKey: SymmetricKey
    let wrappedKey: Data

    var base64WrappedKey: String {
        wrappedKey.base64EncodedString()
    }
}

struct Cryptor {
    enum Errors: Error {
        case keyGenerationFailed
        case keyReterivalFailed
    }

    struct DecryptionChain {
        let privateKey: Data
        let publicKey: Data // Stored in the header
        let salt: String
    }

    func createWrappedKey(withPassword: String) throws -> PassbasedChain {
        guard
            let passKey = getPasswordHash(password: withPassword)
        else {
            throw Errors.keyGenerationFailed
        }

        let realKey = SymmetricKey(size: .bits256)
        let wrappedKey = try AES.KeyWrap.wrap(realKey, using: passKey)
        return .init(encryptionKey: realKey, wrappedKey: wrappedKey)
    }

    func createWrappedKey(withKey: Data) throws -> KeybasedChain {
        let firstPartyPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: withKey)

        // A temp private key is generated and the public is attached to the request it self to be used in future decipher . since Curve25519 can't accept one public key for encryption.
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: firstPartyPublicKey)
        let secondPartyPublicKey = privateKey.publicKey
        let saltStr = UUID().uuidString

        guard let saltData = saltStr.data(using: .utf8) else {
            throw Errors.keyGenerationFailed
        }

        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA512.self,
            salt: saltData,
            sharedInfo: Data(),
            outputByteCount: 32
        )

        return .init(encryptionKey: symmetricKey,
                     secondPartyPublicKey: secondPartyPublicKey.rawRepresentation,
                     firstPartyPublicKey: firstPartyPublicKey.rawRepresentation,
                     salt: saltStr)
    }

    func unWrapUserKey(chain: DecryptionChain) throws -> SymmetricKey {
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: chain.privateKey)
        let userPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: chain.publicKey)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: userPublicKey)

        guard let saltData = chain.salt.data(using: .utf8) else {
            throw Errors.keyGenerationFailed
        }

        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA512.self,
            salt: saltData,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        return symmetricKey
    }

    func getPublicKey(privateKey: Data) throws -> Data {
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        return privateKey.publicKey.rawRepresentation
    }

    func unWrapUserKey(withPassword: String, key: Data) throws -> SymmetricKey {
        guard let password = getPasswordHash(password: withPassword)
        else {
            throw Errors.keyGenerationFailed
        }
        let passKey = SymmetricKey(data: password)
        return try AES.KeyWrap.unwrap(key, using: passKey)
    }

    func getPasswordHash(password: String) -> SymmetricKey? {
        guard let passData = password.data(using: .utf8) else {
            return nil
        }
        let hash = SHA256.hash(data: passData)
        let hashData = Data(hash)
        return SymmetricKey(data: hashData)
    }

    func encrypt(data: Data, key: SymmetricKey) throws -> AES.GCM.SealedBox {
        let encryptedData = try AES.GCM.seal(data, using: key)
        return encryptedData
    }

    func decrypt(data: AES.GCM.SealedBox, key: SymmetricKey) throws -> Data {
        return try AES.GCM.open(data, using: key)
    }

    func generateKeyPair() -> PairOfKeys {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        return .init(publicKey: publicKey.rawRepresentation, privateKey: privateKey.rawRepresentation)
    }
}
