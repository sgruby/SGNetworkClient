//
//  NetworkRequest.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation


internal struct NetworkPreparedRequest {
    let data: Data?
    let tempFile: URL?
    let request: URLRequest
}

public class NetworkRequest {
    public typealias ProgressHandler = (Progress) -> Void
    public typealias RequestCompletedHandler = (URLResponse?, Error?) -> Void

    let method: HTTPMethod
    let path: String
    public var maxAttempts: Int {
        didSet {
            currentAttemptCount = maxAttempts
        }
    }
    
    public var currentAttemptCount: Int {
        didSet {
            uploadProgress.totalUnitCount = 0
            uploadProgress.completedUnitCount = 0
        }
    }

    public var queryItems: [URLQueryItem]?
    public var queryItemsPercentEncoded: Bool = false
    public var timeoutInterval: TimeInterval
    public var multipartBody: MultipartBody = MultipartBody(boundary: MultipartBoundary.boundaryString())
    public var credentials: URLCredential?
    public var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy?
    public var uploadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)?
    public var requestCompletedHandler: (handler: RequestCompletedHandler, queue: DispatchQueue)?

    var headers: [HTTPHeader] = []
    let body: Data?
    let logRequest: Bool
    let logResponse: Bool
    let uuid: UUID = UUID()
    let uploadProgress = Progress(totalUnitCount: 0)

    public init(method: HTTPMethod = .get, path: String, body: Data? = nil, maxAttempts: Int = 0, logRequest: Bool = true, logResponse: Bool = true) {
        self.method = method
        self.path = path
        self.maxAttempts = maxAttempts
        self.currentAttemptCount = maxAttempts
        self.logRequest = logRequest
        self.logResponse = logResponse
        self.body = body
        self.timeoutInterval = 0
    }
    
    // We're going to make all request be JSON
    public init<Body: Encodable>(method: HTTPMethod = .get, path: String, body: Body, maxAttempts: Int = 0, logRequest: Bool = true, logResponse: Bool = true) {
        self.method = method
        self.path = path
        self.maxAttempts = maxAttempts
        self.currentAttemptCount = maxAttempts
        self.logRequest = logRequest
        self.logResponse = logResponse
        if type(of: body) == Data.self || type(of: body) == Data?.self {
            if let data = body as? Data, data.isEmpty == false {
                self.body = data
            } else {
                self.body = nil
            }
        } else {
            self.body = try? JSONEncoder().encode(body)
            self.headers = [HTTPHeader(field: "Content-Type", value: HTTPContentType.json.rawValue)]
        }
        self.timeoutInterval = 0
    }
    
    public func add(header: String, for key: String) {
        headers.append(HTTPHeader(field: key, value: header))
    }

    func prepareURLRequest(with client: NetworkClient, alwaysWriteToFile: Bool = false) -> NetworkPreparedRequest? {
        var url: URL = client.baseURL

        // See if this is a full URL
        if let pathURL = URL(string: path), path.lowercased().hasPrefix("http") {
            url = pathURL
        } else if url.lastPathComponent.hasSuffix("/") == true && path.hasPrefix("/") {
            url.appendPathComponent(String(path.dropFirst()))
        } else {
            if path.hasPrefix("/") == true {
                // Ignore the path in the base URL
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
                components?.path = path
                if let componentURL = components?.url {
                    url = componentURL
                }
            } else {
                url.appendPathComponent(path)
            }
        }
        
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        // While it really doesn't make a difference, if there is an empty array
        // of query items, it appears that a ? is appended to the URL even though
        // it is not necessary.
        if let queryItems = queryItems, queryItems.isEmpty == false {
            if queryItemsPercentEncoded == true {
                urlComponents?.percentEncodedQueryItems = queryItems
            } else {
                urlComponents?.queryItems = queryItems
            }
        }
        
        guard let resolvedURL = urlComponents?.url else {return nil}
        
        var urlRequest: URLRequest = URLRequest(url: resolvedURL)
        urlRequest.httpMethod = method.rawValue.uppercased()
        urlRequest.httpBody = body
        if timeoutInterval == 0 {
            urlRequest.timeoutInterval = client.timeoutInterval
        } else {
            urlRequest.timeoutInterval = timeoutInterval
        }

        // Add the headers from the base client
        // These may be overwritten
        client.additionalHeaders.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.field) }

        headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.field) }

        var uploadData: Data?
        var tempFileURL: URL?

        if multipartBody.parts.isEmpty == false {
            var extraHeaders: [HTTPHeader] = []

            extraHeaders.append(HTTPHeader(field: "Content-Type", value: "multipart/form-data; boundary=\(multipartBody.boundary)"))

            // Over 10 MB, write to a file to be more memory efficient
            if multipartBody.contentLength < 10_000_000 && alwaysWriteToFile == false {
                if let data = prepareUploadData() {
                    var extraHeaders: [HTTPHeader] = []
                    extraHeaders.append(HTTPHeader(field: "Content-Length", value: "\(data.count)"))
                    uploadData = data
                }
            } else {
                tempFileURL = multipartBody.encodedTemporaryFile()
                var contentLength: UInt64 = 0
                if let tempFileURL = tempFileURL, let attributes = try? FileManager.default.attributesOfItem(atPath: tempFileURL.path), let size = attributes[.size] as? NSNumber {
                    contentLength = size.uint64Value
                }
                
                extraHeaders.append(HTTPHeader(field: "Content-Length", value: "\(contentLength)"))
            }

            extraHeaders.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.field) }
        }
        
        return NetworkPreparedRequest(data: uploadData, tempFile: tempFileURL, request: urlRequest)
    }
    
    private func prepareUploadData() -> Data? {
        guard multipartBody.parts.isEmpty == false else {return nil}

        return multipartBody.encodedData()
     }

    internal func updateUploadProgress(totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        uploadProgress.totalUnitCount = totalBytesExpectedToSend
        uploadProgress.completedUnitCount = totalBytesSent
        uploadProgressHandler?.queue.async { self.uploadProgressHandler?.handler(self.uploadProgress) }
    }

    internal func requestCompleted(response: URLResponse?, error: Error?) {
        requestCompletedHandler?.queue.async {self.requestCompletedHandler?.handler(response, error)}
    }
}
