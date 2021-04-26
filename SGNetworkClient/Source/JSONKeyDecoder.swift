//
//  JSONKeyDecoder.swift
//  RetailX
//
//  Created by Scott Gruby on 3/9/21.
//  Copyright © 2021 The Reformation. All rights reserved.
//

import Foundation

public class JSONKeyDecoder: JSONDecoder {
    private let key: String?
    public init(key: String? = nil) {
        self.key = key
    }

    public func decode(from data: Data) throws -> Data {
        return data
    }
    public override func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        if let key = key, let keyData = jsonDataFor(key: key, from: data) {
            return try super.decode(type, from: keyData)
        } else if let key = key {
            return try dataFor(key: key, from: data)
        }
        
        return try super.decode(type, from: data)
    }
    
    private func jsonDataFor(key: String, from data: Data) -> Data? {
        if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            // See if the key exists in the dictionary, encode the dictionary as JSON
            if let subDict = dict[key], JSONSerialization.isValidJSONObject(subDict) == true {
                if let newData = try? JSONSerialization.data(withJSONObject: subDict, options: []) {
                    // Re-parse the new data which is the original data using the key
                    return newData
                }
            }
        }
        return nil
    }
    
    private func dataFor<T: Decodable>(key: String?, from data: Data) throws -> T {
        if let key = key, let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let result = dict[key] as? T {
                return result
            }
        }
        
        throw NetworkError.decodingFailure(data: nil)
    }
}
