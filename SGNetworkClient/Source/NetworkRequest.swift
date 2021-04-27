//
//  NetworkRequest.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/24/21.
//

import Foundation


internal struct NetworkPreparedRequest {
    let data: Data?
    let request: URLRequest
}

public class NetworkRequest {
    let method: HTTPMethod
    let path: String
    public var retryCount: Int
    public var queryItems: [URLQueryItem]?
    public var queryItemsPercentEncoded: Bool = false
    public var headers: [HTTPHeader]?
    let body: Data?
    public var timeoutInterval: TimeInterval
    let logRequest: Bool
    let logResponse: Bool
    public var dataToUpload: [MIMEData]?
    public var credentials: URLCredential?
    let uuid: UUID = UUID()

    lazy var boundaryString: String = {
        var str = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? ""
        let length = arc4random_uniform(11) + 30
        let charSet = [Character]("-_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        
        for _ in 0..<length {
            str.append(charSet[Int(arc4random_uniform(UInt32(charSet.count)))])
        }
        return str
    } ()
    
    public init(method: HTTPMethod = .get, path: String, retryCount: Int = 0, logRequest: Bool = true, logResponse: Bool = true) {
        self.method = method
        self.path = path
        self.retryCount = retryCount
        self.logRequest = logRequest
        self.logResponse = logResponse
        self.body = nil
        self.dataToUpload = nil
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
        self.dataToUpload = nil
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
        let preparedUploadData = prepareUploadData()
        if let data = preparedUploadData {
            var extraHeaders: [HTTPHeader] = []
            extraHeaders.append(HTTPHeader(field: "Content-Type", value: "multipart/form-data; boundary=\(boundaryString)"))
            extraHeaders.append(HTTPHeader(field: "Content-Length", value: "\(data.count)"))
            extraHeaders.forEach { urlRequest.addValue($0.value, forHTTPHeaderField: $0.field) }
        }

        return NetworkPreparedRequest(data: preparedUploadData, request: urlRequest)
    }
    
    private func prepareUploadData() -> Data? {
        guard let data = dataToUpload, data.isEmpty == false else {return nil}

        var uploadData: Data = Data()
        
        // Build up the data
        
        for item in data where item.data.count > 0 {
            let beginBoundary = "\r\n--\(boundaryString)\r\n"
            uploadData.append(beginBoundary.data(using: String.Encoding.utf8) ?? Data())

            var disposition = "Content-Disposition: form-data; name=\"\(item.name)\""
            if let filename = item.filename {
                disposition += "; filename=\"\(filename)\""
            }

            disposition += "\r\n"

            uploadData.append(disposition.data(using: String.Encoding.utf8) ?? Data())

            let contentType = "Content-Type: \(item.contentType)\r\n\r\n"
            uploadData.append(contentType.data(using: String.Encoding.utf8) ?? Data())

            uploadData.append(item.data)
        }
        
        let endBoundary = "\r\n--\(boundaryString)--\r\n"
        uploadData.append(endBoundary.data(using: String.Encoding.utf8) ?? Data())
        
        return uploadData
     }
}
