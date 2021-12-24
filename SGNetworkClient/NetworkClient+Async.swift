//
//  NetworkClient+Async.swift
//  SGNetworkClient
//
//  Created by Scott Gruby on 11/9/21.
//

import Foundation

final class NetworkTaskWrapper { var task: NetworkTask? }

extension NetworkClient {
    public func perform(method: HTTPMethod = .get, for path: String) async throws -> (NetworkResponse<[String: Any]>) {
        let request = NetworkRequest(method: method, path: path, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request)
    }
    
    public func perform<T: Decodable>(method: HTTPMethod = .get, for path: String, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        return try await perform(method: method, for: path, body: Data(), resultKey: resultKey)
    }
    
    public func perform<T: Decodable, Body: Encodable>(method: HTTPMethod = .get, for path: String, body: Body, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        let request = NetworkRequest(method: method, path: path, body: body, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request, resultKey: resultKey)
    }
    
    public func perform<Body: Encodable>(method: HTTPMethod = .get, for path: String, body: Body) async throws -> (NetworkResponse<[String: Any]>) {
        let request = NetworkRequest(method: method, path: path, body: body, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request)
    }

    public func perform<T: Decodable>(request: NetworkRequest, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        let taskWrapper = NetworkTaskWrapper()

        return  try await withTaskCancellationHandler(handler: {
            taskWrapper.task?.cancel()
        }, operation: {
            try await withCheckedThrowingContinuation { continuation in
                taskWrapper.task = self.perform(request: request, resultType: T.self, resultKey: resultKey, completionQueue: DispatchQueue.global(qos: .background)) { response in
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
        })
    }

    public func perform(request: NetworkRequest) async throws -> (NetworkResponse<[String: Any]>) {
        let taskWrapper = NetworkTaskWrapper()
        return  try await withTaskCancellationHandler(handler: {
            taskWrapper.task?.cancel()
        }, operation: {
            try await withCheckedThrowingContinuation { continuation in
                taskWrapper.task = self.perform(request: request, completionQueue: DispatchQueue.global(qos: .background)) { response in
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
        })
    }
}
