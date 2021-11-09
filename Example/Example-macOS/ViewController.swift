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
        guard let client = client else {return}
        if #available(macOS 12.0, *) {
            Task {
                do {
                    let networkResult = try await client.perform(method: .get, for: "/todos/1")
                    if let result = networkResult.result {
                        print("result: \(result)")
                    }
                } catch {
                    
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
}

