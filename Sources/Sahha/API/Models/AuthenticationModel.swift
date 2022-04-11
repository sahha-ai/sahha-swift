// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct AuthenticationRequest: Encodable {
    var customerId: String
    var profileId: String
}

struct AuthenticationResponse: Decodable {
    var token: String
}
