// Copyright © 2022 Sahha. All rights reserved.

import Foundation
import Security

internal class SahhaCredentials {
    
    fileprivate enum SahhaCredentialsAccountIdentifier: String {
        case token
        case demographic
    }

    private(set) static var token: TokenResponse?
    
    internal static var isAuthenticated: Bool {
        if token?.profileToken.isEmpty == false {
            return true
        }
        return false
    }
    
    internal static func configure() {
        if let savedToken = Self.getToken() {
            token = savedToken
            print("Sahha | Credentials OK")
        } else {
            print("Sahha | Credentials missing")
        }
    }
    
    // MARK: - Get
    
    private static func getString(account: SahhaCredentialsAccountIdentifier, service: String) -> String? {
        if let data = getData(account: account, service: service), let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return nil
    }
    
    private static func getData(account: SahhaCredentialsAccountIdentifier, service: String) -> Data? {
        let query = [
            kSecAttrAccount: account.rawValue,
            kSecAttrService: service,
            kSecClass: kSecClassGenericPassword,
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
        if let data = result as? Data {
            return data
        } else {
            print ("Sahha | Credentials get data error")
            let errorMessage = SecCopyErrorMessageString(status, nil) as String? ?? "SecCopyErrorMessageString"
            Sahha.postError(message: errorMessage, path: "SahhaCredentials", method: "get", body: "if let data = result as? Data")
        }
        
        return nil
    }
    
    internal static func getToken() -> TokenResponse? {
        
        if let data = getData(account: .token, service: SahhaConfig.appId) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(TokenResponse.self, from: data) {
                return decoded
            }
        }
        
        return nil
    }
    
    internal static func getDemographic() -> SahhaDemographic? {
        
        if let demographicData = getData(account: .demographic, service: SahhaConfig.appId) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(SahhaDemographic.self, from: demographicData) {
                return decoded
            }
        }
        
        return nil
    }
    
    // MARK: - Set

    private static func setString(account: SahhaCredentialsAccountIdentifier, service: String, value: String) -> Bool {
        if value.isEmpty {
            print("Sahha | Cannot set empty string value")
            Sahha.postError(message: "\(account.rawValue) string empty", path: "SahhaCredentials", method: "setString", body: "guard let data = value.data(using: .utf8) else")
            return false
        }
        
        guard let data = value.data(using: .utf8) else {
            print("Sahha | Convert string to data error")
            Sahha.postError(message: "\(account.rawValue) data invalid", path: "SahhaCredentials", method: "setString", body: "guard let data = value.data(using: .utf8) else")
            return false
        }
        
        return setData(account: account, service: service, data: data)
    }
    
    @discardableResult private static func setData(account: SahhaCredentialsAccountIdentifier, service: String, data: Data) -> Bool {

        let query = [
            kSecValueData: data,
            kSecAttrAccount: account.rawValue,
            kSecAttrService: service,
            kSecClass: kSecClassGenericPassword
        ] as [CFString : Any] as CFDictionary

        // Add data in query to keychain
        let status = SecItemAdd(query, nil)

        if status == errSecDuplicateItem {
            // Item already exist - update it.
            let query = [
                kSecAttrAccount: account.rawValue,
                kSecAttrService: service,
                kSecClass: kSecClassGenericPassword
            ] as [CFString : Any] as CFDictionary

            let queryUpdate = [kSecValueData: data] as CFDictionary

            // Update existing item
            let status = SecItemUpdate(query, queryUpdate)
            
            if status == errSecSuccess {
                print("Sahha | Credentials \(account.rawValue) updated")
                return true
            } else {
                print("Sahha | Credentials update error")
                Sahha.postError(message: " \(account.rawValue) update error", path: "SahhaCredentials", method: "setData", body: "if status == errSecSuccess")
                return false
            }
        }
        
        print("Sahha | Credentials \(account.rawValue) set")
        
        return true
    }
    
    @discardableResult internal static func setToken(_ token: TokenResponse) -> Bool {
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(token)
            setData(account: .token, service: SahhaConfig.appId, data: data)
            // Hold the static token
            Self.token = token
        } catch {
            return false
        }
        return true
    }
    
    internal static func setDemographic(_ demographic: SahhaDemographic?) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(demographic)
            setData(account: .demographic, service: SahhaConfig.appId, data: data)
        } catch {
        }
    }
    
    // MARK: - Delete
    
    private static func delete(account: SahhaCredentialsAccountIdentifier, service: String) -> Bool {
            
        let query = [
            kSecAttrAccount: account.rawValue,
            kSecAttrService: service,
            kSecClass: kSecClassGenericPassword
        ] as [CFString : Any] as CFDictionary

        // Delete query from keychain
        let status = SecItemDelete(query)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                print ("Sahha | Credentials delete \(account.rawValue) not found")
                return true
            }
            print ("Sahha | Credentials delete \(account.rawValue) error")
            let errorMessage = SecCopyErrorMessageString(status, nil) as String? ?? "SecCopyErrorMessageString"
            print(errorMessage)
            Sahha.postError(message:" \(account.rawValue) \(errorMessage)", path: "SahhaCredentials", method: "delete", body: "guard status == errSecSuccess else")
                return false
        }
        
        return true
    }
    
    @discardableResult internal static func deleteCredentials() -> Bool {
        if deleteToken(), deleteDemographic() {
            print ("Sahha | Credentials deleted")
            return true
        }
        print ("Sahha | Credentials deleted failed")
        return false
    }
    
    private static func deleteToken() -> Bool {
        if delete(account: .token, service: SahhaConfig.appId) {
            Self.token = nil
            return true
        }
        return false
    }
    
    private static func deleteDemographic() -> Bool {
        return delete(account: .demographic, service: SahhaConfig.appId)
    }

}
