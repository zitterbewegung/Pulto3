import SwiftUI

struct MainTabView: View {
    @State private var hasPlayedStartupSound = false
    
    var body: some View {
        TabView {
            EnvironmentView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
            
            TestFeaturesView()
                .tabItem {
                    Image(systemName: "testtube.2")
                    Text("Testing")
                }
        }
        .onAppear {
            // Play startup sound when main view appears (only once)
            if !hasPlayedStartupSound {
                AudioManager.shared.playStartupSound()
                hasPlayedStartupSound = true
            }
        }
    }
}
