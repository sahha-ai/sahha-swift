// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI

class APIRequest {
    
    static func execute<E: Encodable, D: Decodable>(_ endpoint: ApiEndpoint, _ method: ApiMethod, encodable: E, decodable: D.Type, onComplete: @escaping (Result<D, ApiError>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let body: Data
            do {
                body = try JSONEncoder().encode(encodable)
            } catch {
                DispatchQueue.main.async {
                    SahhaAnalytics.logEvent(.api_error, params: [SahhaAnalyticsParam.error_type : ApiError.encodingError.id,
                                                                 SahhaAnalyticsParam.api_url : endpoint.relativePath,
                                                                 SahhaAnalyticsParam.api_method : method.rawValue,
                                                                 SahhaAnalyticsParam.api_auth : endpoint.isAuthRequired])

                    onComplete(.failure(.encodingError))
                }
                return
            }
            execute(endpoint, method, body: body, decodable: decodable, onComplete: onComplete)
        }
    }
    
    static func execute<D: Decodable>(_ endpoint: ApiEndpoint, _ method: ApiMethod, body: Data? = nil, decodable: D.Type, canAlert: Bool = true, onComplete: @escaping (Result<D, ApiError>) -> Void) {
        
        guard let url = URL(string: endpoint.path) else {return}
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var eventParams: [SahhaAnalyticsParam: Any] = [
            SahhaAnalyticsParam.api_url : endpoint.relativePath,
            SahhaAnalyticsParam.api_method : method.rawValue,
            SahhaAnalyticsParam.api_auth : endpoint.isAuthRequired
        ]
        
        do {
            if let jsonData = body, let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                var jsonBody = jsonObject
                if let _ = jsonObject["token"] as? String {
                    jsonBody["token"] = "******"
                }
                eventParams[SahhaAnalyticsParam.api_body] = jsonBody.description
            }
        } catch {
            print(error.localizedDescription)
        }

        if endpoint.isAuthRequired {
            if let token = Credentials.token {
                let authValue = "Bearer \(token)"
                urlRequest.addValue(authValue, forHTTPHeaderField: "Authorization")
            } else {
                // cancel request
                print("Sahha | Aborting unauthorized", method.rawValue, url.absoluteString)
                eventParams[SahhaAnalyticsParam.error_type] = ApiError.authError.id
                eventParams[SahhaAnalyticsParam.error_message] = "Missing token"
                SahhaAnalytics.logEvent(.api_error, params: eventParams)
                onComplete(.failure(.authError))
                return
            }
        }
        
        // Don't fetch the same task at the same time
        if ApiEndpoint.activeTasks.contains(endpoint.path) {
            print("Sahha | Aborting duplicated", method.rawValue, url.absoluteString)
            return
        }
        
        ApiEndpoint.activeTasks.append(endpoint.path)

        print("Sahha | Trying", method.rawValue, url.absoluteString)
        
        if method == .post || method == .put || method == .patch {
            if let body = body {
                urlRequest.httpBody = body
            } else {
                eventParams[SahhaAnalyticsParam.error_type] = ApiError.missingData.id
                eventParams[SahhaAnalyticsParam.error_message] = "Missing request data"
                SahhaAnalytics.logEvent(.api_error, params: eventParams)
                return
            }
        }
        
        URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            
            ApiEndpoint.activeTasks.removeAll {
                $0 == endpoint.path
            }
            
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    eventParams[SahhaAnalyticsParam.error_type] = ApiError.serverError.id
                    eventParams[SahhaAnalyticsParam.error_message] = error.localizedDescription
                    SahhaAnalytics.logEvent(.api_error, params: eventParams)
                    onComplete(.failure(.serverError))
                }
                return
            }
            
            guard let urlResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        eventParams[SahhaAnalyticsParam.error_type] = ApiError.serverError.id
                        eventParams[SahhaAnalyticsParam.error_message] = "Missing response"
                        SahhaAnalytics.logEvent(.api_error, params: eventParams)
                        onComplete(.failure(.responseError))
                }
                return
            }
            print("\(urlResponse.statusCode) : " + url.absoluteString)
            
            eventParams[SahhaAnalyticsParam.error_code] = urlResponse.statusCode
            
            // Token has expired
            if urlResponse.statusCode == 401, let customerId = Credentials.customerId, customerId.isEmpty == false, let profileId = Credentials.profileId, profileId.isEmpty == false {
                print("Sahha | Authorization token is expired")
                
                DispatchQueue.main.async {
                    eventParams[SahhaAnalyticsParam.error_type] = ApiError.tokenError.id
                    eventParams[SahhaAnalyticsParam.error_message] = "Token expired"
                    SahhaAnalytics.logEvent(.api_error, params: eventParams)
                }
                
                // get new token
                return
            } else if urlResponse.statusCode >= 300 {
                    DispatchQueue.main.async {
                        eventParams[SahhaAnalyticsParam.error_type] = ApiError.responseError.id
                        eventParams[SahhaAnalyticsParam.error_message] = HTTPURLResponse.localizedString(forStatusCode: urlResponse.statusCode)
                        SahhaAnalytics.logEvent(.api_error, params: eventParams)
                        onComplete(.failure(.responseError))
                    }
                return
            }
            if decodable is EmptyResponse.Type, let emptyResponse = EmptyResponse() as? D {
                DispatchQueue.main.async {
                    onComplete(.success(emptyResponse))
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    eventParams[SahhaAnalyticsParam.error_type] = ApiError.missingData.id
                    eventParams[SahhaAnalyticsParam.error_message] = "Missing response data"
                    SahhaAnalytics.logEvent(.api_error, params: eventParams)
                    onComplete(.failure(.missingData))
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let decoded = try? decoder.decode(decodable.self, from: data) else {
                DispatchQueue.main.async {
                    eventParams[SahhaAnalyticsParam.error_type] = ApiError.decodingError.id
                    SahhaAnalytics.logEvent(.api_error, params: eventParams)
                    onComplete(.failure(.decodingError))
                }
                return
            }
            
            DispatchQueue.main.async {
                onComplete(.success(decoded))
            }
            return
        }.resume()
    }
}

