//
//  Error+NetworkExtensions.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

// Borrowed from PMHTTP
public extension Error {
    // Returns `true` if `self` is a transient networking error
    func isTransientNetworkingError() -> Bool {
        switch self {
        case let error as URLError:
            switch error.code {
            case .unknown:
                // We don't know what this is, so we'll err on the side of accepting it.
                return true
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
                 .dnsLookupFailed, .notConnectedToInternet, .badServerResponse,
                 .zeroByteResource, .cannotDecodeRawData, .cannotDecodeContentData,
                 .cannotParseResponse, .dataNotAllowed,
                 // All SSL errors
            .clientCertificateRequired, .clientCertificateRejected, .serverCertificateNotYetValid,
            .serverCertificateHasUnknownRoot, .serverCertificateUntrusted, .serverCertificateHasBadDate,
            .secureConnectionFailed:
                return true
            case .callIsActive:
                // If we retry immediately this is unlikely to change, but if we retry after a delay
                // then retrying makes sense, so we'll accept it.
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    // Returns `true` if `self` is an `NetworkError.failedResponse(503, ...)`.
    func is503ServiceUnavailable() -> Bool {
        switch self {
        case let error as NetworkError:
            switch error {
            case .failedResponse(statusCode: 503, response: _, body: _):
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    func isCancelled() -> Bool {
        switch self {
        case let error as NetworkError:
            switch error {
            case .cancelled:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
}
