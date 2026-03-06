import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var selectedTab = 0

    private var myProfile: UserProfile? {
        profiles.first(where: { !$0.isPartnerProfile })
    }

    var body: some View {
        Group {
            if let profile = myProfile {
                mainTabView(profile: profile)
            } else if !UserDefaults.standard.bool(forKey: Constants.onboardingCompleteKey) {
                OnboardingView {}
            } else {
                OnboardingView {}
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func mainTabView(profile: UserProfile) -> some View {
        TabView(selection: $selectedTab) {
            // Tab 0 — Home (daily summary)
            DashboardView(profile: profile)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            // Tab 1 — Food (nutrition log)
            NutritionView(profile: profile)
                .tabItem { Label("Food", systemImage: "fork.knife") }
                .tag(1)

            // Tab 2 — Move (activity + auto-steps)
            ActivityView(profile: profile)
                .tabItem { Label("Move", systemImage: "figure.run") }
                .tag(2)

            // Tab 3 — Insights (charts, trends, AI coaching)
            InsightsView(profile: profile)
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                .tag(3)

            // Tab 4 — Me (settings, strength, partner)
            MeTabView(profile: profile)
                .tabItem { Label("Me", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(.leanGreen)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.cardBackground)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Me Tab (Settings + Strength + Partner)

struct MeTabView: View {
    let profile: UserProfile
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Section picker
                        Picker("Section", selection: $selectedSection) {
                            Text("Profile").tag(0)
                            Text("Strength").tag(1)
                            Text("Partner").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        switch selectedSection {
                        case 0:
                            SettingsView(profile: profile)
                                .navigationBarHidden(true)
                        case 1:
                            StrengthView(profile: profile)
                                .navigationBarHidden(true)
                        case 2:
                            PartnerView(myProfile: profile)
                                .navigationBarHidden(true)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
