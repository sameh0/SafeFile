# SafeFile - Secure File Encryption for Mac

SafeFile is an open-source project that implements file encryption on macOS using Swift, leveraging advanced cryptographic techniques for superior data security.

## Features

* **AES-256 Encryption**: Built with Swift's CryptoKit, SafeFile provides AES-256 encryption, one of the most secure encryption standards available today.
* **Seal Boxes**: SafeFile uses sealed boxes for encapsulating encrypted data and the associated nonce, which prevents any alteration of the data after encryption.
* **End-to-End Encryption**: SafeFile implements end-to-end encryption, ensuring that only the sender and receiver can read the data.
* **Curve25519**: uses the elliptic curve Curve25519 for generating public and private keys, a widely recognized standard in the field of cryptography.
* **HKDF Derived Symmetric Key**: Hashed Key Derivation Function (HKDF) is used for deriving symmetric keys, providing enhanced security.

## Download the App

SafeFile is available on the App Store. Download it [here](https://apps.apple.com/eg/app/safefile/id6447214406).

## Future Plans

1. **UI Refactoring**: I aim to refactor the user interface for a more responsive and intuitive user experience.
2. **Testability Enhancement**: Improving unit test coverage to increase the reliability of the codebase.

Contributions to facilitate these developments are welcomed and greatly appreciated.

## Contribute

Forks and Pull Requests are always welcome! If you're interested in contributing to the codebase, enhancing the UI, or improving testability, I'd be delighted to see your work.

Together, let's make SafeFile the benchmark for file encryption on Mac.
