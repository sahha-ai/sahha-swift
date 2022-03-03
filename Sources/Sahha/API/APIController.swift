// Copyright © 2022 Sahha. All rights reserved.

import Foundation

class APIController {
    
    static func postAuthentication(body: AuthenticationRequest, _ onComplete: @escaping (Result<AuthenticationResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.authentication), .post, encodable: body, decodable: AuthenticationResponse.self, onComplete: onComplete)
    }
    
    static func postAuthentication(customerId: String, profileId: String, _ onComplete: @escaping (Result<AuthenticationResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.authentication, "?customerId=\(customerId)", "&profileId=\(profileId)"), .post, decodable: AuthenticationResponse.self, onComplete: onComplete)
    }
}
