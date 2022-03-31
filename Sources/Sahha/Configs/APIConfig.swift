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
    
    var message: String {
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
        case authentication = "authentication"
        case deviceActivity = "deviceActivity"
        case lock = "deviceActivity/lock"
        case lockRange = "deviceActivity/lockRange"
        case profile = "profile"
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
        case .authentication:
            return false
        default:
            return true
        }
    }
    
    var isAppInfoRequired: Bool {
        switch endpointPath {
        case .authentication:
            return true
        default:
            return false
        }
    }
    
    init(_ endpointPath: EndpointPath, _ queryParams: String...) {
        self.endpointPath = endpointPath
        var urlPath = endpointPath.rawValue
        for param in queryParams {
            urlPath.append(param)
        }
        self.relativePath = urlPath
        self.path = SahhaConfig.apiBasePath + urlPath
    }
}
