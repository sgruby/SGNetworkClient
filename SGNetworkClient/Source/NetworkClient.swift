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
    // The networkTasks can be accessed on multiple threads,
    // so we have to be careful when we access it and use
    // the lockingQueue to handle that
    internal var networkTasks = Set<NetworkTask>()
    internal let lockingQueue: DispatchQueue = DispatchQueue.init(label: "com.grubysolutions.networkclient.lock")

    public var baseURL: URL
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
    public var completionQueue: DispatchQueue = .main

    public var userAgent: String? {
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
    
    public var timeoutInterval: TimeInterval = 0
    public var retryCount: Int = 0
    internal lazy var urlSession: URLSession = {
        return URLSession(configuration: urlSessionConfiguration,
                          delegate: self,
                          delegateQueue: nil)
    } ()
    private func setupURLSession() {
        if urlSession != URLSession.shared {
            urlSession.invalidateAndCancel()
        }
        
        urlSession = URLSession(configuration: urlSessionConfiguration,
                                delegate: self,
                                delegateQueue: nil)
    }
    
    public init(baseURL: URL, configuration: URLSessionConfiguration? = nil) {
        self.baseURL = baseURL
        timeoutInterval = 120
        let nwConfiguration = configuration ?? URLSessionConfiguration.default
        urlSessionConfiguration = NetworkClient.addHTTP(header: NetworkClient.defaultUserAgent, for: "User-Agent", configuration: nwConfiguration)
    }

    public func addHTTP(header: String, for key: String) {
        urlSessionConfiguration = NetworkClient.addHTTP(header: header, for: key, configuration: urlSessionConfiguration)
    }
    
    static private func addHTTP(header: String?, for key: String, configuration: URLSessionConfiguration) ->  URLSessionConfiguration {
        let config = configuration
        var headers = config.httpAdditionalHeaders ?? [:]
        headers[key] = header
        config.httpAdditionalHeaders = headers
        
        return config
    }

    public func removeHTTPHeaderFor(key: String) {
        urlSessionConfiguration = NetworkClient.addHTTP(header: nil, for: key, configuration: urlSessionConfiguration)
    }
    
    // Reset everything
    public func cancelAllRequests() {
        urlSession.getAllTasks {[weak self] tasks in
            guard let self = self else {return}
            tasks.forEach { task in
                task.cancel()
            }
            
            self.lockingQueue.async {[weak self] in
                guard let self = self else {return}
                self.networkTasks.removeAll()
            }
        }
    }

    func networkTask(for task: URLSessionTask) -> NetworkTask? {
        var result: NetworkTask?
        lockingQueue.sync {[weak self] in
            guard let self = self else {return}
            result = (self.networkTasks.first {$0.dataTask == task})
        }
        
        return result
    }

    func networkTask(for uuid: UUID) -> NetworkTask? {
        var result: NetworkTask?
        lockingQueue.sync {[weak self] in
            guard let self = self else {return}
            result = (self.networkTasks.first {$0.networkRequest.uuid == uuid})
        }
        
        return result
    }
    
    func removeTask(_ task: NetworkTask) {
        lockingQueue.async {[weak self] in
            guard let self = self else {return}
            self.networkTasks.remove(task)
        }
    }
    
    // Not called when the call is made with a closure
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let completedTask = networkTask(for: task) else {return}
        if completedTask.networkRequest.logResponse == true && self.logResponses == true {
            self.log(urlResponse: task.response, data: nil, error: error)
        }

        completedTask.networkRequest.requestCompleted(response: task.response, error: error)

        // Remove the request from our list
        if let tempFileURL = completedTask.tempFileURL {
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        self.removeTask(completedTask)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let progressTask = networkTask(for: task) else {return}
        progressTask.networkRequest.updateUploadProgress(totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
    }
    
    // Some stupid servers return 200 responses, but embed the errors in the header
    // Let this method be overwritten if required
    static public func headerError(response: HTTPURLResponse) -> Error? {
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
