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
}

struct AppErrorModel: Encodable
{
    var appMethod: String?
    var appBody: String?
}
