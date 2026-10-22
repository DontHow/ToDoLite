import Foundation
import Security

protocol APIKeyStorage: Sendable {
    func load() throws -> String?
    func save(_ apiKey: String) throws
}

struct KeychainAPIKeyStorage: APIKeyStorage {
    var service = "com.donghao.TodoLite.llm"
    var account = "apiKey"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    func load() throws -> String? {
        var attributes = query
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw APIKeyStorageError(status: status) }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw APIKeyStorageError(status: errSecDecode)
        }
        return key
    }

    func save(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let changes = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw APIKeyStorageError(status: status) }
    }
}

struct APIKeyStorageError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        "无法访问钥匙串（\(status)），请解锁设备后重试。原有配置已保留。"
    }
}

actor LLMConfigRepository {
    static let shared = LLMConfigRepository()

    private let fs: FileSystemManager
    private let keyStorage: any APIKeyStorage
    private let filename = "llm_config.json"

    init(fs: FileSystemManager = .shared, keyStorage: any APIKeyStorage = KeychainAPIKeyStorage()) {
        self.fs = fs
        self.keyStorage = keyStorage
    }

    func migrateLocalFallbackKeyIfNeeded() async throws {
        guard let local = try await fs.localFallbackLLMConfig(), !local.apiKey.isEmpty else { return }
        if try keyStorage.load() == nil { try keyStorage.save(local.apiKey) }
        try await fs.clearLocalFallbackAPIKey(matching: local.apiKey)
    }

    func save(_ config: LLMConfig) async throws {
        // 先确保持久化到钥匙串成功，再清理磁盘中的旧明文密钥。
        try keyStorage.save(config.apiKey)
        try await fs.write(config, filename: filename, directory: .config)
    }

    func loadOrDefault() async throws -> LLMConfig {
        var config: LLMConfig
        do {
            config = try await fs.read(LLMConfig.self, filename: filename, directory: .config)
        } catch FileSystemError.fileNotFound {
            config = LLMConfig()
        }
        let legacyKey = config.apiKey
        if let storedKey = try keyStorage.load() {
            // 空密钥也是显式设置，防止旧云端配置重新启用已清除的密钥。
            config.apiKey = storedKey
        } else if !legacyKey.isEmpty {
            try keyStorage.save(legacyKey)
        }
        if !legacyKey.isEmpty {
            try await fs.write(config, filename: filename, directory: .config)
        }
        return config
    }
}
