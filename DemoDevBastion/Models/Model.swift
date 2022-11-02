//
//  Model.swift
//  DemoDevBastion
//
//  Created by Роман Елфимов on 20.04.2021.
//

import Foundation

struct Model: Decodable {
    let state: String
}

struct FirstResponseModel: Decodable {
    let id: Int
    let path: String
    let value: Int
}

struct SecondResponseModel: Decodable {
    let id: Int
    let result: String
}
