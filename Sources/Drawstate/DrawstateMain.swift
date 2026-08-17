import SwiftUI

@main
struct DrawstateApp: App {
    @NSApplicationDelegateAdaptor(DrawstateAppDelegate.self) private var appDelegate

    init() {
        let defaults = UserDefaults.standard
        try? LaunchAtLoginManager.ensureCurrentConfiguration()
        if defaults.object(forKey: "launchAtLoginConfigured") == nil {
            defaults.set(true, forKey: "launchAtLoginConfigured")
        }
    }

    var body: some Scene {
        Settings {
            DrawstateSettings()
        }
    }
}
