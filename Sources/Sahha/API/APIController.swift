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
    
    internal static func patchDemographic(body: SahhaDemographic, _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.demographic), .patch, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func getScores(_ types: Set<SahhaScoreType>, dates:(startDate: Date, endDate: Date)? = nil, _ onComplete: @escaping (Result<DataResponse, SahhaError>) -> Void) {
        var queryParams: [(key: String, value: String)] = []
        for type in types {
            queryParams.append((key: "types", value: type.rawValue))
        }
        if let startDateTime = dates?.startDate.toDateTime, let endDateTime = dates?.endDate.toDateTime {
            queryParams.append((key: "startDateTime", value: startDateTime))
            queryParams.append((key: "endDateTime", value: endDateTime))
        }
        APIRequest.execute(ApiEndpoint(.score, queryParams), .get, decodable: DataResponse.self, onComplete: onComplete)
    }
    
    static func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        dates:(startDate: Date, endDate: Date)? = nil,
        _ onComplete: @escaping (Result<DataResponse, SahhaError>) -> Void
    ) {
        var queryParams: [(key: String, value: String)] = []
        
        for category in categories {
            queryParams.append((key: "categories", value: category.rawValue))
        }
        for type in types {
            queryParams.append((key: "types", value: type.rawValue))
        }
        
        if let startDateTime = dates?.startDate.toDateTime, let endDateTime = dates?.endDate.toDateTime {
            queryParams.append((key: "startDateTime", value: startDateTime))
            queryParams.append((key: "endDateTime", value: endDateTime))
        }
        APIRequest.execute(ApiEndpoint(.biomarker, queryParams), .get, decodable: DataResponse.self, onComplete: onComplete)
    }
    
    static func postDataLog(body: [DataLogRequest], _ onComplete: @escaping (Result<EmptyResponse, SahhaError>) -> Void) {
        APIRequest.execute(ApiEndpoint(.dataLog), .post, encodable: body, decodable: EmptyResponse.self, onComplete: onComplete)
    }
    
    static func postApiError(_ sahhaError: SahhaErrorModel, responseError: SahhaResponseError) {
        postError(sahhaError.fromResponseError(responseError), source: .api)
    }
    
    static func postError(_ sahhaError: SahhaErrorModel, source: SahhaErrorSource) {
                
        var error = sahhaError
        error.errorSource = source.rawValue
        error.sdkId = Sahha.settings?.framework.rawValue ?? SahhaFramework.ios_swift.rawValue
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
        
        if let profileToken = SahhaCredentials.token?.profileToken {
            let authValue = "Profile \(profileToken)"
            urlRequest.addValue(authValue, forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = jsonBody
        
        print("Sahha | API Error", error.codeMethod?.uppercased() ?? "METHOD", error.codePath ?? "PATH", error.errorCode ?? 0, error.errorLocation ?? "LOCATION", error.errorMessage ?? "MESSAGE")
        print(error.errorBody ?? "BODY")
        
        URLSession.shared.dataTask(with: urlRequest) { (_, _, _) in
        }.resume()
    }
    
    static func getJsonString(_ response: DataResponse)
    -> (error: String?, value: String?) {
        if let string = String(data: response.data, encoding: .utf8) {
            return (nil, string)
        } else {
            let errorString: String = "Data could not be converted to JSON string."
            Sahha.postError(message: errorString, path: "APIController", method: "trySerializeJson", body: "if let data = try? JSONEncoder().encode(response.data)")
            return (errorString, nil)
        }
    }
}
