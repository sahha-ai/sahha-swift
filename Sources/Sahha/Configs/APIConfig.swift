// Copyright © 2022 Sahha. All rights reserved.

import Foundation

enum ApiError: String, Error {
    case authError      = "Authentication Error"
    case tokenError     = "Token Error"
    case encodingError  = "Encoding Error"
    case serverError    = "Server error"
    case responseError  = "Response error"
    case decodingError  = "Decoding error"
    case missingData    = "Missing data"
    
    var id: String {
        return self.rawValue
    }
}

enum ApiMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct EmptyResponse: Decodable {
    
}

class ApiEndpoint {
    enum EndpointPath: String {
        case refreshToken = "oauth/profile/refreshToken"
        case deviceActivity = "deviceActivity"
        case lock = "deviceActivity/lock"
        case lockRange = "deviceActivity/lockRange"
        case demographic = "profile/demographic"
        case analyze = "profile/analyze"
        case sleepRange = "sleep/logRange"
    }
    
    let endpointPath: EndpointPath
    let relativePath: String
    let path: String
    static var activeTasks: [String] = []
    
    var isAuthRequired: Bool {
        switch endpointPath {
        case .refreshToken:
            return false
        default:
            return true
        }
    }
    
    init(_ endpointPath: EndpointPath, _ subPaths: String...) {
        self.endpointPath = endpointPath
        var urlPath = endpointPath.rawValue
        for subPath in subPaths {
            urlPath.append(subPath)
        }
        self.relativePath = urlPath
        self.path = SahhaConfig.apiBasePath + urlPath
    }
    
    init(_ endpointPath: EndpointPath, _ queryParams: [String:String]) {
        self.endpointPath = endpointPath
        var urlPath = endpointPath.rawValue
        for (index, queryParam) in queryParams.enumerated() {
            // escape string
            let escapedString = queryParam.value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? queryParam.value
            if (index == 0) {
                urlPath.append("?\(queryParam.key)=\(escapedString)")
            } else {
                urlPath.append("&\(queryParam.key)=\(escapedString)")
            }
        }
        self.relativePath = urlPath
        self.path = SahhaConfig.apiBasePath + urlPath
    }
}
