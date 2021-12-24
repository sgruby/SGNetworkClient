//
//  User.swift
//  NetworkClientExample
//
//  Created by Scott Gruby on 12/24/21.
//

import Foundation

struct User: Decodable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}
