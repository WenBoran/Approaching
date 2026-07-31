//
//  Station.swift
//  Approaching
//
//  Metro station model.
//

import Foundation

struct Station: Identifiable, Equatable {
    let id: Int
    let name: String
    let city: String
    let latitude: Double
    let longitude: Double
}
