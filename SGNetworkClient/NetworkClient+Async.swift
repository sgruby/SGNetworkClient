//
//  NetworkClient+Async.swift
//  SGNetworkClient
//
//  Created by Scott Gruby on 11/9/21.
//

import Foundation

extension NetworkClient {
    public func perform(method: HTTPMethod = .get, for path: String) async throws -> (NetworkResponse<[String: Any]>) {
        let request = NetworkRequest(method: method, path: path, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request)
    }
    
    public func performAndReturnData(method: HTTPMethod = .get, for path: String) async throws -> (NetworkResponse<Data>) {
        let request = NetworkRequest(method: method, path: path, logRequest: logRequests, logResponse: logResponses)
        return try await performAndReturnData(request: request)
    }

    public func perform<T: Decodable>(method: HTTPMethod = .get, for path: String, resultType: T.Type, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        return try await perform(method: method, for: path, body: Data(), resultType: resultType, resultKey: resultKey)
    }
    
    public func perform<T: Decodable, Body: Encodable>(method: HTTPMethod = .get, for path: String, body: Body, resultType: T.Type, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        let request = NetworkRequest(method: method, path: path, body: body, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request, resultType: resultType, resultKey: resultKey)
    }
    
    public func perform<Body: Encodable>(method: HTTPMethod = .get, for path: String, body: Body) async throws -> (NetworkResponse<[String: Any]>) {
        let request = NetworkRequest(method: method, path: path, body: body, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request)
    }

    public func performAndReturnData(request: NetworkRequest) async throws -> (NetworkResponse<Data>) {
        return try await perform(request: request, resultType: Data.self)
    }

    public func perform<T: Decodable>(request: NetworkRequest, resultType: T.Type, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        try await withCheckedThrowingContinuation { continuation in
            self.perform(request: request, resultType: resultType, resultKey: resultKey, completionQueue: DispatchQueue.global(qos: .background)) { response in
                if let response = response {
                    if let error = response.error {
                        return continuation.resume(throwing: error)
                    } else {
                        return continuation.resume(returning: response)
                    }
                } else {
                    return continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
        }
    }

    public func perform(request: NetworkRequest) async throws -> (NetworkResponse<[String: Any]>) {
        try await withCheckedThrowingContinuation { continuation in
            self.perform(request: request, completionQueue: DispatchQueue.global(qos: .background)) { response in
                if let response = response {
                    if let error = response.error {
                        return continuation.resume(throwing: error)
                    } else {
                        return continuation.resume(returning: response)
                    }
                } else {
                    return continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
        }
    }
}
