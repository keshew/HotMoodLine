import SwiftUI

@main
struct SessionMoodApp: App {
    
    init() {
        let key = "didAddInitialCoins"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(5000, forKey: "balance")
            UserDefaults.standard.set(true, forKey: key)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
