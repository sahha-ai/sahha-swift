//
//  SahhaStorage.swift
//
//
//  Created by Matthew on 2024-05-22.
//

import Foundation

internal class SahhaStorage {
    
    enum SahhaStorageidentifier: String {
        case timeZone
        case sdkVersion
        case appVersion
        case systemVersion
    }
    
    internal static func getValue(_ key: SahhaStorageidentifier) -> String {
        return UserDefaults.standard.string(forKey: key.rawValue) ?? ""
    }
    
    internal static func setValue(_ value: String, for key: SahhaStorageidentifier) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
