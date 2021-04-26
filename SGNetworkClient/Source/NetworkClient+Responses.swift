//
//  NetworkClient+Responses.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/26/21.
//

import Foundation

extension NetworkClient {
    func handleResponse<T: Decodable>(resultType: T.Type, resultKey: String? = nil, data: Data?, urlResponse: URLResponse?, error: Error?) -> (result: T?, error: Error?) {
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
        
        return(result, returnError)
    }

    internal func shouldRetry(request: NetworkRequest, error: Error?) -> Bool {
        if let error = error, error.isTransientNetworkingError() || error.is503ServiceUnavailable(), request.retryCount > 0 {
            return true
        }
        return false
    }
}
