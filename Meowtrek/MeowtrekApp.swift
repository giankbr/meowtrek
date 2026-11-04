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
                            await Devices.refreshAll(state)
                            if state.store.loaded { await state.store.refreshEntitlements() } else { await state.store.load() }
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
                .tabItem { Label("Journey", systemImage: "map.fill") }.tag(1)
            NavigationStack { ShopView() }
                .tabItem { Label("Shop", systemImage: "bag.fill") }.tag(2)
            NavigationStack { SocialView() }
                .tabItem { Label("Social", systemImage: "person.2.fill") }.tag(3)
            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }.tag(4)
        }
        .tint(.grassDark)
        .overlay { FXLayer(fx: state.fx) }
        .overlay(alignment: .bottom) {
            if let t = state.toast {
                ToastView(toast: t)
                    .padding(.bottom, 96)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { state.toast = nil }
                    .task(id: t.id) {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation(.spring) { if state.toast?.id == t.id { state.toast = nil } }
                    }
            }
        }
        .sensoryFeedback(.success, trigger: state.toast?.id)
        .fullScreenCover(isPresented: Binding(get: { !state.onboarded }, set: { _ in })) {
            OnboardingView()
        }
    }
}
