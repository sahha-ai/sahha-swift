// Copyright © 2022 Sahha. All rights reserved.

import Foundation
import Security

internal class SahhaCredentials {

    internal static var profileToken: String?
    internal static var refreshToken: String?
    
    internal static var isAuthenticated: Bool {
        if profileToken?.isEmpty == false, refreshToken?.isEmpty == false {
            return true
        }
        return false
    }
    
    internal static func getCredentials() {
        if let profileToken = getProfileToken(), let refreshToken = getRefreshToken() {
            self.profileToken = profileToken
            self.refreshToken = refreshToken
            // print("Sahha | Credentials OK")
        } else {
            print("Sahha | Credentials missing")
        }
    }
    
    private static func getProfileToken() -> String? {
        return get(account: Sahha.settings.environment.rawValue, server: SahhaConfig.apiBasePath)
    }
    
    private static func getRefreshToken() -> String? {
        return get(account: Sahha.settings.environment.rawValue, server: SahhaConfig.appId)
    }
    
    private static func get(account: String, server: String) -> String? {
        let query = [
            kSecAttrAccount: account,
            kSecAttrServer: server,
            kSecClass: kSecClassInternetPassword,
            kSecReturnData: true
        ] as [CFString : Any] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        guard status == errSecSuccess else {
            print ("Sahha | Credentials get error")
            let errorMessage = SecCopyErrorMessageString(status, nil) as String? ?? "SecCopyErrorMessageString"
            Sahha.postError(message: errorMessage, path: "SahhaCredentials", method: "get", body: "guard status == errSecSuccess else")
                return nil
        }
        if let data = result as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            print ("Sahha | Credentials get data error")
            let errorMessage = SecCopyErrorMessageString(status, nil) as String? ?? "SecCopyErrorMessageString"
            Sahha.postError(message: errorMessage, path: "SahhaCredentials", method: "get", body: "if let data = result as? Data, let string = String(data: data, encoding: .utf8)")
        }
        
        return nil
    }
    
    @discardableResult internal static func setCredentials(profileToken: String, refreshToken: String) -> Bool {
        setProfileToken(profileToken)
        setRefreshToken(refreshToken)
        guard let _ = self.profileToken, let _ = self.refreshToken else {
            return false
        }
        print("Sahha | Credentials set")
        return true
    }
    
    private static func setProfileToken(_ value: String) {
        self.profileToken = set(account: Sahha.settings.environment.rawValue, server: SahhaConfig.apiBasePath, value: value)
    }
    
    private static func setRefreshToken(_ value: String) {
        self.refreshToken = set(account: Sahha.settings.environment.rawValue, server: SahhaConfig.appId, value: value)
    }

    private static func set(account: String, server: String, value: String) -> String? {
        if value.isEmpty {
            print("Sahha | Credentials set empty value")
            return nil
        }
        
        guard let data = value.data(using: .utf8) else {
            print("Sahha | Credentials set data error")
            Sahha.postError(message: "Data invalid", path: "SahhaCredentials", method: "set", body: "guard let data = value.data(using: .utf8) else")
            return nil
        }
        let query = [
            kSecValueData: data,
            kSecAttrAccount: account,
            kSecAttrServer: server,
            kSecClass: kSecClassInternetPassword
        ] as [CFString : Any] as CFDictionary

        // Add data in query to keychain
        let status = SecItemAdd(query, nil)

        if status == errSecDuplicateItem {
            // Item already exist - update it.
            let query = [
                kSecAttrAccount: account,
                kSecAttrServer: server,
                kSecClass: kSecClassInternetPassword
            ] as [CFString : Any] as CFDictionary

            let queryUpdate = [kSecValueData: data] as CFDictionary

            // Update existing item
            let status = SecItemUpdate(query, queryUpdate)
            
            if status == errSecSuccess {
                print("Sahha | Credentials updated")
                return value
            } else {
                print("Sahha | Credentials update error")
                Sahha.postError(message: "Credentials update error", path: "SahhaCredentials", method: "set", body: "if status == errSecSuccess")
            }
            return nil
        } else {
            return value
        }
    }
    
    @discardableResult internal static func deleteCredentials() -> Bool {
        if deleteProfileToken(), deleteRefreshToken() {
            print ("Sahha | Credentials deleted")
            return true
        }
        return false
    }
    
    private static func deleteProfileToken() -> Bool {
        if delete(account: Sahha.settings.environment.rawValue, server: SahhaConfig.apiBasePath, value: self.profileToken) {
            self.profileToken = nil
            return true
        }
        return false
    }
    
    private static func deleteRefreshToken() -> Bool {
        if delete(account: Sahha.settings.environment.rawValue, server: SahhaConfig.appId, value: self.refreshToken) {
            self.refreshToken = nil
            return true
        }
        return false
    }
    
    private static func delete(account: String, server: String, value: String?) -> Bool {
            
        let query = [
            kSecAttrAccount: account,
            kSecAttrServer: server,
            kSecClass: kSecClassInternetPassword
        ] as [CFString : Any] as CFDictionary

        // Delete query from keychain
        let status = SecItemDelete(query)
        
        guard status == errSecSuccess else {
            print ("Sahha | Credentials delete error")
            let errorMessage = SecCopyErrorMessageString(status, nil) as String? ?? "SecCopyErrorMessageString"
            print(errorMessage)
            Sahha.postError(message: errorMessage, path: "SahhaCredentials", method: "delete", body: "guard status == errSecSuccess else")
                return false
        }
        
        return true
    }
}
