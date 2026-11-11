import Foundation
import LocalAuthentication
import Security

enum SavedLoginError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status): SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)."
        }
    }
}

/// Holds one supplier login in this device's Keychain. The item never syncs, and filling it
/// asks the device owner to confirm with Touch ID, Face ID, or the device password.
nonisolated struct SavedLoginStore {
    var service: String

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    }

    func savedEmail() -> String? {
        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any] else { return nil }
        return attributes[kSecAttrAccount as String] as? String
    }

    func password() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SavedLoginError.keychain(status) }
        return String(data: data, encoding: .utf8)
    }

    func save(email: String, password: String) throws {
        delete()
        var item = baseQuery
        item[kSecAttrAccount as String] = email
        item[kSecAttrLabel as String] = "Inventory Tracker supplier login"
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        item[kSecValueData as String] = Data(password.utf8)
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw SavedLoginError.keychain(status) }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    static func confirmOwner() async -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["INVENTORY_SKIP_OWNER_CHECK"] != nil { return true }
        #endif
        let reason = "fill your saved login"
        return (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

extension SavedLoginStore {
    init(supplierID: String) {
        #if DEBUG
        if let service = ProcessInfo.processInfo.environment["INVENTORY_KEYCHAIN_SERVICE"] {
            self.init(service: service)
            return
        }
        #endif
        self.init(service: "com.joshuaswanson.inventorytracker.\(supplierID)")
    }
}
