import SwiftUI

@main
struct MeowtrekApp: App {
    @State private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(.light)
                .fontDesign(.rounded)
                .onOpenURL { url in
                    if url.host == "friend", !state.addFriend(from: url.absoluteString) {
                        state.show("That friend link didn't work")
                    }
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active where state.onboarded:
                        Task {
                            await state.steps.load()
                            state.refresh()
                        }
                    case .background:
                        state.save()
                        Notifier.reschedule(state)
                    default: break
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var tab = UserDefaults.standard.integer(forKey: "tab")

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
                .badge(state.inboxCount)
            NavigationStack { JourneyView() }
                .tabItem { Label("Journey", systemImage: "figure.walk") }.tag(1)
            NavigationStack { ShopView() }
                .tabItem { Label("Shop", systemImage: "bag.fill") }.tag(2)
            NavigationStack { SocialView() }
                .tabItem { Label("Social", systemImage: "person.2.fill") }.tag(3)
            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }.tag(4)
        }
        .tint(.leafDark)
        .overlay(alignment: .top) {
            if let t = state.toast {
                Text(t)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { state.toast = nil }
                    .task(id: t) {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation { state.toast = nil }
                    }
            }
        }
        .sensoryFeedback(.success, trigger: state.toast)
        .fullScreenCover(isPresented: Binding(get: { !state.onboarded }, set: { _ in })) {
            OnboardingView()
        }
    }
}
