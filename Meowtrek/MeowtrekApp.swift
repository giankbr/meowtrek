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
            NavigationStack { HomeView() }.tag(0).toolbar(.hidden, for: .tabBar)
            NavigationStack { JourneyView() }.tag(1).toolbar(.hidden, for: .tabBar)
            NavigationStack { ShopView() }.tag(2).toolbar(.hidden, for: .tabBar)
            NavigationStack { SocialView() }.tag(3).toolbar(.hidden, for: .tabBar)
            NavigationStack { StatsView() }.tag(4).toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GameTabBar(selection: $tab, badge: state.inboxCount)
                .padding(.bottom, 2)
                .background(alignment: .bottom) {
                    LinearGradient(colors: [Color.cream.opacity(0), Color.cream], startPoint: .top, endPoint: .center)
                        .frame(height: 110)
                        .ignoresSafeArea(edges: .bottom)
                        .allowsHitTesting(false)
                }
        }
        .tint(.grassDark)
        .overlay { FXLayer(fx: state.fx) }
        .overlay(alignment: .top) {
            if let t = state.toast {
                ToastView(toast: t)
                    .padding(.top, 6)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .scale(scale: 0.6)).combined(with: .opacity))
                    .onTapGesture { state.toast = nil }
                    .task(id: t.id) {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation(.spring) { if state.toast?.id == t.id { state.toast = nil } }
                    }
            }
        }
        .sensoryFeedback(.success, trigger: state.toast?.id)
        .sensoryFeedback(.impact(weight: .medium), trigger: state.fx.tick)
        .fullScreenCover(isPresented: Binding(get: { !state.onboarded }, set: { _ in })) {
            OnboardingView()
        }
    }
}
