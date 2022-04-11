// Copyright © 2022 Sahha. All rights reserved.

import Foundation

class APIController {
    
    static func postAuthentication(body: AuthenticationRequest, _ onComplete: @escaping (Result<AuthenticationResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.authentication), .post, encodable: body, decodable: AuthenticationResponse.self, onComplete: onComplete)
    }
    
    static func postAuthentication(customerId: String, profileId: String, _ onComplete: @escaping (Result<AuthenticationResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.authentication, "?customerId=\(customerId)", "&profileId=\(profileId)"), .post, decodable: AuthenticationResponse.self, onComplete: onComplete)
    }
    
    static func getDemographic(_ onComplete: @escaping (Result<SahhaDemographic, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.demographic), .get, decodable: SahhaDemographic.self, onComplete: onComplete)
    }
    
    static func putDemographic(body: SahhaDemographic, _ onComplete: @escaping (Result<EmptyResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.demographic), .put, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func getAnalyzation(_ onComplete: @escaping (Result<AnalyzationResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.analyze), .get, decodable: AnalyzationResponse.self, onComplete: onComplete)
    }
    
    static func postSleep(body: [SleepRequest], _ onComplete: @escaping (Result<EmptyResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.sleepRange), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
}
