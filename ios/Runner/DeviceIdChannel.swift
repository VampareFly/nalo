import Flutter
import Foundation
import Security

enum DeviceIdChannel {
  private static let channelName = "com.sanjiang.nalo/device_id"
  private static let keychainService = "com.sanjiang.nalo.device-id"
  private static let keychainAccount = "device-id"

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getDeviceId" else {
        result(FlutterMethodNotImplemented)
        return
      }

      do {
        result(try getOrCreateDeviceId())
      } catch {
        result(
          FlutterError(
            code: "device_id_keychain_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private static func getOrCreateDeviceId() throws -> String {
    if let storedDeviceId = try readDeviceId() {
      return storedDeviceId
    }

    let deviceId = UUID().uuidString
    let status = SecItemAdd(
      [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: keychainAccount,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecValueData as String: Data(deviceId.utf8),
      ] as CFDictionary,
      nil
    )

    if status == errSecSuccess {
      return deviceId
    }
    if status == errSecDuplicateItem, let storedDeviceId = try readDeviceId() {
      return storedDeviceId
    }
    throw keychainError(status: status)
  }

  private static func readDeviceId() throws -> String? {
    let query = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ] as CFDictionary

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw keychainError(status: status)
    }
    guard
      let data = item as? Data,
      let deviceId = String(data: data, encoding: .utf8),
      !deviceId.isEmpty
    else {
      throw NSError(
        domain: "DeviceIdChannel",
        code: Int(errSecDecode),
        userInfo: [NSLocalizedDescriptionKey: "The stored device ID is invalid."]
      )
    }
    return deviceId
  }

  private static func keychainError(status: OSStatus) -> NSError {
    let message = SecCopyErrorMessageString(status, nil) as String?
      ?? "Keychain operation failed with status \(status)."
    return NSError(
      domain: "DeviceIdChannel",
      code: Int(status),
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }
}
