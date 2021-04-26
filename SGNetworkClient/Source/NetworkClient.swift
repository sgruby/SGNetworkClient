//
//  NetworkClient.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/24/21.
//

// TODO

// Upload file

import Foundation

open class NetworkClient: NSObject, URLSessionTaskDelegate {
    internal var networkTasks = Set<NetworkTask>()
    internal let baseURL: URL
    internal var urlSessionConfiguration: URLSessionConfiguration {
        // if the configuration changes, we need to update the session
        didSet {
            setupURLSession()
        }
    }
    public var responseLogger: ((String) -> Void)?
    public var requestLogger: ((String) -> Void)?
    public var logRequests: Bool = false
    public var logResponses: Bool = false
    public var completionQueue: OperationQueue = .main

    var userAgent: String? {
        get {
            (urlSessionConfiguration.httpAdditionalHeaders?.first {($0.key as? String) == "User-Agent"})?.value as? String
        }
        
        set {
            if let newValue = newValue {
                addHTTP(header: newValue, for: "User-Agent")
            } else {
                removeHTTPHeaderFor(key: "User-Agent")
            }
        }
    }
    
    var timeoutInterval: TimeInterval = 0
    var retryCount: Int = 0
    internal lazy var urlSession: URLSession = {
        return URLSession(configuration: urlSessionConfiguration,
                          delegate: self,
                          delegateQueue: completionQueue)
    }()

    private func setupURLSession() {
        urlSession = URLSession(configuration: urlSessionConfiguration,
                                delegate: self,
                                delegateQueue: OperationQueue.main)
    }
    
    public init(baseURL: URL, configuration: URLSessionConfiguration? = nil) {
        self.baseURL = baseURL
        self.timeoutInterval = 120
        let config = configuration ?? URLSessionConfiguration.default
        var headers = config.httpAdditionalHeaders ?? [:]
        headers["User-Agent"] = NetworkClient.defaultUserAgent
        config.httpAdditionalHeaders = headers
        urlSessionConfiguration = config
    }
    
    public func addHTTP(header: String, for key: String) {
        let config = urlSessionConfiguration
        var headers = config.httpAdditionalHeaders ?? [:]
        headers[key] = header
        config.httpAdditionalHeaders = headers
        urlSessionConfiguration = config
    }

    public func removeHTTPHeaderFor(key: String) {
        let config = urlSessionConfiguration
        var headers = config.httpAdditionalHeaders ?? [:]
        headers[key] = nil
        config.httpAdditionalHeaders = headers
        urlSessionConfiguration = config
    }
    
    // Reset everything
    public func cancelAllRequests() {
        urlSession.finishTasksAndInvalidate()
        urlSession = URLSession(configuration: urlSessionConfiguration)
        networkTasks.removeAll()
    }

    func networkTask(for task: URLSessionTask) -> NetworkTask? {
        return (networkTasks.first {$0.dataTask == task})
    }

    func networkTask(for uuid: UUID) -> NetworkTask? {
        return (networkTasks.first {$0.networkRequest.uuid == uuid})
    }
    
    func removeTask(_ task: NetworkTask) {
        networkTasks.remove(task)
    }
    
    // Not called when the call is made with a closure
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    }

    // Some stupid servers return 200 responses, but embed the errors in the header
    // Let this method be overwritten if required
    open func headerError(response: HTTPURLResponse) -> Error? {
        var networkError: NetworkError?
        var flashMessages = (response.allHeaderFields.first {($0.key as? String)?.lowercased() == "x-flash-messages"})?.value as? String
        if flashMessages != nil {
            flashMessages = flashMessages?.replacingOccurrences(of: "\\u0026quot;", with: "\"")
            flashMessages = flashMessages?.replacingOccurrences(of: "\"[", with: "[")
            flashMessages = flashMessages?.replacingOccurrences(of: "]\"", with: "]")
            if let jsonData = flashMessages?.data(using: .utf8) {
                if let messsages = try? JSONSerialization.jsonObject(with: jsonData) as? [String: [String]], messsages["error"] != nil {
                    networkError = NetworkError.failedResponse(statusCode: response.statusCode, response: response, body: jsonData)
                }
            }
        }
        
        return networkError
    }
}
