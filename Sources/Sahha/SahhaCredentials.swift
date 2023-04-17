// Copyright © 2022 Sahha. All rights reserved.

import Foundation
import Security

class SahhaCredentials {

    static var profileToken: String?
    static var refreshToken: String?
    
    static var isAuthenticated: Bool {
        if let _ = profileToken, let _ = refreshToken {
            return true
        }
        return false
    }
    
    static func getCredentials() {
        if let profileToken = getProfileToken(), let refreshToken = getRefreshToken() {
            self.profileToken = profileToken
            self.refreshToken = refreshToken
            print("Sahha | Credentials OK")
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
        // Look for item
        let status = SecItemCopyMatching(query, &result)
        
        guard status == errSecSuccess else {
            print ("Sahha | Credentials get error")
            print(SecCopyErrorMessageString(status, nil) as String? ?? "error")
                return nil
        }
        if let data = result as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            print ("Sahha | Credentials get data error")
        }
        
        return nil
    }
    
    @discardableResult static func setCredentials(profileToken: String, refreshToken: String) -> Bool {
        setProfileToken(profileToken)
        setRefreshToken(refreshToken)
        guard let _ = self.profileToken, let _ = self.refreshToken else {
            return false
        }
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
            }
            return nil
        } else {
            print("Sahha | Credentials set")
            return value
        }
    }
    
    static func deleteCredentials() {
        deleteProfileToken()
        deleteRefreshToken()
    }
    
    private static func deleteProfileToken() {
        self.profileToken = delete(account: Sahha.settings.environment.rawValue, server: SahhaConfig.apiBasePath, value: self.profileToken)
    }
    
    private static func deleteRefreshToken() {
        self.refreshToken = delete(account: Sahha.settings.environment.rawValue, server: SahhaConfig.appId, value: self.refreshToken)
    }
    
    private static func delete(account: String, server: String, value: String?) -> String? {
            
        let query = [
            kSecAttrAccount: account,
            kSecAttrServer: server,
            kSecClass: kSecClassInternetPassword
        ] as CFDictionary

        // Delete query from keychain
        let status = SecItemDelete(query)
        
        guard status == errSecSuccess else {
            print ("Sahha | Credentials delete error")
            print(SecCopyErrorMessageString(status, nil) as String? ?? "error")
                return value
        }
        
        print ("Sahha | Credentials deleted")
        return nil
    }
}
