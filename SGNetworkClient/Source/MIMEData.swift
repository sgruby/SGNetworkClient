//
//  MIME.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/25/21.
//

import Foundation

public struct MIMEData {
    public let contentType: String
    public let filename: String?
    let name: String
    public let data: Data
    
    init(string: String, filename: String? = nil, name: String) {
        contentType = "text/plain; charset=utf-8"
        self.filename = filename
        self.name = name
        if let data = string.data(using: String.Encoding.utf8) {
            self.data = data
        } else {
            self.data = Data()
        }
    }
    
    init(text: Data, filename: String? = nil, name: String) {
        contentType = "text/plain"
        self.filename = filename
        self.name = name
        self.data = text
    }
    
    init(data: Data, filename: String, name: String) {
        contentType = "application/octet-stream"
        self.filename = filename
        self.name = name
        self.data = data
    }

    init(video: Data, filename: String, name: String) {
        contentType = "video/mp4"
        self.filename = filename
        self.name = name
        self.data = video
    }
}
