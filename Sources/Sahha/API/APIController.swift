// Copyright © 2022 Sahha. All rights reserved.

import Foundation

class APIController {
    
    static func postProfileToken(body: ProfileTokenRequest, _ onComplete: @escaping (Result<TokenResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.profileToken), .post, encodable: body, decodable: TokenResponse.self, onComplete: onComplete)
    }
    
    static func postRefreshToken(body: RefreshTokenRequest, _ onComplete: @escaping (Result<TokenResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.refreshToken), .post, encodable: body, decodable: TokenResponse.self, onComplete: onComplete)
    }
    
    static func putDeviceInfo(body: SahhaErrorModel, _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.deviceInfo), .put, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func getDemographic(_ onComplete: @escaping (Result<SahhaDemographic, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.demographic), .get, decodable: SahhaDemographic.self, onComplete: onComplete)
    }
    
    static func putDemographic(body: SahhaDemographic, _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.demographic), .put, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func getAnalysis(body: AnalysisRequest, _ onComplete: @escaping (Result<DataResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.analysis), .post, encodable: body, decodable: DataResponse.self, onComplete: onComplete)
    }
    
    static func postSleep(body: [SleepRequest], _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.sleep), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postMovement(body: [HealthRequest], _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.movement), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postHeart(body: [HealthRequest], _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.heart), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postBlood(body: [BloodRequest], _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.blood), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postSurvey(body: SahhaSurvey, _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.surveyResponse), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postInsight(body: [SahhaInsightRequest], _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.insight), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postApiError(_ sahhaError: SahhaErrorModel, responseError: SahhaResponseError) {
        postError(sahhaError.fromResponseError(responseError), source: .api)
    }
    
    static func postError(_ sahhaError: SahhaErrorModel, source: SahhaErrorSource) {
                
        var error = sahhaError
        error.errorSource = source.rawValue
        error.sdkId = Sahha.settings.framework.rawValue
        error.sdkVersion = SahhaConfig.sdkVersion
        error.appId = SahhaConfig.appId
        error.appVersion = SahhaConfig.appVersion
        error.deviceType = SahhaConfig.deviceType
        error.deviceModel = SahhaConfig.deviceModel
        error.system = SahhaConfig.system
        error.systemVersion = SahhaConfig.systemVersion
        
        guard let jsonBody = try? JSONEncoder().encode(error) else {
            return
        }
                
        guard let url = URL(string: ApiEndpoint(.error).path) else {return}
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let profileToken = SahhaCredentials.profileToken {
            let authValue = "Profile \(profileToken)"
            urlRequest.addValue(authValue, forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = jsonBody
        
        print("Sahha | API Error", error.codeMethod?.uppercased() ?? "METHOD", error.codePath ?? "PATH", error.errorCode ?? 0, error.errorLocation ?? "LOCATION", error.errorMessage ?? "MESSAGE")
        print(error.errorBody ?? "BODY")
        
        URLSession.shared.dataTask(with: urlRequest) { (_, _, _) in
        }.resume()
    }
}
