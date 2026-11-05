import Foundation

// A backend-synced group step challenge: a shared leaderboard across devices, keyed by a short code.

struct GroupMember: Codable, Identifiable, Hashable {
    let name: String
    let fur: String
    let steps: Int
    let week: String
    var id: String { "\(name)#\(steps)" }
}

struct LoadedGroup: Codable, Equatable {
    let code: String
    let name: String
    let goal: Int
    let members: [GroupMember]

    var total: Int { members.reduce(0) { $0 + $1.steps } }
}

enum GroupError: LocalizedError {
    case notConfigured, noGroup, server(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured: loc("Group challenges need the Meowtrek server.")
        case .noGroup: loc("That group code wasn't found.")
        case .server(let m): m
        }
    }
}

enum GroupsAPI {
    struct MemberBody: Encodable { let name: String; let fur: String; let steps: Int; let week: String }
    private struct CreateBody: Encodable { let name: String; let goal: Int; let member: MemberBody }
    private struct JoinBody: Encodable { let code: String; let member: MemberBody }
    private struct LeaveBody: Encodable { let code: String }
    private struct ServerError: Decodable { let error: String }

    static func create(device: String, name: String, goal: Int, member: MemberBody) async throws -> LoadedGroup {
        try await send("groups/create", device: device, body: CreateBody(name: name, goal: goal, member: member))
    }
    static func join(device: String, code: String, member: MemberBody) async throws -> LoadedGroup {
        try await send("groups/join", device: device, body: JoinBody(code: code, member: member))
    }
    static func sync(device: String, code: String, member: MemberBody) async throws -> LoadedGroup {
        try await send("groups/sync", device: device, body: JoinBody(code: code, member: member))
    }
    static func leave(device: String, code: String) async throws {
        _ = try await raw("groups/leave", device: device, body: LeaveBody(code: code))
    }

    private static func send(_ path: String, device: String, body: Encodable) async throws -> LoadedGroup {
        let data = try await raw(path, device: device, body: body)
        return try JSONDecoder().decode(LoadedGroup.self, from: data)
    }

    private static func raw(_ path: String, device: String, body: Encodable) async throws -> Data {
        guard let base = AppConfig.apiBase else { throw GroupError.notConfigured }
        var req = URLRequest(url: base.appending(path: path))
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(device, forHTTPHeaderField: "X-Meowtrek-Device")
        req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let msg = (try? JSONDecoder().decode(ServerError.self, from: data))?.error ?? "server_\(code)"
            if msg == "no_group" { throw GroupError.noGroup }
            throw GroupError.server(loc("Group error (\(msg))"))
        }
        return data
    }
}

/// Lets us encode an existing `Encodable` value held behind the protocol.
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
