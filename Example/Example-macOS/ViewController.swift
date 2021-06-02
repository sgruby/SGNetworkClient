//
//  ViewController.swift
//  Example-macOS
//
//  Created by Scott Gruby on 6/2/21.
//

import Cocoa
import SGNetworkClient

class ViewController: NSViewController {
    var client: NetworkClient?

    override func viewDidLoad() {
        super.viewDidLoad()

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
            
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func sendParsedRequest() {
        client?.perform(method: .get, for: "/todos/1", resultType: Mock.self) {(response) in
            if let error = response?.error {
                print("Error: \(error.localizedDescription)")
            } else {
                print("result: \(String(describing: response?.result))")
            }
        }
    }
}

