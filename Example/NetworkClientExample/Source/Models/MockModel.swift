//
//  MockModel.swift
//  NetworkClient
//
//  Copyright (c) 2021 Scott Gruby. All rights reserved.
//  Licensed under the MIT License.

import Foundation

struct Mock: Codable {
    let userID: Int?
    let id: Int?
    let title: String?
    let completed: Bool?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case id
        case title
        case completed
    }
}
