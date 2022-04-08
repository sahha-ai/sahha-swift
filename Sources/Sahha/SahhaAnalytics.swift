// Copyright © 2022 Sahha. All rights reserved.

import Foundation
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

enum SahhaAnalyticsEvent: String, Identifiable, Equatable {
    case api_error
    
    var id: String {
        return self.rawValue
    }
}

enum SahhaAnalyticsParam: String, Identifiable, Equatable {
    case sdk_id
    case sdk_version
    case app_id
    case app_version
    case device_id
    case device_type
    case device_model
    case system
    case system_version
    case error_code
    case error_type
    case error_message
    case api_url
    case api_method
    case api_body
    case api_auth
    
    var id: String {
        return self.rawValue
    }
}

class SahhaAnalytics {
    
    class func configure() {
        AppCenter.start(withAppSecret: SahhaConfig.appAnalyticsKey, services:[
            AppCenterAnalytics.Analytics.self,
            AppCenterCrashes.Crashes.self
        ])
        print("Sahha | Analytics configured")
    }
    
    class func logEvent(_ identifier: SahhaAnalyticsEvent, params: [SahhaAnalyticsParam : Any]? = nil) {
        
        let properties = EventProperties()
        
        var eventParams: [SahhaAnalyticsParam: Any] = [
            SahhaAnalyticsParam.sdk_id : Sahha.settings.framework,
            SahhaAnalyticsParam.sdk_version : SahhaConfig.sdkVersion,
            SahhaAnalyticsParam.app_id : SahhaConfig.appId,
            SahhaAnalyticsParam.app_version : SahhaConfig.appVersion,
            SahhaAnalyticsParam.device_id : SahhaConfig.deviceId,
            SahhaAnalyticsParam.device_type : SahhaConfig.deviceType,
            SahhaAnalyticsParam.device_model : SahhaConfig.deviceModel,
            SahhaAnalyticsParam.system : SahhaConfig.system,
            SahhaAnalyticsParam.system_version : SahhaConfig.systemVersion
        ]
        
        if let customParams = params {
            eventParams.merge(customParams) { _, newParam in
                newParam
            }
        }
        
        eventParams.forEach({ (key, value) in
            if value is String, let stringValue = value as? String {
                properties.setEventProperty(stringValue, forKey: key.id)
            } else if value is Int, let intValue = value as? Int64 {
                properties.setEventProperty(intValue, forKey: key.id)
            } else if value is Bool, let boolValue = value as? Bool {
                properties.setEventProperty(boolValue, forKey: key.id)
            }
        })
        
        print("track error")
        print(eventParams)
        AppCenterAnalytics.Analytics.trackEvent(identifier.id, withProperties: properties)
    }
}
