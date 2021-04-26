//
//  NetworkClient+Authentication.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/25/21.
//

import Foundation

extension NetworkClient {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if let networkTask = (networkTasks.first {$0.dataTask == task}), let credentials = networkTask.networkRequest.credentials, challenge.protectionSpace.authenticationMethod  == NSURLAuthenticationMethodHTTPBasic || challenge.protectionSpace.authenticationMethod  == NSURLAuthenticationMethodHTTPDigest {
            completionHandler(.useCredential, credentials)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
