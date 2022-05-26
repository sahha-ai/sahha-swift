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
    
    static func getAnalyzation(queryParams: [String: String] = [:], _ onComplete: @escaping (Result<DataResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.analyze, queryParams), .get, decodable: DataResponse.self, onComplete: onComplete)
    }
    
    static func postSleep(body: [SleepRequest], _ onComplete: @escaping (Result<EmptyResponse, ApiError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.sleepRange), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postApiError(_ error: ApiErrorModel) {
        
        var body = ErrorModel()

        body.errorCode = error.errorCode
        body.errorType = error.errorType
        body.errorMessage = error.errorMessage
        body.apiURL = error.apiURL
        body.apiMethod = error.apiMethod
        body.apiBody = error.apiBody
        
        postError(body)
    }
    
    static func postAppError(_ error: AppErrorModel) {
        
        var body = ErrorModel()

        body.appMethod = error.appMethod
        body.appBody = error.appBody
        
        postError(body)
    }
    
    private static func postError(_ error: ErrorModel) {
        
        var body = error
                
        body.sdkId = Sahha.settings.framework.rawValue
        body.sdkVersion = SahhaConfig.sdkVersion
        body.appId = SahhaConfig.appId
        body.appVersion = SahhaConfig.appVersion
        body.deviceType = SahhaConfig.deviceType
        body.deviceModel = SahhaConfig.deviceModel
        body.system = SahhaConfig.system
        body.systemVersion = SahhaConfig.systemVersion
        
        guard let url = URL(string: "https://sandbox-error-api.sahha.ai/api/v1/error") else {return}
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let profileToken = SahhaCredentials.profileToken, let jsonBody = try? JSONEncoder().encode(body)
        else {
            return
        }
        
        let authValue = "Profile \(profileToken)"
        urlRequest.addValue(authValue, forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonBody
        
        URLSession.shared.dataTask(with: urlRequest) { (_, _, _) in
        }.resume()
        
    }
}
