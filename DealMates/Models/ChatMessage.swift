import Foundation

struct ChatMessage: Identifiable, Codable {
    var id: String
    var planId: String
    var senderId: String
    var senderName: String
    var senderAvatarURL: String?
    var text: String
    var timestamp: Date
    var isSystem: Bool

    // For system messages: a stable kind identifier + the user ids referenced by the
    // template (e.g. ["alice-uid"] for "joined", ["leaver-uid", "newOrg-uid"] for
    // "left_promoted"). Names are resolved live from `UserCache` at render time so the
    // chat reflects each user's current display name.
    var systemKind: String?
    var systemArgs: [String]?

    init(planId: String, senderId: String, senderName: String, senderAvatarURL: String? = nil,
         text: String, isSystem: Bool = false,
         systemKind: String? = nil, systemArgs: [String]? = nil) {
        self.id              = UUID().uuidString.lowercased()
        self.planId          = planId
        self.senderId        = senderId
        self.senderName      = senderName
        self.senderAvatarURL = senderAvatarURL
        self.text            = text
        self.timestamp       = Date()
        self.isSystem        = isSystem
        self.systemKind      = systemKind
        self.systemArgs      = systemArgs
    }
}

extension ChatMessage {
    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderAvatarURL = "sender_avatar_url"
        case text
        case timestamp
        case isSystem = "is_system"
        case systemKind = "system_kind"
        case systemArgs = "system_args"
    }
}

extension ChatMessage {
    /// User-facing text. Three paths, in priority order:
    ///   1. Structured system messages (post-migration) → render localized template
    ///      with names resolved live from `UserCache`.
    ///   2. Legacy system messages (pre-migration, no `system_kind`) → pattern-match
    ///      the stored English text to recover the kind + names, then render the
    ///      localized template with the snapshot names embedded in the text.
    ///   3. Anything else → return `text` verbatim (regular chat content).
    @MainActor
    func displayText() -> String {
        // 1. Structured system message
        if let kind = systemKind, let args = systemArgs {
            let cache = UserCache.shared
            let names = args.map {
                cache.name(for: $0, fallback: AppLocalization.string("Diner"))
            }
            return formatSystem(kind: kind, names: names) ?? text
        }

        // 2. Legacy English system message — try to parse the action out
        if isSystem, let (kind, names) = legacyParse(text) {
            return formatSystem(kind: kind, names: names) ?? text
        }

        // 3. Plain chat message
        return text
    }

    private func formatSystem(kind: String, names: [String]) -> String? {
        let key: String
        switch kind {
        case "joined":         key = "system.joined"
        case "left":           key = "system.left"
        case "left_promoted":  key = "system.left_promoted"
        case "removed":        key = "system.removed"
        default:               return nil
        }
        let format = AppLocalization.string(key)
        return String(format: format, arguments: names.map { $0 as CVarArg })
    }

    /// Recovers `(kind, names)` from the four hardcoded English strings the
    /// app used to write before the `system_kind` migration. Snapshot names
    /// embedded in the text — if Alice has since renamed, the legacy entry
    /// keeps the old name.
    private func legacyParse(_ raw: String) -> (kind: String, names: [String])? {
        // "%@ joined the plan 🙌"
        if let r = raw.range(of: " joined the plan") {
            let name = String(raw[..<r.lowerBound])
            return ("joined", [name])
        }
        // "%1$@ left. %2$@ is now the organiser."
        if let leftR = raw.range(of: " left. "),
           let orgR = raw.range(of: " is now the organiser") {
            let leaver = String(raw[..<leftR.lowerBound])
            let newOrg = String(raw[leftR.upperBound..<orgR.lowerBound])
            return ("left_promoted", [leaver, newOrg])
        }
        // "%@ left the plan"
        if raw.hasSuffix(" left the plan") {
            let name = String(raw.dropLast(" left the plan".count))
            return ("left", [name])
        }
        // "%1$@ removed %2$@ from the plan."
        if let remR = raw.range(of: " removed "),
           let fromR = raw.range(of: " from the plan") {
            let remover = String(raw[..<remR.lowerBound])
            let target = String(raw[remR.upperBound..<fromR.lowerBound])
            return ("removed", [remover, target])
        }
        return nil
    }
}
