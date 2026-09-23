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
        Window("Drawstate", id: "menu-bar-placeholder") { EmptyView() }
            .commands { settingsCommand }
    }

    @CommandsBuilder private var settingsCommand: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { appDelegate.showSettings() }
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}
