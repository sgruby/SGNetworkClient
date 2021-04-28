//
//  MultipartBody.swift
//  SGNetworkClient
//
//  Created by Scott Gruby on 4/28/21.
//

import Foundation

public class MultipartBody {
    internal fileprivate(set) var parts: [MultipartPart] = []
    let boundary: String
    let streamBufferSize = 1024
    lazy var contentType: String = "multipart/form-data; boundary=\(self.boundary)"
    public var contentLength: UInt64 { parts.reduce(0) { $0 + $1.length } }

    lazy var temporaryFileURL: URL? = {
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        let tempFileURL = tempDirectoryURL.appendingPathComponent(boundary)
        return tempFileURL
    } ()
    
    init(boundary: String) {
        self.boundary = boundary
    }
    
    
    public func add(part: MultipartPart) {
        parts.append(part)
    }
    
    internal func encodedData() -> Data {
        var data = Data()
        
        // Initial boundary
        data.append(MultipartBoundary.boundary(for: .initial, boundary: boundary))

        for (index, part) in parts.enumerated() {
            if index > 0 {
                data.append(MultipartBoundary.boundary(for: .encapsulated, boundary: boundary))
            }
            data.append(encode(part))
        }
        // Final boundary
        data.append(MultipartBoundary.boundary(for: .last, boundary: boundary))
        return data
    }
    
    internal func encodedTemporaryFile() -> URL? {
        guard let fileURL = temporaryFileURL else {return nil}
        try? FileManager.default.removeItem(at: fileURL)
        guard let outputStream = OutputStream(url: fileURL, append: false) else {return nil}
        outputStream.open()
        defer { outputStream.close() }

        writeStream(inputStream: InputStream(data: MultipartBoundary.boundary(for: .initial, boundary: boundary)), to: outputStream)

        for (index, part) in parts.enumerated() {
            if index > 0 {
                writeStream(inputStream: InputStream(data: MultipartBoundary.boundary(for: .encapsulated, boundary: boundary)), to: outputStream)
            }
            
            writeStream(for: part, to: outputStream)
        }

        writeStream(inputStream: InputStream(data: MultipartBoundary.boundary(for: .last, boundary: boundary)), to: outputStream)

        return fileURL
    }
    
    private  func encodeHeader(_ part: MultipartPart) -> Data {
        var data = Data()
        var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
        if let filename = part.filename {
            disposition += "; filename=\"\(filename)\""
        }

        disposition += "\r\n"

        data.append(disposition.data(using: String.Encoding.utf8) ?? Data())

        if let mimeType = part.mimeType {
            let contentType = "Content-Type: \(mimeType.string())\r\n\r\n"
            data.append(contentType.data(using: String.Encoding.utf8) ?? Data())
        } else {
            let crlf = "\r\n"
            data.append(crlf.data(using: String.Encoding.utf8) ?? Data())
        }
        
        return data
    }
    
    private func encode(_ part: MultipartPart) -> Data {
        var data = Data()
        data.append(encodeHeader(part))
        data.append(encodeStream(for: part))
        return data
    }
    
    private func encodeStream(for part: MultipartPart) -> Data {
        let inputStream = part.bodyStream
        inputStream.open()
        defer { inputStream.close() }

        var data = Data()

        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)


            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }

        return data
    }

    private func writeStream(for part: MultipartPart, to outputStream: OutputStream) {
        let headerData = encodeHeader(part)
        writeStream(inputStream: InputStream(data: headerData), to: outputStream)

        let inputStream = part.bodyStream
        writeStream(inputStream: inputStream, to: outputStream)
    }
    
    private func writeStream(inputStream: InputStream, to outputStream: OutputStream) {
        inputStream.open()
        defer { inputStream.close() }

        var buffer = [UInt8](repeating: 0, count: streamBufferSize)

        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)

            if bytesRead > 0 {
                var bytesToWrite = bytesRead
                var writeBuffer = buffer
                while bytesToWrite > 0, outputStream.hasSpaceAvailable {
                    let bytesWritten = outputStream.write(writeBuffer, maxLength: bytesToWrite)
                    bytesToWrite -= bytesWritten
                    
                    if bytesToWrite > 0 {
                        writeBuffer = Array(buffer[bytesWritten..<writeBuffer.count])
                    }
                }
            } else {
                break
            }
        }
    }
}
