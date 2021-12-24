//
//  NetworkClient+SendRequests.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

extension NetworkClient {
    // This takes a method and path with no body and returns a dictionary
    @discardableResult
    public func perform(method: HTTPMethod = .get, for path: String, completionHandler handler: @escaping ((NetworkResponse<[String: Any]>) -> Void)) -> NetworkTask? {
        let request = NetworkRequest(method: method, path: path, logRequest: logRequests, logResponse: logResponses)
        return perform(request: request, completionHandler: handler)
    }

    @discardableResult
    public func perform<T: Decodable>(method: HTTPMethod = .get, for path: String, resultKey: String? = nil, completionHandler handler: @escaping ((NetworkResponse<T>) -> Void)) -> NetworkTask? {
        return perform(method: method, for: path, body: Data(), resultKey: resultKey, completionHandler: handler)
    }
    
    // This takes a method and path with a encodable object that is encoded to JSON and returns a JSON parsed object in the completion handler.
    // ResultKey is used if the object you want to get back is not the full JSON response.
    @discardableResult
    public func perform<T: Decodable, Body: Encodable>(method: HTTPMethod = .get, for path: String, body: Body, resultKey: String? = nil, completionHandler handler: @escaping ((NetworkResponse<T>) -> Void)) -> NetworkTask? {
        let request = NetworkRequest(method: method, path: path, body: body, logRequest: logRequests, logResponse: logResponses)
        return perform(request: request, resultKey: resultKey, completionHandler: handler)
    }

    // This takes a method and path with a encodable object that is encoded to JSON and returns a JSON parsed object in the completion handler.
    @discardableResult
    public func perform<Body: Encodable>(method: HTTPMethod = .get, for path: String, body: Body, completionHandler handler: @escaping ((NetworkResponse<[String: Any]>) -> Void)) -> NetworkTask? {
        let request = NetworkRequest(method: method, path: path, body: body, logRequest: logRequests, logResponse: logResponses)
        return perform(request: request, completionHandler: handler)
    }

    // This takes a request and returns a JSON parsed object in the completion handler.
    // ResultKey is used if the object you want to get back is not the full JSON response.
    @discardableResult
    public func perform<T: Decodable>(request: NetworkRequest, resultKey: String? = nil, completionQueue: DispatchQueue? = nil, completionHandler handler: @escaping ((NetworkResponse<T>) -> Void)) -> NetworkTask? {
        if request.maxAttempts == 0 {
            request.maxAttempts = maxAttempts
        }
        
        if request.dateDecodingStrategy == nil {
            request.dateDecodingStrategy = dateDecodingStrategy
        }
        
        let completionQueue = completionQueue ?? self.completionQueue
        let taskHandler = parseableTaskHandler(request: request, resultKey: resultKey, completionQueue: completionQueue, completionHandler: handler)

        guard let preparedURLRequest = request.prepareURLRequest(with: self) else {handler(NetworkResponse(error: NetworkError.invalidURL, httpResponse: nil, result: nil, task: nil)); return nil}

        return createNetworkTask(request: request, preparedURLRequest: preparedURLRequest, taskHandler: taskHandler)
    }

    // This takes a request and returns a JSON parsed object in the completion handler.
    @discardableResult
    public func perform(request: NetworkRequest, completionQueue: DispatchQueue? = nil, completionHandler handler: @escaping ((NetworkResponse<[String: Any]>) -> Void)) -> NetworkTask? {
        if request.maxAttempts == 0 {
            request.maxAttempts = maxAttempts
        }

        if request.dateDecodingStrategy == nil {
            request.dateDecodingStrategy = dateDecodingStrategy
        }

        let completionQueue = completionQueue ?? self.completionQueue
        let taskHandler = dictionaryTaskHandler(request: request, completionQueue: completionQueue, completionHandler: handler)

        guard let preparedURLRequest = request.prepareURLRequest(with: self) else {handler(NetworkResponse(error: NetworkError.invalidURL, httpResponse: nil, result: nil, task: nil)); return nil}

        return createNetworkTask(request: request, preparedURLRequest: preparedURLRequest, taskHandler: taskHandler)
    }

    // Internal method that creates a handler that decodes an object
    private func parseableTaskHandler<T: Decodable>(request: NetworkRequest, resultKey: String? = nil, completionQueue: DispatchQueue, completionHandler handler: @escaping ((NetworkResponse<T>) -> Void)) -> ((Data?, URLResponse?, Error?) -> Void) {
        let taskHandler: (Data?, URLResponse?, Error?) -> Void = {[weak self] (data, urlResponse, error) in
            guard let self = self else {return}

            let networkTask = self.networkTask(for: request.uuid)

            if request.logResponse == true && self.logResponses == true {
                self.log(urlResponse: urlResponse, data: data, error: error)
                if let task = networkTask?.dataTask {
                    if let error = error {
                        self.log(task: task, error: error)
                    } else {
                        if let dataTask = task as? URLSessionDataTask {
                            self.log(task: dataTask, response: urlResponse, data: data)
                        }
                        
                        self.log(task: task, error: error)
                    }
                }
            }
            
            if self.shouldRetry(request: request, error: error) == true {
                let newRequest = request
                newRequest.currentAttemptCount = request.currentAttemptCount - 1
                self.perform(request: request, resultKey: resultKey, completionQueue: completionQueue, completionHandler: handler)
            } else {
                // Remove the request from our list
                if let tempFileURL = networkTask?.tempFileURL {
                    try? FileManager.default.removeItem(at: tempFileURL)
                }
                
                self.removeTask(networkTask)

                let response: NetworkResponse<T> = NetworkClient.handleResponse(dateDecodingStrategy: request.dateDecodingStrategy,
                                                            resultKey: resultKey,
                                                            data: data,
                                                            urlResponse: urlResponse,
                                                            error: error,
                                                            task: networkTask)

                completionQueue.async {
                    handler(response)
                }
            }
        }

        return taskHandler
    }

    // Internal task handler that does a JSON serialization without decoding the data
    private func dictionaryTaskHandler(request: NetworkRequest, completionQueue: DispatchQueue, completionHandler handler: @escaping ((NetworkResponse<[String: Any]>) -> Void)) -> ((Data?, URLResponse?, Error?) -> Void) {
        let taskHandler: (Data?, URLResponse?, Error?) -> Void = {[weak self] (data, urlResponse, error) in
            guard let self = self else {return}
            
            let networkTask = self.networkTask(for: request.uuid)

            if request.logResponse == true && self.logResponses == true {
                self.log(urlResponse: urlResponse, data: data, error: error)
                if let task = networkTask?.dataTask {
                    if let error = error {
                        self.log(task: task, error: error)
                    } else {
                        if let dataTask = task as? URLSessionDataTask {
                            self.log(task: dataTask, response: urlResponse, data: data)
                        }

                        self.log(task: task, error: error)
                    }
                }
            }
            
            if self.shouldRetry(request: request, error: error) == true {
                let newRequest = request
                newRequest.currentAttemptCount = request.currentAttemptCount - 1
                self.perform(request: request, completionQueue: completionQueue, completionHandler: handler)
            } else {
                // Remove the request from our list
                if let tempFileURL = networkTask?.tempFileURL {
                    try? FileManager.default.removeItem(at: tempFileURL)
                }
                
                self.removeTask(networkTask)

                let response = NetworkClient.handleResponse(data: data, urlResponse: urlResponse, error: error, task: networkTask)

                completionQueue.async {
                    handler(response)
                }
            }
        }

        return taskHandler
    }

    // Creates and starts the network task
    private func createNetworkTask(request: NetworkRequest, preparedURLRequest: NetworkPreparedRequest, taskHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) -> NetworkTask? {
        // The individual request can turn off logging
        if request.logRequest == true && logRequests == true {
            log(preparedRequest: preparedURLRequest, totalAttemptCount: request.maxAttempts, currentAttempt: request.currentAttemptCount)
        }

        var task: URLSessionTask?
        if let uploadData = preparedURLRequest.data {
            task = urlSession.uploadTask(with: preparedURLRequest.request, from: uploadData, completionHandler: taskHandler)
        } else if let uploadFileURL = preparedURLRequest.tempFile {
            var expectedBytesToSend: Int64 = 0
            if let attributes = try? FileManager.default.attributesOfItem(atPath: uploadFileURL.path), let size = attributes[.size] as? NSNumber {
                expectedBytesToSend = size.int64Value
            }
            
            task = urlSession.uploadTask(with: preparedURLRequest.request, fromFile: uploadFileURL, completionHandler: taskHandler)

            if expectedBytesToSend > 0 {
                task?.countOfBytesClientExpectsToSend = expectedBytesToSend
            }
            
                
        } else {
            task = urlSession.dataTask(with: preparedURLRequest.request, completionHandler: taskHandler)
        }
        
        guard let sessionTask = task else {return nil}
        
        let requestNetworkTask: NetworkTask = networkTask(for: request.uuid) ?? NetworkTask(sessionTask, request: request)
        requestNetworkTask.dataTask = sessionTask
        requestNetworkTask.tempFileURL = preparedURLRequest.tempFile
        
        lockingQueue.async {[weak self] in
            guard let self = self else {return}
            self.networkTasks.insert(requestNetworkTask)
        }

        sessionTask.resume()
        return requestNetworkTask
    }
}
