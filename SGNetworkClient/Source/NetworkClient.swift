//
//  NetworkClient.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

open class NetworkClient: NSObject, URLSessionDataDelegate {
    // The networkTasks can be accessed on multiple threads,
    // so we have to be careful when we access it and use
    // the lockingQueue to handle that
    internal var networkTasks = Set<NetworkTask>()
    internal let lockingQueue: DispatchQueue = DispatchQueue.init(label: "com.grubysolutions.networkclient.lock")

    public var baseURL: URL
    internal var urlSessionConfiguration: URLSessionConfiguration
    
    public var responseLogger: ((String, Bool) -> Void)?
    public var requestLogger: ((String) -> Void)?
    public var dataTaskLogger: ((URLSessionDataTask, URLResponse?, Data?) -> Void)?
    public var taskCompleteLogger: ((URLSessionTask, Error?) -> Void)?
    public var metricsLogger: ((URLSessionTask, URLSessionTaskMetrics) -> Void)?
    public var backgroundDidFinishEventsHandler: ((URLSession) -> Void)?
    public var receiveAuthenticationChallenge: ((NetworkTask, URLAuthenticationChallenge) -> URLCredential?)?
    public var logRequests: Bool = false
    public var logResponses: Bool = false
    public var completionQueue: DispatchQueue = .main
    public var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate
    internal var additionalHeaders: [HTTPHeader] = []
    
    public var userAgent: String? {
        get {
            (additionalHeaders.first {$0.field == "User-Agent"})?.value
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
    public var maxAttempts: Int = 0
    internal lazy var urlSession: URLSession = {
        return URLSession(configuration: urlSessionConfiguration,
                          delegate: self,
                          delegateQueue: nil)
    } ()
    
    public init(baseURL: URL, configuration: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.baseURL = baseURL
        timeoutInterval = 120
        urlSessionConfiguration = configuration
        super.init()
        addHTTP(header: NetworkClient.defaultUserAgent, for: "User-Agent")
    }
    
    public var protocolClasses: [AnyClass]? {
        didSet {
            urlSessionConfiguration.protocolClasses = protocolClasses
        }
    }

    public func addHTTP(header: String, for key: String) {
        removeHTTPHeaderFor(key: key)
        additionalHeaders.append(HTTPHeader(field: key, value: header))
    }

    public func removeHTTPHeaderFor(key: String) {
        additionalHeaders.removeAll {$0.field == key}
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
    
    func removeTask(_ task: NetworkTask?) {
        guard let task = task else {return}
        lockingQueue.async {[weak self] in
            guard let self = self else {return}
            self.networkTasks.remove(task)
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        log(task: dataTask, response: nil, data: data)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        log(task: dataTask, response: response, data: nil)
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let completedTask = networkTask(for: task) else {return}
        if completedTask.networkRequest.logResponse == true && self.logResponses == true {
            log(task: task, metrics: metrics)
        }
    }
    
    // Not called when the call is made with a closure
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let completedTask = networkTask(for: task) else {return}
        if completedTask.networkRequest.logResponse == true && self.logResponses == true {
            log(urlResponse: task.response, data: nil, error: error)
            log(task: task, error: error)
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
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        backgroundDidFinishEventsHandler?(session)
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
