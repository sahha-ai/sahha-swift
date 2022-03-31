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

        if endpoint.isAuthRequired {
            if let token = Credentials.token {
                urlRequest.addValue(token, forHTTPHeaderField: "Authorization")
            } else {
                // cancel request
                print("Sahha | Aborting unauthorized API call to ", url.absoluteString)
                onComplete(.failure(.authError))
                return
            }
        }
        
        // Add tracking data
        if endpoint.isAppInfoRequired {
            urlRequest.addValue(SahhaConfig.sdkVersion, forHTTPHeaderField: SahhaAppInfo.sdkVersion.rawValue)
            urlRequest.addValue(SahhaConfig.deviceModel, forHTTPHeaderField: SahhaAppInfo.deviceModel.rawValue)
            urlRequest.addValue(SahhaConfig.devicePlatform, forHTTPHeaderField: SahhaAppInfo.devicePlatform.rawValue)
            urlRequest.addValue(SahhaConfig.devicePlatformVersion, forHTTPHeaderField: SahhaAppInfo.devicePlatformVersion.rawValue)
        }
        
        // Don't fetch the same task at the same time
        if ApiEndpoint.activeTasks.contains(endpoint.path) {
            print("Sahha | Aborting duplicated API call to ", url.absoluteString)
            return
        }
        
        ApiEndpoint.activeTasks.append(endpoint.path)

        print("Sahha | Trying API call to ", url.absoluteString)
        
        if let body = body {
            urlRequest.httpBody = body
        }
        
        URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            
            ApiEndpoint.activeTasks.removeAll {
                $0 == endpoint.path
            }
            
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    onComplete(.failure(.serverError))
                }
                return
            }
            
            guard let urlResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        onComplete(.failure(.responseError))
                }
                return
            }
            print("\(urlResponse.statusCode) : " + url.absoluteString)
            
            // Token has expired
            if urlResponse.statusCode == 401, let customerId = Credentials.customerId, customerId.isEmpty == false, let profileId = Credentials.profileId, profileId.isEmpty == false {
                print("Sahha | Authorization token is expired")
                
                // get new token
                return
            } else if urlResponse.statusCode >= 300 {
                    DispatchQueue.main.async {
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
                    onComplete(.failure(.missingData))
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let decoded = try? decoder.decode(decodable.self, from: data) else {
                onComplete(.failure(.decodingError))
                return
            }
            
            DispatchQueue.main.async {
                onComplete(.success(decoded))
            }
            return
        }.resume()
    }
}

