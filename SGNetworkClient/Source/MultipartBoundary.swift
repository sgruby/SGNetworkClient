//
//  MultipartBoundary.swift
//  SGNetworkClient
//
//  Created by Scott Gruby on 4/28/21.
//

import Foundation

internal struct MultipartBoundary {
    enum BoundaryType {
        case initial
        case encapsulated
        case last
    }
    
    static func boundaryString() -> String {
        var str = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? ""
        let length = arc4random_uniform(11) + 15
        let charSet = [Character]("-_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        
        str += "."
        
        for _ in 0..<length {
            str.append(charSet[Int(arc4random_uniform(UInt32(charSet.count)))])
        }
        return str
    }
    
    static func boundary(for boundaryType: BoundaryType, boundary: String) -> Data {
        let text: String
        
        switch boundaryType {
        case .initial:
            text = "--\(boundary)\r\n"
        case .encapsulated:
            text = "\r\n--\(boundary)\r\n"
        case .last:
            text = "\r\n--\(boundary)--\r\n"
        }
        
        return Data(text.utf8)
    }
}
