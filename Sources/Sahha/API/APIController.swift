// Copyright © 2022 Sahha. All rights reserved.

import Foundation

class APIController {
    
    static func postAuthentication(body: AuthenticationRequest, _ onComplete: @escaping (Result<AuthenticationResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.authentication), .post, encodable: body, decodable: AuthenticationResponse.self, onComplete: onComplete)
    }
    
    static func postAuthentication(customerId: String, profileId: String, _ onComplete: @escaping (Result<AuthenticationResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.authentication, "?customerId=\(customerId)", "&profileId=\(profileId)"), .post, decodable: AuthenticationResponse.self, onComplete: onComplete)
    }
    
    static func getProfile(profileId: String, _ onComplete: @escaping (Result<ProfileResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.profile, "/\(profileId)"), .get, decodable: ProfileResponse.self, onComplete: onComplete)
    }
    
    static func postProfile(body: ProfileRequest, _ onComplete: @escaping (Result<EmptyResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.demographic), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postDemographic(body: DemographicRequest, _ onComplete: @escaping (Result<EmptyResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.demographic), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postSleep(body: [SleepRequest], _ onComplete: @escaping (Result<EmptyResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.sleepRange), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
}
