// Copyright © 2022 Sahha. All rights reserved.

import Foundation
import Security

class Credentials {

    static var customerId: String?
    static var profileId: String?
    static var token: String?
    
    static func getCredentials() {
        if let value = getCustomer() {
            self.customerId = value
            self.profileId = getProfile(account: value)
            self.token = getToken(account: value)
            print("Sahha credentials \(value) \(profileId ?? "")")
        } else {
            print("Sahha missing credentials")
        }
    }
    
    private static func getCustomer() -> String? {
        return get(account: Sahha.settings.environment.rawValue, server: SahhaConfig.apiBasePath)
    }
    
    private static func getProfile(account: String) -> String? {
        return get(account: account, server: Sahha.settings.environment.rawValue)
    }
    
    private static func getToken(account: String)  -> String? {
        return get(account: account, server: SahhaConfig.apiBasePath)
    }
    
    private static func get(account: String, server: String) -> String? {
        let query = [
            kSecAttrAccount: account,
            kSecAttrServer: server,
            kSecClass: kSecClassInternetPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        // Look for item
        let status = SecItemCopyMatching(query, &result)
        
        guard status == errSecSuccess else {
            print ("credentials get error")
            print(SecCopyErrorMessageString(status, nil) as String? ?? "error")
                return nil
        }
        if let data = result as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            print ("credentials get data error")
        }
        
        return nil
    }
    
    static func setCredentials(customer: String, profile: String, token: String) {
        setCustomer(value: customer)
        setProfile(account: customer, value: profile)
        setToken(account: customer, value: token)
    }
    
    private static func setCustomer(value: String) {
        self.customerId = set(account: Sahha.settings.environment.rawValue, server: SahhaConfig.apiBasePath, value: value)
    }
    
    private static func setProfile(account: String, value: String) {
        self.profileId = set(account: account, server: Sahha.settings.environment.rawValue, value: value)
    }
    
    private static func setToken(account: String, value: String) {
        self.token = set(account: account, server: SahhaConfig.apiBasePath, value: value)
    }

    private static func set(account: String, server: String, value: String) -> String? {
        guard let data = value.data(using: .utf8) else {
            print("credentials set data error")
            return nil
        }
        let query = [
            kSecValueData: data,
            kSecAttrAccount: account,
            kSecAttrServer: server,
            kSecClass: kSecClassInternetPassword
        ] as CFDictionary

        // Add data in query to keychain
        let status = SecItemAdd(query, nil)

        if status == errSecDuplicateItem {
            print("credentials update")
            // Item already exist - update it.
            let query = [
                kSecAttrAccount: account,
                kSecAttrServer: server,
                kSecClass: kSecClassInternetPassword
            ] as CFDictionary

            let queryUpdate = [kSecValueData: data] as CFDictionary

            // Update existing item
            let status = SecItemUpdate(query, queryUpdate)
            
            if status == errSecSuccess {
                return value
            } else {
                print("credentials set error")
            }
            return nil
        } else {
            print("credentials set")
            return value
        }
    }
    
    static func deleteCredentials() {
        //deleteProfile()
        deleteToken()
        //deleteCustomer()
    }
    
    private static func deleteCustomer() {
        self.customerId = delete(account: Sahha.settings.environment.rawValue, server: SahhaConfig.apiBasePath, value: self.customerId)
    }
    
    private static func deleteProfile() {
        self.profileId = delete(account: self.customerId, server: Sahha.settings.environment.rawValue, value: self.profileId)
    }
    
    private static func deleteToken() {
        self.token = delete(account: self.customerId, server: SahhaConfig.apiBasePath, value: self.token)
    }
    
    private static func delete(account: String?, server: String, value: String?) -> String? {
        guard let account = account else {
            print ("credentials delete data error")
            return value
        }
            
        let query = [
            kSecAttrAccount: account,
            kSecAttrServer: server,
            kSecClass: kSecClassInternetPassword
        ] as CFDictionary

        // Delete query from keychain
        let status = SecItemDelete(query)
        
        guard status == errSecSuccess else {
            print ("credentials delete error")
            print(SecCopyErrorMessageString(status, nil) as String? ?? "error")
                return value
        }
        
        print ("credentials delete")
        return nil
    }
}
