import Foundation

/// Where the choices live between launches.
///
/// One key holding the whole struct as JSON, rather than a key per field: the
/// settings are read and written together, and a half-migrated set of
/// defaults keys is a worse thing to debug than a decode that failed.
struct SettingsStore {
    static let key = "settings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Settings {
        guard let data = defaults.data(forKey: Self.key) else { return .defaults }
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            // Rather than refuse to start. A settings file this app cannot
            // read is a settings file worth losing.
            Log.app.error("the settings would not decode, using the defaults: \(error.localizedDescription, privacy: .public)")
            return .defaults
        }
    }

    func save(_ settings: Settings) {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: Self.key)
        } catch {
            Log.app.error("the settings would not encode: \(error.localizedDescription, privacy: .public)")
        }
    }
}
