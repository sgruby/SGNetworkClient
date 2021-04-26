//
//  MockModel.swift
//  NetworkClient
//
//  Created by Scott Gruby on 4/24/21.
//

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
