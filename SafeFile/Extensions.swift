//
//  NewCryptor.swift
//  SafeFile
//
//  Created by Sameh Sayed on 10/20/22.
//

import Foundation

extension Encodable {
    func encode() -> Data? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try? encoder.encode(self)
    }
}

extension Data {
    func getObject<T: Decodable>() -> T? {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            let parsedData = try decoder.decode(T.self, from: self)
            return parsedData
        } catch {
            print(error)
        }
        return nil
    }
}
