//
//  NetworkClient+Logging.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/25/21.
//

import Foundation

extension NetworkClient {
    internal func log(request: URLRequest) {
        var requestString = "\n------------- Request --------------------\n"
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
        
        requestString += "\n----------------------------------------\n"
        requestLogger?(requestString)
    }

    internal func log(urlResponse: URLResponse?, data: Data?, error: Error?) {
        var responseString = "\n---------------------- Response ----------------------\n"

        if let response = urlResponse as? HTTPURLResponse {
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
        responseLogger?(responseString)
    }
}
