import Foundation

/// One usage bar, e.g. "Current session 56%".
struct UsageLimit: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let percent: Double
    let resetsAt: Date?
    let severity: String
}

struct UsageSnapshot: Equatable {
    let limits: [UsageLimit]
    let fetchedAt: Date

    var session: UsageLimit? { limits.first { $0.id == "session" } }
    var weekly: UsageLimit? { limits.first { $0.id == "weekly_all" } }
    var highest: UsageLimit? { limits.max { $0.percent < $1.percent } }
}

enum UsageError: LocalizedError {
    case noCredentials
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .noCredentials: "No Claude Code login found. Run `claude` and sign in."
        case .unauthorized: "Login expired. Open Claude Code once to refresh it."
        case .rateLimited: "Rate limited. Will retry shortly."
        case .http(let code): "Server returned HTTP \(code)."
        case .decoding: "Unexpected response from the usage API."
        }
    }
}

/// Reads the same `/api/oauth/usage` endpoint Claude Code's `/usage` uses.
struct UsageClient {
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func fetch() async throws -> UsageSnapshot {
        guard let token = Credentials.accessToken() else { throw UsageError.noCredentials }

        var req = URLRequest(url: Self.endpoint, timeoutInterval: 20)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("claude-meter/1.0", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        switch http?.statusCode ?? 0 {
        case 200: break
        case 401, 403: throw UsageError.unauthorized
        case 429:
            let retry = http?.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init)
            throw UsageError.rateLimited(retryAfter: retry)
        case let code: throw UsageError.http(code)
        }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> UsageSnapshot {
        guard let raw = try? JSONDecoder().decode(RawUsage.self, from: data) else { throw UsageError.decoding }

        var limits: [UsageLimit] = []
        if let rows = raw.limits, !rows.isEmpty {
            for row in rows {
                let model = row.scope?.model?.display_name
                let (id, title): (String, String) = switch row.kind {
                case "session": ("session", "Current session")
                case "weekly_all": ("weekly_all", "This week")
                case "weekly_scoped": ("weekly_\(model ?? "scoped")", "\(model ?? "Scoped") this week")
                default: (row.kind, row.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                }
                limits.append(UsageLimit(
                    id: id, title: title,
                    subtitle: nil,
                    percent: row.percent ?? 0,
                    resetsAt: row.resets_at.flatMap(parseDate),
                    severity: row.severity ?? "normal"))
            }
        } else {
            // Older response shape.
            if let w = raw.five_hour {
                limits.append(UsageLimit(id: "session", title: "Current session", subtitle: nil,
                                         percent: w.utilization ?? 0, resetsAt: w.resets_at.flatMap(parseDate), severity: "normal"))
            }
            if let w = raw.seven_day {
                limits.append(UsageLimit(id: "weekly_all", title: "This week", subtitle: nil,
                                         percent: w.utilization ?? 0, resetsAt: w.resets_at.flatMap(parseDate), severity: "normal"))
            }
        }
        return UsageSnapshot(limits: limits, fetchedAt: Date())
    }

    private static func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

private struct RawUsage: Decodable {
    struct Window: Decodable { let utilization: Double?; let resets_at: String? }
    struct Limit: Decodable {
        struct Scope: Decodable {
            struct Model: Decodable { let display_name: String? }
            let model: Model?
        }
        let kind: String
        let percent: Double?
        let severity: String?
        let resets_at: String?
        let scope: Scope?
    }
    let five_hour: Window?
    let seven_day: Window?
    let limits: [Limit]?
}
