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
                    let responseError = SahhaResponseError(title: "Request encoding error", statusCode: 0, location: ApiErrorLocation.encoding.rawValue, errors: [])
                    var sahhaError = SahhaErrorModel()
                    sahhaError.codePath = endpoint.relativePath
                    sahhaError.codeMethod = method.rawValue
                    APIController.postApiError(sahhaError, responseError: responseError)
                    onComplete(.failure(SahhaError(message: responseError.title)))
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
        var sahhaError = SahhaErrorModel()
        sahhaError.codePath = endpoint.relativePath
        sahhaError.codeMethod = method.rawValue
        
        if let jsonData = body, let jsonString = String(data: jsonData, encoding: .utf8) {
            sahhaError.codeBody = jsonString
        }
        
        if endpoint.isAuthRequired {
            if let profileToken = SahhaCredentials.profileToken {
                let authValue = "Profile \(profileToken)"
                urlRequest.addValue(authValue, forHTTPHeaderField: "Authorization")
            } else {
                DispatchQueue.main.async {
                    let responseError = SahhaResponseError(title: "Missing profile token", statusCode: 0, location: ApiErrorLocation.authentication.rawValue, errors: [])
                    APIController.postApiError(sahhaError, responseError: responseError)
                    onComplete(.failure(SahhaError(message: responseError.title)))
                }
                return
            }
        }
        
        if endpoint.endpointPath == .profileToken {
            urlRequest.addValue(Sahha.appId, forHTTPHeaderField: "AppId")
            urlRequest.addValue(Sahha.appSecret, forHTTPHeaderField: "AppSecret")
        }
                
        switch method {
        case .post, .put, .patch:
            if let body = body {
                urlRequest.httpBody = body
            } else {
                print("Sahha | Aborting missing request body", method.rawValue, endpoint.relativePath)
                DispatchQueue.main.async {
                    let responseError = SahhaResponseError(title: "Missing request body", statusCode: 0, location: ApiErrorLocation.request.rawValue, errors: [])
                    APIController.postApiError(sahhaError, responseError: responseError)
                    onComplete(.failure(SahhaError(message: responseError.title)))
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
                    let responseError = SahhaResponseError(title: error.localizedDescription, statusCode: 0, location: ApiErrorLocation.request.rawValue, errors: [])
                    APIController.postApiError(sahhaError, responseError: responseError)
                    onComplete(.failure(SahhaError(message: responseError.title)))
                }
                return
            }
            
            guard let urlResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    let responseError = SahhaResponseError(title: "Missing response", statusCode: 0, location: ApiErrorLocation.response.rawValue, errors: [])
                    APIController.postApiError(sahhaError, responseError: responseError)
                    onComplete(.failure(SahhaError(message: responseError.title)))
                }
                return
            }
            print("Sahha |", method.rawValue.uppercased(), url.relativePath, urlResponse.statusCode)
            
            sahhaError.errorCode = urlResponse.statusCode
            
            // Account has been removed
            if urlResponse.statusCode == 410 {
                print("Sahha | Account does not exist")
                
                Sahha.deauthenticate { error, success in
                    DispatchQueue.main.async {
                        onComplete(.failure(SahhaError(message: "Sahha | Account does not exist")))
                    }
                }
                
                return
            }
            
            // Token has expired
            if urlResponse.statusCode == 401 {
                print("Sahha | Authorization token is expired")
                
                // Get a new token
                if let refreshToken = SahhaCredentials.refreshToken {
                    APIController.postRefreshToken(body: RefreshTokenRequest(refreshToken: refreshToken)) { result in
                        switch result {
                        case .success(let response):
                            // Save new token
                            SahhaCredentials.setCredentials(profileToken: response.profileToken, refreshToken: response.refreshToken)
                            
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
            
            if urlResponse.statusCode == 204 {
                if decodable is DataResponse.Type, let responseData = "{}".data(using: .utf8), let dataResponse = DataResponse(data: responseData) as? D {
                    onComplete(.success(dataResponse))
                } else if decodable is SahhaDemographic.Type, let dataResponse = SahhaDemographic() as? D  {
                    onComplete(.success(dataResponse))
                } else if decodable is TokenResponse.Type, let dataResponse = TokenResponse() as? D  {
                    onComplete(.success(dataResponse))
                }
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
                    let responseError = SahhaResponseError(title: "Missing response data", statusCode: urlResponse.statusCode, location: ApiErrorLocation.response.rawValue, errors: [])
                    APIController.postApiError(sahhaError, responseError: responseError)
                    onComplete(.failure(SahhaError(message: responseError.title)))
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            if urlResponse.statusCode >= 300 {
                
                guard let responseError = try? decoder.decode(SahhaResponseError.self, from: jsonData) else {
                    DispatchQueue.main.async {
                        let responseError = SahhaResponseError(title: "Error decoding response data", statusCode: urlResponse.statusCode, location: ApiErrorLocation.decoding.rawValue, errors: [])
                        APIController.postApiError(sahhaError, responseError: responseError)
                        onComplete(.failure(SahhaError(message: responseError.title)))
                    }
                    return
                }
                                
                DispatchQueue.main.async {
                    APIController.postApiError(sahhaError, responseError: responseError)
                    onComplete(.failure(SahhaError(message: responseError.title)))
                }
                return
            }
            
            if decodable is DataResponse.Type, let dataResponse = DataResponse(data: jsonData) as? D {
                onComplete(.success(dataResponse))
                return
            }
            
            guard let decoded = try? decoder.decode(decodable.self, from: jsonData) else {
                DispatchQueue.main.async {
                    let responseError = SahhaResponseError(title: "Error decoding response data", statusCode: urlResponse.statusCode, location: ApiErrorLocation.decoding.rawValue, errors: [])
                    APIController.postApiError(sahhaError, responseError: responseError)
                    onComplete(.failure(SahhaError(message: responseError.title)))
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

