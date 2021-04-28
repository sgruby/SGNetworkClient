//
//  NetworkRequest.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/24/21.
//

import Foundation


internal struct NetworkPreparedRequest {
    let data: Data?
    let tempFile: URL?
    let request: URLRequest
}

public class NetworkRequest {
    public typealias ProgressHandler = (Progress) -> Void

    let method: HTTPMethod
    let path: String
    public var retryCount: Int {
        didSet {
            uploadProgress.totalUnitCount = 0
            uploadProgress.completedUnitCount = 0
        }
    }

    public var queryItems: [URLQueryItem]?
    public var queryItemsPercentEncoded: Bool = false
    public var headers: [HTTPHeader]?
    let body: Data?
    public var timeoutInterval: TimeInterval
    let logRequest: Bool
    let logResponse: Bool
    public var multipartBody: MultipartBody = MultipartBody(boundary: MultipartBoundary.boundaryString())
    public var credentials: URLCredential?
    let uuid: UUID = UUID()

    var uploadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)?
    public let uploadProgress = Progress(totalUnitCount: 0)

    public init(method: HTTPMethod = .get, path: String, retryCount: Int = 0, logRequest: Bool = true, logResponse: Bool = true) {
        self.method = method
        self.path = path
        self.retryCount = retryCount
        self.logRequest = logRequest
        self.logResponse = logResponse
        self.body = nil
        self.timeoutInterval = 0
    }
    
    // We're going to make all request be JSON
    public init<Body: Encodable>(method: HTTPMethod = .get, path: String, body: Body, retryCount: Int = 0, logRequest: Bool = true, logResponse: Bool = true) {
        self.method = method
        self.path = path
        self.retryCount = retryCount
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

    func prepareURLRequest(with client: NetworkClient) -> NetworkPreparedRequest? {
        var url: URL = client.baseURL
        // Protect against an extra trailing or leading slash
        if url.lastPathComponent.hasSuffix("/") == true && path.hasPrefix("/") {
            url.appendPathComponent(String(path.dropFirst()))
        } else {
            url.appendPathComponent(path)
        }
        
        // See if this is a full URL
        if let pathURL = URL(string: path), path.lowercased().hasPrefix("http") {
            url = pathURL
        }
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if queryItemsPercentEncoded == true {
            urlComponents?.percentEncodedQueryItems = queryItems
        } else {
            urlComponents?.queryItems = queryItems
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

        headers?.forEach { urlRequest.addValue($0.value, forHTTPHeaderField: $0.field) }
        
        var uploadData: Data?
        var tempFileURL: URL?
        var extraHeaders: [HTTPHeader] = []

        extraHeaders.append(HTTPHeader(field: "Content-Type", value: "multipart/form-data; boundary=\(multipartBody.boundary)"))

        // Over 10 MB, write to a file to be more memory efficient
        if multipartBody.contentLength < 10_000_000 {
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

        extraHeaders.forEach { urlRequest.addValue($0.value, forHTTPHeaderField: $0.field) }

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
}
