// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI

class APIRequest {
    
    static func execute<E: Encodable, D: Decodable>(_ endpoint: ApiEndpoint, _ method: ApiMethod, encodable: E, decodable: D.Type, onComplete: @escaping (Result<D, SahhaError>) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let body: Data
            do {
                body = try JSONEncoder().encode(encodable)
            } catch {
                DispatchQueue.main.async {
                    let errorResponse = ResponseError(title: "Request encoding error", statusCode: 0, location: ApiErrorLocation.encoding.rawValue, errors: [])
                    var apiError = ApiErrorModel()
                    apiError.apiURL = endpoint.relativePath
                    apiError.apiMethod = method.rawValue
                    APIController.postApiError(apiError.fromErrorResponse(errorResponse))
                    onComplete(.failure(SahhaError(message: errorResponse.toString())))
                }
                return
            }

            execute(endpoint, method, body: body, decodable: decodable, onComplete: onComplete)
        }
    }
    
    static func execute<D: Decodable>(_ endpoint: ApiEndpoint, _ method: ApiMethod, body: Data? = nil, decodable: D.Type, onComplete: @escaping (Result<D, SahhaError>) -> Void) {
        
        guard let url = URL(string: endpoint.path) else {return}
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use if an error occurs
        var apiError = ApiErrorModel()
        apiError.apiURL = endpoint.relativePath
        apiError.apiMethod = method.rawValue
        
        do {
            if let jsonData = body, let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                var jsonBody = jsonObject
                if let _ = jsonObject["token"] as? String {
                    jsonBody["token"] = "******"
                }
                if let _ = jsonObject["profileToken"] as? String {
                    jsonBody["profileToken"] = "******"
                }
                if let _ = jsonObject["refreshToken"] as? String {
                    jsonBody["refreshToken"] = "******"
                }
                apiError.apiBody = jsonBody.description
            }
        } catch {
            print(error.localizedDescription)
        }
        
        if endpoint.isAuthRequired {
            if let profileToken = SahhaCredentials.profileToken {
                let authValue = "Profile \(profileToken)"
                urlRequest.addValue(authValue, forHTTPHeaderField: "Authorization")
            } else {
                DispatchQueue.main.async {
                    let errorResponse = ResponseError(title: "Missing profile token", statusCode: 0, location: ApiErrorLocation.authentication.rawValue, errors: [])
                    APIController.postApiError(apiError.fromErrorResponse(errorResponse))
                    onComplete(.failure(SahhaError(message: errorResponse.toString())))
                }
                return
            }
        }
                
        switch method {
        case .post, .put, .patch:
            if let body = body {
                urlRequest.httpBody = body
            } else {
                print("Sahha | Aborting missing request body", method.rawValue, endpoint.relativePath)
                DispatchQueue.main.async {
                    let errorResponse = ResponseError(title: "Missing request body", statusCode: 0, location: ApiErrorLocation.request.rawValue, errors: [])
                    APIController.postApiError(apiError.fromErrorResponse(errorResponse))
                    onComplete(.failure(SahhaError(message: errorResponse.toString())))
                }
                return
            }
        default:
            break
        }
        
        URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    let errorResponse = ResponseError(title: error.localizedDescription, statusCode: 0, location: ApiErrorLocation.request.rawValue, errors: [])
                    APIController.postApiError(apiError.fromErrorResponse(errorResponse))
                    onComplete(.failure(SahhaError(message: errorResponse.toString())))
                }
                return
            }
            
            guard let urlResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    let errorResponse = ResponseError(title: "Missing response", statusCode: 0, location: ApiErrorLocation.response.rawValue, errors: [])
                    APIController.postApiError(apiError.fromErrorResponse(errorResponse))
                    onComplete(.failure(SahhaError(message: errorResponse.toString())))
                }
                return
            }
            print("Sahha |", url.relativePath, urlResponse.statusCode)
            
            apiError.errorCode = urlResponse.statusCode
            
            // Token has expired
            if urlResponse.statusCode == 401 {
                print("Sahha | Authorization token is expired")
                
                // Get a new token
                if let profileToken = SahhaCredentials.profileToken, let refreshToken = SahhaCredentials.refreshToken {
                    APIController.postRefreshToken(body: RefreshTokenRequest(profileToken: profileToken, refreshToken: refreshToken)) { result in
                        switch result {
                        case .success(let response):
                            // Save new token
                            SahhaCredentials.setCredentials(profileToken: response.profileToken ?? "", refreshToken: response.refreshToken ?? "")
                            
                            // Try failed endpoint again
                            APIRequest.execute(endpoint, method, body: body, decodable: decodable, onComplete: onComplete)
                        case .failure(let error):
                            print(error.message)
                            DispatchQueue.main.async {
                                onComplete(.failure(error))
                            }
                        }
                        return
                    }
                }
                return
                
            }
            
            if urlResponse.statusCode == 204, decodable is DataResponse.Type, let responseData = "{}".data(using: .utf8), let dataResponse = DataResponse(data: responseData) as? D {
                onComplete(.success(dataResponse))
                return
            }
            
            if urlResponse.statusCode < 300, decodable is EmptyResponse.Type, let emptyResponse = EmptyResponse() as? D {
                DispatchQueue.main.async {
                    onComplete(.success(emptyResponse))
                }
                return
            }
            
            guard let jsonData = data else {
                DispatchQueue.main.async {
                    let errorResponse = ResponseError(title: "Missing response data", statusCode: urlResponse.statusCode, location: ApiErrorLocation.response.rawValue, errors: [])
                    APIController.postApiError(apiError.fromErrorResponse(errorResponse))
                    onComplete(.failure(SahhaError(message: errorResponse.toString())))
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            if urlResponse.statusCode >= 300 {
                
                guard let decoded = try? decoder.decode(ResponseError.self, from: jsonData) else {
                    DispatchQueue.main.async {
                        let errorResponse = ResponseError(title: "Error decoding response data", statusCode: urlResponse.statusCode, location: ApiErrorLocation.decoding.rawValue, errors: [])
                        APIController.postApiError(apiError.fromErrorResponse(errorResponse))
                        onComplete(.failure(SahhaError(message: errorResponse.toString())))
                    }
                    return
                }
                                
                DispatchQueue.main.async {
                    APIController.postApiError(apiError.fromErrorResponse(decoded))
                    onComplete(.failure(SahhaError(message: decoded.toString())))
                }
                return
            }
            
            if decodable is DataResponse.Type, let dataResponse = DataResponse(data: jsonData) as? D {
                onComplete(.success(dataResponse))
                return
            }
            
            guard let decoded = try? decoder.decode(decodable.self, from: jsonData) else {
                DispatchQueue.main.async {
                    let errorResponse = ResponseError(title: "Error decoding response data", statusCode: urlResponse.statusCode, location: ApiErrorLocation.decoding.rawValue, errors: [])
                    APIController.postApiError(apiError.fromErrorResponse(errorResponse))
                    onComplete(.failure(SahhaError(message: errorResponse.toString())))
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

