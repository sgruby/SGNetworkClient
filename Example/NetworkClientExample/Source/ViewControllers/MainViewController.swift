//
//  MainViewController.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/24/21.
//

import UIKit
import SGNetworkClient

class MainViewController: UIViewController {
    @IBOutlet weak var label: UILabel!
    var client: NetworkClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "Hello"

        if let url = URL(string: "https://jsonplaceholder.typicode.com/") {
            client = NetworkClient(baseURL: url)
            client?.logRequests = true
            client?.logResponses = true
            client?.requestLogger = {(string) in
                print(string)
            }

            client?.responseLogger = {(string, _) in
                print(string)
            }
        
            sendParsedRequest()
            sendAuthenticatedRequest()
            sendFailedRequest()
        }
    }
    
    func sendAuthenticatedRequest() {
        guard let client = client else {return}
        let request = NetworkRequest(method: .get, path: "https://authenticationtest.com/HTTPAuth/")
        request.credentials = URLCredential(user: "user", password: "pass", persistence: .forSession)
        if #available(macOS 12.0, iOS 15.0, *) {
            Task {
                do {
                    let response = try await client.perform(request: request)
                    print("result using async: \(String(describing: response.result))")
                } catch {
                    print("Error using async: \(error.localizedDescription)")
                }
            }
        } else {
            client.perform(request: request) {(response) in
                if let error = response?.error {
                    print("Error: \(error.localizedDescription)")
                } else {
                    print("result: \(String(describing: response?.result))")
                }
            }
        }
    }
    
    func sendParsedRequest() {
        guard let client = client else {return}
        if #available(macOS 12.0, iOS 15.0, *) {
            Task {
                do {
                    let response = try await client.perform(method: .get, for: "/todos/1")
                    print("result using async: \(String(describing: response.result))")
                } catch {
                    print("Error using async: \(error.localizedDescription)")
                }
            }
        } else {
            client.perform(method: .get, for: "/todos/1", resultType: Mock.self) {(response) in
                if let error = response?.error {
                    print("Error: \(error.localizedDescription)")
                } else {
                    print("result: \(String(describing: response?.result))")
                }
            }
        }
    }
    
    func sendLargeDownloadWithCancel() {
        guard let client = client else {return}

        let request = NetworkRequest(path: "http://ipv4.download.thinkbroadband.com/10MB.zip")
        let task = client.perform(request: request) {(response) in
            if let result = response?.result {
                print("download length: \(result.count)")
            }
            print("Large download: \(String(describing: response?.error))")
        }

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            task?.cancel()
        }

    }
    
    func sendFailedRequest() {
        guard let client = client else {return}
        let request = NetworkRequest(method: .get, path: "https://192.168.1.2")
        request.timeoutInterval = 2
        request.maxAttempts = 1
        if #available(macOS 12.0, iOS 15.0, *) {
            Task {
                do {
                    let response = try await client.perform(request: request)
                    print("result using async: \(String(describing: response.result))")
                } catch {
                    print("Error using async: \(error.localizedDescription)")
                }
            }
        } else {
            client.perform(request: request) {(response) in
                print("Failed request: \(String(describing: response?.error))")
            }
        }
    }
}
