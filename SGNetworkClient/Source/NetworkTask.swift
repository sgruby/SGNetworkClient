//
//  NetworkTask.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

// This must be a class as we will replace the dataTask
// on retries and the caller that holds onto a NetworkTask
// must be able to cancel whatever the current URLSessionTask is running
public class NetworkTask: Equatable, Hashable {
    public static func == (lhs: NetworkTask, rhs: NetworkTask) -> Bool {
        return lhs.networkRequest.uuid == rhs.networkRequest.uuid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.networkRequest.uuid)
    }
    
    var dataTask: URLSessionTask
    var tempFileURL: URL?
    let networkRequest: NetworkRequest

    init(_ task: URLSessionTask, request: NetworkRequest) {
        dataTask = task
        networkRequest = request
    }

    public func cancel() {
        dataTask.cancel()
    }
    
    public func path() -> String {
        return networkRequest.path
    }
}
