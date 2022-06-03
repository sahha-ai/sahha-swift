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
                    if endpoint.isAuthRequired {
                        var apiError = ApiErrorModel()
                        apiError.errorType = ApiError.encodingError.id
                        apiError.apiURL = endpoint.relativePath
                        apiError.apiMethod = method.rawValue
                        APIController.postApiError(apiError)
                    }
                    
                    onComplete(.failure(.encodingError))
                }
                return
            }
            execute(endpoint, method, body: body, decodable: decodable, onComplete: onComplete)
        }
    }
    
    static func execute<D: Decodable>(_ endpoint: ApiEndpoint, _ method: ApiMethod, body: Data? = nil, decodable: D.Type, onComplete: @escaping (Result<D, ApiError>) -> Void) {
        
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
                // cancel request
                print("Sahha | Aborting unauthorized", method.rawValue, url.absoluteString)
                apiError.errorType = ApiError.authError.id
                apiError.errorMessage = "Missing token"
                APIController.postApiError(apiError)
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
        
        switch method {
        case .post, .put, .patch:
            if let body = body {
                urlRequest.httpBody = body
            } else {
                apiError.errorType = ApiError.missingData.id
                apiError.errorMessage = "Missing request data"
                APIController.postApiError(apiError)
                print("Sahha | Aborting missing request body", method.rawValue, url.absoluteString)
                return
            }
        default:
            break
        }

        URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            
            ApiEndpoint.activeTasks.removeAll {
                $0 == endpoint.path
            }
            
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    apiError.errorType = ApiError.serverError.id
                    apiError.errorMessage = error.localizedDescription
                    APIController.postApiError(apiError)
                    onComplete(.failure(.serverError))
                }
                return
            }
            
            guard let urlResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        apiError.errorType = ApiError.serverError.id
                        apiError.errorMessage = "Missing response"
                        APIController.postApiError(apiError)
                        onComplete(.failure(.responseError))
                }
                return
            }
            print("\(urlResponse.statusCode) : " + url.absoluteString)
            
            apiError.errorCode = urlResponse.statusCode
            
            // Token has expired
            if urlResponse.statusCode == 401 {
                print("Sahha | Authorization token is expired")
                
                // Get a new token
                if let profileToken = SahhaCredentials.profileToken, let refreshToken = SahhaCredentials.refreshToken {
                    APIController.postRefreshToken(body: RefreshTokenRequest(profileToken: profileToken, refreshToken: refreshToken)) { result in
                        switch result {
                        case .success(let response):
                            DispatchQueue.main.async {
                                
                                // Save new token
                                SahhaCredentials.setCredentials(profileToken: response.profileToken ?? "", refreshToken: response.refreshToken ?? "")

                                // Try failed endpoint again
                                APIRequest.execute(endpoint, method, body: body, decodable: decodable, onComplete: onComplete)
                            }
                        case .failure(let error):
                            print(error.localizedDescription)
                            
                            DispatchQueue.main.async {
                                apiError.errorType = ApiError.authError.id
                                apiError.errorMessage = error.localizedDescription
                                APIController.postApiError(apiError)
                                
                                onComplete(.failure(.authError))
                            }
                            return
                        }
                    }
                }
                return
                
            } else if urlResponse.statusCode >= 300 {
                    DispatchQueue.main.async {
                        apiError.errorType = ApiError.responseError.id
                        apiError.errorMessage = HTTPURLResponse.localizedString(forStatusCode: urlResponse.statusCode)
                        APIController.postApiError(apiError)
                        onComplete(.failure(.responseError))
                    }
                return
            }
            
            if urlResponse.statusCode == 204, decodable is DataResponse.Type, let responseData = "{}".data(using: .utf8), let dataResponse = DataResponse(data: responseData) as? D {
                onComplete(.success(dataResponse))
                return
            }
            
            if decodable is EmptyResponse.Type, let emptyResponse = EmptyResponse() as? D {
                DispatchQueue.main.async {
                    onComplete(.success(emptyResponse))
                }
                return
            }

            guard let jsonData = data else {
                DispatchQueue.main.async {
                    apiError.errorType = ApiError.missingData.id
                    apiError.errorMessage = "Missing response data"
                    APIController.postApiError(apiError)
                    onComplete(.failure(.missingData))
                }
                return
            }
            
            if decodable is DataResponse.Type, let dataResponse = DataResponse(data: jsonData) as? D {
                onComplete(.success(dataResponse))
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let decoded = try? decoder.decode(decodable.self, from: jsonData) else {
                DispatchQueue.main.async {
                    apiError.errorType = ApiError.decodingError.id
                    APIController.postApiError(apiError)
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

