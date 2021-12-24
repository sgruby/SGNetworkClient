//
//  MainViewController.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/24/21.
//

import UIKit
import SGNetworkClient

struct User: Decodable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}

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
//            sendAuthenticatedRequest()
//            sendFailedRequest()
//            sendLargeDownload(cancel: false)
        }
    }
    
    func sendAuthenticatedRequest() {
        guard let client = client else {return}
        let request = NetworkRequest(method: .get, path: "https://authenticationtest.com/HTTPAuth/")
        request.credentials = URLCredential(user: "user", password: "pass", persistence: .forSession)
        Task {
            do {
                let response: NetworkResponse<String> = try await client.perform(request: request)
                print("result using async: \(String(describing: response.result))")
            } catch {
                print("Error using async: \(error.localizedDescription)")
            }
        }
    }
    
    func sendParsedRequest() {
        guard let client = client else {return}
        Task {
            do {
                let response: NetworkResponse<User> = try await client.perform(method: .get, for: "/todos/1")
                print("result using async: \(String(describing: response.result))")
            } catch {
                print("Error using async: \(error.localizedDescription)")
            }
        }
    }
    
    func sendLargeDownload(cancel: Bool = false) {
        guard let client = client else {return}

        let request = NetworkRequest(path: "http://ipv4.download.thinkbroadband.com/10MB.zip")
        let task = Task {
            do {
                let response: NetworkResponse<Data> = try await client.perform(request: request)
                print("respnse: \(response.result?.count ?? 0)")
            } catch {
                if Task.isCancelled == true {
                    print("Task was cancelled")
                } else {
                    print("Error using async: \(error.localizedDescription)")
                }
            }
        }

        if cancel == true {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                task.cancel()
            }
        }
    }
    
    func sendFailedRequest() {
        guard let client = client else {return}
        let request = NetworkRequest(method: .get, path: "https://192.168.1.2")
        request.timeoutInterval = 2
        request.maxAttempts = 1
        Task {
            do {
                let response: NetworkResponse<[String: Any]> = try await client.perform(request: request)
                print("result using async: \(String(describing: response.result))")
            } catch {
                print("Error using async: \(error.localizedDescription)")
            }
        }
    }
}
