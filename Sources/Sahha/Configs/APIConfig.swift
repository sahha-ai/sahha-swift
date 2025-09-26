// Copyright © 2022 Sahha. All rights reserved.

import Foundation

enum ApiErrorLocation: String, Error {
    case authentication
    case request
    case encoding
    case decoding
    case response
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

struct DataResponse: Decodable {
    var data: Data
}

class ApiEndpoint {
    enum EndpointPath: String {
        case error = "error"
        case profileToken = "oauth/profile/register/appId"
        case refreshToken = "oauth/profile/refreshToken"
        case deviceInfo = "profile/deviceInformation"
        case demographic = "profile/demographic"
        case score = "profile/score"
        case biomarker = "profile/biomarker"
        case dataLog = "profile/data/log"
        case insightComparison = "profile/insight/comparison"
        case insightTrend = "profile/insight/trend"
        case archetypes = "profile/archetypes"
    }
    
    let endpointPath: EndpointPath
    let relativePath: String
    let path: String
    
    var isAuthRequired: Bool {
        switch endpointPath {
        case .error, .profileToken, .refreshToken:
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
    
    
    init(_ endpointPath: EndpointPath, _ queryParams: [(key: String, value: String)]) {
        self.endpointPath = endpointPath
        var urlPath = endpointPath.rawValue
        for (index, queryParam) in queryParams.enumerated() {
            // escape string
            let escapedString = queryParam.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? queryParam.value
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
