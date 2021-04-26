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

            client?.responseLogger = {(string) in
                print(string)
            }
        
            sendAuthenticatedRequest()
            
        }
    }
    
    func sendAuthenticatedRequest() {
        let request = NetworkRequest(method: .get, path: "https://authenticationtest.com/HTTPAuth/")
        request.credentials = URLCredential(user: "user", password: "pass", persistence: .forSession)
        client?.perform(request: request) {(result, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            } else {
                print("result: \(String(describing: result))")
            }
        }
    }
    
    func sendParsedRequest() {
        client?.perform(method: .get, for: "/todos/1", resultType: Mock.self) {(result, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            } else {
                print("result: \(String(describing: result))")
            }
        }
    }
    
    func sendLargeDownloadWithCancel() {
        let request = NetworkRequest(path: "http://ipv4.download.thinkbroadband.com/10MB.zip")
        let task = client?.perform(request: request) {(result, error) in
            if let result = result {
                print("download length: \(result.count)")
            }
            print("Large download: \(String(describing: error))")
        }

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            task?.cancel()
        }

    }
    
    func sendFailedRequest() {
        let request = NetworkRequest(method: .get, path: "https://192.168.1.2")
        request.timeoutInterval = 2
        request.retryCount = 1
        client?.perform(request: request) {(result, error) in
            print("Failed request: \(String(describing: error))")
        }
    }
}
