// 

import Foundation

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
    var errorCode: Int?
    var errorType: String?
    var errorMessage: String?
    var apiURL: String?
    var apiMethod: String?
    var apiBody: String?
}

struct ApiErrorModel: Encodable
{
    var errorCode: Int?
    var errorType: String?
    var errorMessage: String?
    var apiURL: String?
    var apiMethod: String?
    var apiBody: String?
}
