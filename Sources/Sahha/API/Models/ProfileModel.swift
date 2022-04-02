// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct ProfileRequest: Codable {
    var id: String
    var version: Int
    var customerId: String
}

struct ProfileResponse: Decodable {
    var id: String
    var version: Int
    var customerId: String
}
