import AppKit
import SwiftUI

struct DrawstateWelcomeView: View {
    let appIcon: NSImage
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 26)

            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 144, height: 144)
                .accessibilityLabel("Drawstate app icon")

            Text("Hey, welcome to Drawstate.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            Text("Created by Kian Konrad Tajbakhsh")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 7)

            Text("See your Mac’s live power draw, battery flow, charge level, and time remaining directly from the menu bar.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 410)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 12) {
                welcomeFeature("bolt.fill", "Live power telemetry")
                welcomeFeature("menubar.rectangle", "Available in the menu bar when you launch it")
                welcomeFeature("lock.shield.fill", "Local, private, and open source")
            }
            .padding(.top, 24)

            Spacer(minLength: 24)

            Button("Get Started", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

            Text("You can reopen this welcome window from Settings at any time.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 42)
        .frame(width: 520, height: 560)
        .background(.ultraThinMaterial)
    }

    private func welcomeFeature(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
