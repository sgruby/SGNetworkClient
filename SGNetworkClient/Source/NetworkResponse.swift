//
//  NetworkResponse.swift
//  SGNetworkClient
//
//  Created by Scott Gruby on 4/28/21.
//

import Foundation

public struct NetworkResponse<T> {
    public let error: Error?
    public let httpResponse: HTTPURLResponse?
    public let result: T?
}
