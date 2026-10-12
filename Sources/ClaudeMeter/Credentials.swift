import Foundation

/// Borrows Claude Code's OAuth access token. We never refresh it ourselves:
/// refresh tokens rotate, and refreshing here would log Claude Code out.
enum Credentials {
    static func accessToken() -> String? {
        if let json = keychainJSON() ?? fileJSON(), let token = parse(json) { return token }
        return nil
    }

    /// Uses `/usr/bin/security` rather than SecItem APIs: Claude Code writes the item
    /// with that tool, so reading through it doesn't trigger a keychain access prompt.
    private static func keychainJSON() -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 ? data : nil
    }

    private static func fileJSON() -> Data? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/.credentials.json")
        return try? Data(contentsOf: url)
    }

    private static func parse(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return nil }
        return token
    }
}
