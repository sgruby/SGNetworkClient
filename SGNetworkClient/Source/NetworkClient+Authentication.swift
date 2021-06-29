//
//  NetworkClient+Authentication.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

extension NetworkClient {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if let networkTask = networkTask(for: task), let credentials = networkTask.networkRequest.credentials, challenge.protectionSpace.authenticationMethod  == NSURLAuthenticationMethodHTTPBasic || challenge.protectionSpace.authenticationMethod  == NSURLAuthenticationMethodHTTPDigest {
            completionHandler(.useCredential, credentials)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
