//
//  HTTPStructures.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/24/21.
//

import Foundation

public enum HTTPMethod: String {
    case get
    case put
    case post
    case patch
    case delete
    case head
    case options
    case trace
    case connect
}

enum HTTPContentType: String {
    case json = "application/json"
    case html = "text/html"
}

public struct HTTPHeader {
    let field: String
    let value: String
}
