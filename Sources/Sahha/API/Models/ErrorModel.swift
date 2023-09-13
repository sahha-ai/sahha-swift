// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct SahhaError: Error {
    var message: String
}

enum SahhaErrorSource: String {
    case app
    case api
}

struct SahhaResponseError: Codable
{
    var title: String
    var statusCode: Int
    var location: String
    var errors: [SahhaResponseErrorItem]
}

struct SahhaResponseErrorItem: Codable {
    var origin: String
    var errors: [String]
}

struct SahhaErrorModel: Encodable
{
    var sdkId: String?
    var sdkVersion: String?
    var appId: String?
    var appVersion: String?
    var deviceId: String?
    var deviceType: String?
    var deviceModel: String?
    var system: String?
    var systemVersion: String?
    var errorSource: String?
    var errorCode: Int?
    var errorLocation: String?
    var errorMessage: String?
    var errorBody: String?
    var codePath: String?
    var codeMethod: String?
    var codeBody: String?
    var timeZone: String?
    
    func fromResponseError(_ responseError: SahhaResponseError) -> SahhaErrorModel {
        var error = self
        error.errorCode = responseError.statusCode
        error.errorLocation = responseError.location
        error.errorMessage = responseError.title
        
        if let jsonData = try? JSONEncoder().encode(responseError), let jsonString = String(data: jsonData, encoding: .utf8) {
            error.errorBody = jsonString
        }
        return error
    }
}
