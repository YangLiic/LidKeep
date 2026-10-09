import SwiftUI

struct LidKeepApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var language = LanguageSettings()

    var body: some Scene {
        Window(Text(verbatim: "LidKeep"), id: "main") {
            ContentView()
                .environmentObject(model)
                .environmentObject(language)
                .environment(\.locale, language.locale)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 680)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
                .environmentObject(language)
                .environment(\.locale, language.locale)
        } label: {
            Image(systemName: model.status.lidAwakeWanted ? "laptopcomputer" : "moon.zzz")
                .help(model.lidLine.0)
        }
    }
}
