//
//  NetworkClient+Async.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.


import Foundation

#if compiler(>=5.5) && canImport(_Concurrency)
final class NetworkTaskWrapper { var task: NetworkTask? }

extension NetworkClient {
    public func perform(method: HTTPMethod = .get, for path: String) async throws -> (NetworkResponse<[String: Any]>) {
        let request = NetworkRequest(method: method, path: path, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request)
    }
    
    public func perform<T: Decodable>(method: HTTPMethod = .get, for path: String, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        return try await perform(method: method, for: path, body: Data(), resultKey: resultKey)
    }
    
    public func perform<T: Decodable, Body: Encodable>(method: HTTPMethod = .post, for path: String, body: Body, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        let request = NetworkRequest(method: method, path: path, body: body, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request, resultKey: resultKey)
    }
    
    public func perform<Body: Encodable>(method: HTTPMethod = .post, for path: String, body: Body) async throws -> (NetworkResponse<[String: Any]>) {
        let request = NetworkRequest(method: method, path: path, body: body, logRequest: logRequests, logResponse: logResponses)
        return try await perform(request: request)
    }

    public func perform<T: Decodable>(request: NetworkRequest, resultKey: String? = nil) async throws -> (NetworkResponse<T>) {
        let taskWrapper = NetworkTaskWrapper()

        return  try await withTaskCancellationHandler(handler: {
            taskWrapper.task?.cancel()
        }, operation: {
            try await withCheckedThrowingContinuation { continuation in
                let result: ((NetworkResponse<T>) -> Void) = {response in
                    if let error = response.error {
                        return continuation.resume(throwing: error)
                    } else {
                        return continuation.resume(returning: response)
                    }
                }
                
                taskWrapper.task = self.perform(request: request, resultKey: resultKey, completionQueue: DispatchQueue.global(qos: .background), completionHandler: result)
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
                    if let error = response.error {
                        return continuation.resume(throwing: error)
                    } else {
                        return continuation.resume(returning: response)
                    }
                }
            }
        })
    }
}
#endif
