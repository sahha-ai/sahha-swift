// 

import Foundation

struct SahhaError: Error {
    var message: String
}

struct ResponseError: Codable
{
    var title: String
    var statusCode: Int
    var location: String
    var errors: [ResponseErrorItem]
    
    func toString() -> String {
        guard let data = try? JSONEncoder().encode(self), let string = String(data: data,
                                                                              encoding: .utf8) else {
            return ""
        }
        return string
    }
}

struct ResponseErrorItem: Codable {
    var origin: String
    var errors: [String]
}

struct ErrorModel: Encodable
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
    var errorType: String?
    var errorMessage: String?
    var apiURL: String?
    var apiMethod: String?
    var apiBody: String?
    var appMethod: String?
    var appBody: String?
}

struct ApiErrorModel: Encodable
{
    var errorCode: Int?
    var errorType: String?
    var errorMessage: String?
    var apiURL: String?
    var apiMethod: String?
    var apiBody: String?
    
    mutating func fromErrorResponse(_ errorResponse: ResponseError) -> ApiErrorModel {
        self.errorCode = errorResponse.statusCode
        self.errorMessage = errorResponse.toString()
        self.errorType = errorResponse.location
        return self
    }
}

struct AppErrorModel: Encodable
{
    var appMethod: String?
    var appBody: String?
}
