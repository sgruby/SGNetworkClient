//
//  NetworkClient+Logging.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

extension NetworkClient {
    internal func log(preparedRequest: NetworkPreparedRequest, totalAttemptCount: Int, currentAttempt: Int) {
        let request = preparedRequest.request
        var requestString = "\n------------- Request -------------\n"
        requestString += "---------- Attempt \(totalAttemptCount - currentAttempt + 1) of \(totalAttemptCount > 0 ? totalAttemptCount : 1) ----------\n"
        requestString += request.httpMethod ?? "UNKNOWN"
        requestString += " "
        requestString += request.url?.absoluteString ?? "UNKNOWN URL"
        requestString += "\n"

        var headerFields: [String: String] = [:]

        if let headers = urlSessionConfiguration.httpAdditionalHeaders {
            for (key, value) in headers {
                if let key = key as? String, let value = value as? String {
                    headerFields[key] = value
                }
            }
        }

        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                headerFields[key] = value
            }
        }

        for (key, value) in headerFields {
            requestString += key + ": " + value + "\n"
        }

        requestString += "\n"

        if let body = request.httpBody, let str = String(data: body, encoding: String.Encoding.utf8) {
            requestString += str
        }
        
        if preparedRequest.data != nil {
            requestString += "*** Request contains Multipart data (not displaying) ***"
        } else if let fileURL = preparedRequest.tempFile {
            requestString += "Request contains Multipart data stored in a file: \(fileURL.path)"
        }
        
        requestString += "\n----------------------------------------\n"
        requestLogger?(requestString)
    }
    
    internal func log(task: URLSessionDataTask, response: URLResponse?, data: Data?) {
        dataTaskLogger?(task, response, data)
    }
    
    internal func log(task: URLSessionTask, error: Error?) {
        taskCompleteLogger?(task, error)
    }
    
    internal func log(task: URLSessionTask, metrics: URLSessionTaskMetrics) {
        metricsLogger?(task, metrics)
    }

    internal func log(urlResponse: URLResponse?, data: Data?, error: Error?) {
        var responseString = "\n---------------------- Response ----------------------\n"
        var success: Bool = false
        
        if let response = urlResponse as? HTTPURLResponse {
            if response.statusCode / 200 == 1 {
                success = true
            }
            
            responseString += "\(response.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))\n"
            if let url = response.url {
                responseString += url.absoluteString + "\n\n"
            }

            if let mimeType = response.mimeType {
                responseString += "Content-Type: \(mimeType)\n"
            }

            for (key, value) in response.allHeaderFields {
                if let key = key as? String, let value = value as? String {
                    responseString += key + ": " + value + "\n"
                }
            }
        }
        
        if let error = error {
            if let urlError = error as? URLError, let urlString = urlError.failureURLString {
                responseString += urlString + "\n\n"
            } else if let url = urlResponse?.url {
                responseString += url.absoluteString + "\n\n"
            }
            responseString += "\n" + error.localizedDescription + "\n"
        }

        responseString += "\n"

        if let data = data, let str = String(data: data, encoding: .utf8) {
            responseString += str
        }

        responseString += "\n----------------------------------------\n"
        responseLogger?(responseString, success)
    }
}
