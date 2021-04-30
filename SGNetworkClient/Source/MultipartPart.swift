//
//  MIME.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)
import MobileCoreServices
#elseif os(macOS)
import CoreServices
#endif

public enum MIMEType {
    case plainText
    case utf8Text
    case binary
    case video
    case other(value: String)
    
    func string() -> String {
        switch self {
        case .plainText:
            return "text/plain"
        case .utf8Text:
            return "text/plain; charset=utf-8"
        case .binary:
            return "application/octet-stream"
        case .video:
            return "video/mp4"
        case .other(let value):
            return value
        }
    }
}

public struct MultipartPart {
    let mimeType: MIMEType?
    let filename: String?
    let name: String
    let bodyStream: InputStream
    let length: UInt64
    
    public  init(string: String, name: String, filename: String? = nil) {
        self.init(data: Data(string.utf8), name: name, filename: filename, mimeType: .utf8Text)
    }
    
    public init(text: Data, name: String, filename: String? = nil) {
        self.init(data: text, name: name, filename: filename, mimeType: .plainText)
    }
    
    public init(video: Data, name: String, filename: String) {
        self.init(data: video, name: name, filename: filename, mimeType: .video)
    }
    
    public init(data: Data, name: String, filename: String? = nil, mimeType: MIMEType? = nil) {
        self.bodyStream = InputStream(data: data)
        self.name = name
        self.filename = filename
        self.mimeType = mimeType
        self.length = UInt64(data.count)
    }

    public init(url: URL, name: String, filename: String? = nil, mimeType: MIMEType? = nil) {
        self.bodyStream = InputStream(url: url) ?? InputStream(data: Data())
        self.name = name
        self.filename = filename ?? url.lastPathComponent
        
        // Files must get a MIME Type
        self.mimeType = mimeType ?? MIMEType.other(value: MultipartPart.mimeType(pathExtension: url.pathExtension))
            
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), let size = attributes[.size] as? NSNumber {
            self.length = size.uint64Value
        } else {
            self.length = 0
        }
    }

    static func mimeType(pathExtension: String) -> String {
        if let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue() {
            if let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue() {
                return contentType as String
            }
        }

        return "application/octet-stream"
    }
}
