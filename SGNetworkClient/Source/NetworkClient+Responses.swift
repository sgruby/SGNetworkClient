//
//  NetworkClient+Responses.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

extension NetworkClient {
    static func handleResponse<T: Decodable>(resultType: T.Type, resultKey: String? = nil, data: Data?, urlResponse: URLResponse?, error: Error?, task: NetworkTask?) -> (NetworkResponse<T>) {
        var returnError: Error?
        var result: T?
        if let error = error as? URLError, case URLError.cancelled = error {
            returnError = NetworkError.cancelled
        } else if let error = error {
            returnError = error
        } else if let httpResponse = urlResponse as? HTTPURLResponse {
            if httpResponse.statusCode / 200 == 1 {
                if let headerError = headerError(response: httpResponse) {
                    returnError = headerError
                } else {
                    // Parse the data
                    if let data = data {
                        if resultType == Data.self {
                            result = data as? T
                        } else {
                            let decoder = JSONKeyDecoder(key: resultKey)
                            do {
                                result = try decoder.decode(resultType, from: data)
                            } catch {
                                returnError = NetworkError.decodingFailure(data: data)
                            }
                        }
                    }
                }
            } else {
                switch httpResponse.statusCode {
                case 401:
                    returnError = NetworkError.unauthorized(response: httpResponse, body: data)
                    
                default:
                    returnError = NetworkError.failedResponse(statusCode: httpResponse.statusCode, response: httpResponse, body: data)
                }
            }
        }
        
        return NetworkResponse(error: returnError, httpResponse: urlResponse as? HTTPURLResponse, result: result, task: task)
    }

    static func handleResponse(data: Data?, urlResponse: URLResponse?, error: Error?, task: NetworkTask?) -> (NetworkResponse<[String: Any]>) {
        var returnError: Error?
        var result: [String: Any]?
        if let error = error as? URLError, case URLError.cancelled = error {
            returnError = NetworkError.cancelled
        } else if let error = error {
            returnError = error
        } else if let httpResponse = urlResponse as? HTTPURLResponse {
            if httpResponse.statusCode / 200 == 1 {
                if let headerError = headerError(response: httpResponse) {
                    returnError = headerError
                } else {
                    if httpResponse.statusCode == 204 {
                        result =  [:]
                    } else if let data = data {
                        // Not sure why we'd get an empty body, but protect against it
                        if data.isEmpty == true {
                            result = [:]
                        }

                        result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
                    } else {
                        result = [:]
                    }
                }
            } else {
                switch httpResponse.statusCode {
                case 401:
                    returnError = NetworkError.unauthorized(response: httpResponse, body: data)
                    
                default:
                    returnError = NetworkError.failedResponse(statusCode: httpResponse.statusCode, response: httpResponse, body: data)
                }
            }
        }
        
        return NetworkResponse(error: returnError, httpResponse: urlResponse as? HTTPURLResponse, result: result, task: task)
    }

    internal func shouldRetry(request: NetworkRequest, error: Error?) -> Bool {
        if let error = error, error.isTransientNetworkingError() || error.is503ServiceUnavailable(), request.currentRetryCount > 1 {
            return true
        }
        return false
    }
}
