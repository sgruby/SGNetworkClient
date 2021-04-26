//
//  NetworkClient+UserAgent.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/24/21.
//

import Foundation
import UIKit

extension NetworkClient {
    internal static let defaultUserAgent: String = {
        let bundle = Bundle.main

        func appName() -> String {
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                return name
            } else if let name = bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String {
                return name
            } else {
                return "(null)"
            }
        }

        func appVersion() -> String {
            let marketingVersionNumber = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let buildVersionNumber = bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
            if let marketingVersionNumber = marketingVersionNumber, let buildVersionNumber = buildVersionNumber, marketingVersionNumber != buildVersionNumber {
                return "\(marketingVersionNumber) rv:\(buildVersionNumber)"
            } else {
                return marketingVersionNumber ?? buildVersionNumber ?? "(null)"
            }
        }

        func deviceInfo() -> (model: String, systemName: String) {
            #if os(OSX)
            return ("Macintosh", "Mac OS X")
            #elseif os(iOS) || os(tvOS)
            let device = UIDevice.current
            return (device.model, device.systemName)
            #endif
        }

        func systemVersion() -> String {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            var s = "\(version.majorVersion).\(version.minorVersion)"
            if version.patchVersion != 0 {
                s += ".\(version.patchVersion)"
            }
            return s
        }

        let localeIdentifier = Locale.current.identifier

        let (deviceModel, systemName) = deviceInfo()
        // Format is "My Application 1.0 (device_model:iPhone; system_os:iPhone OS system_version:9.2; en_US)"
        return "\(appName()) \(appVersion()) (device_model:\(deviceModel); system_os:\(systemName); system_version:\(systemVersion()); \(localeIdentifier))"
    }()
}
