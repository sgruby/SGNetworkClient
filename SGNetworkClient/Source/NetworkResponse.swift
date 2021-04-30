//
//  NetworkResponse.swift
//  SGNetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

public struct NetworkResponse<T> {
    public let error: Error?
    public let httpResponse: HTTPURLResponse?
    public let result: T?
}
