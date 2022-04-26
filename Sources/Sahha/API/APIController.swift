// Copyright © 2022 Sahha. All rights reserved.

import Foundation

class APIController {
    
    static func postRefreshToken(body: RefreshTokenRequest, _ onComplete: @escaping (Result<TokenResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.refreshToken), .post, encodable: body, decodable: TokenResponse.self, onComplete: onComplete)
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
