// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct ProfileTokenRequest: Encodable {
    var externalId: String = ""
}

struct RefreshTokenRequest: Encodable {
    var refreshToken: String = ""
}

struct TokenResponse: Decodable {
    var profileToken: String = ""
    var refreshToken: String = ""
    var expiresIn: Int = 0
    var tokenType: String = ""
}
