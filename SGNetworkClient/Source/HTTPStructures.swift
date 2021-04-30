//
//  HTTPStructures.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

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
