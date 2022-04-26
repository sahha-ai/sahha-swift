// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct RefreshTokenRequest: Encodable {
    var profileToken: String = ""
    var refreshToken: String = ""
}

struct TokenResponse: Decodable {
    var profileToken: String?
    var refreshToken: String?
    var expiresIn: Int?
    var tokenType: String?
}
