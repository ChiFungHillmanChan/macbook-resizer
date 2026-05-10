import Foundation

public enum URLRoutingError: Error, Equatable, Sendable {
    case unsupportedScheme
    case unknownRoute
    case missingIdentifier
}

public enum URLRouter {
    /// Parses a `scene://...` URL into an `AutomationCommand`.
    /// Pure: no I/O, no store reads. ID-or-name disambiguation
    /// (UUID parse vs case-insensitive name lookup) happens later
    /// in `Coordinator` which has the stores.
    public static func parse(_ url: URL) -> Result<AutomationCommand, URLRoutingError> {
        guard url.scheme?.lowercased() == "scene" else {
            return .failure(.unsupportedScheme)
        }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.host?.lowercased(), !host.isEmpty
        else {
            return .failure(.unknownRoute)
        }

        // URL grammar: scene://<host>/<path-segment>?<query>
        // Path segments are everything after the leading "/".
        let segments = url.pathComponents.filter { $0 != "/" }
        let force = boolQueryValue(comps, key: "force") ?? false

        switch host {
        case "workspace":
            guard let raw = segments.first else { return .failure(.missingIdentifier) }
            let id = parseIdentifier(raw)
            return .success(.activateWorkspace(id: makeWorkspaceID(id), force: force))

        case "layout":
            guard let raw = segments.first else { return .failure(.missingIdentifier) }
            let id = parseIdentifier(raw)
            let screen = parseScreen(comps)
            return .success(.applyLayout(id: makeLayoutID(id), force: force, screen: screen))

        case "free-mode":
            guard let action = segments.first?.lowercased() else { return .failure(.missingIdentifier) }
            switch action {
            case "toggle": return .success(.toggleFreeMode)
            case "on":     return .success(.setFreeMode(enabled: true))
            case "off":    return .success(.setFreeMode(enabled: false))
            default:       return .failure(.unknownRoute)
            }

        default:
            return .failure(.unknownRoute)
        }
    }

    // MARK: - Helpers

    private enum RawIdentifier {
        case uuid(UUID)
        case name(String)
    }

    private static func parseIdentifier(_ raw: String) -> RawIdentifier {
        let decoded = raw.removingPercentEncoding ?? raw
        if let uuid = UUID(uuidString: decoded) {
            return .uuid(uuid)
        }
        return .name(decoded)
    }

    private static func makeLayoutID(_ raw: RawIdentifier) -> LayoutIdentifier {
        switch raw {
        case .uuid(let u): return .uuid(u)
        case .name(let n): return .name(n)
        }
    }

    private static func makeWorkspaceID(_ raw: RawIdentifier) -> WorkspaceIdentifier {
        switch raw {
        case .uuid(let u): return .uuid(u)
        case .name(let n): return .name(n)
        }
    }

    private static func parseScreen(_ comps: URLComponents) -> ScreenSelector {
        guard let raw = comps.queryItems?.first(where: { $0.name == "screen" })?.value?.lowercased() else {
            return .underMouse
        }
        switch raw {
        case "under-mouse", "undermouse": return .underMouse
        case "primary": return .primary
        default:
            if let n = Int(raw) { return .index(n) }
            return .underMouse
        }
    }

    private static func boolQueryValue(_ comps: URLComponents, key: String) -> Bool? {
        guard let raw = comps.queryItems?.first(where: { $0.name == key })?.value?.lowercased() else {
            return nil
        }
        switch raw {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return nil
        }
    }
}
