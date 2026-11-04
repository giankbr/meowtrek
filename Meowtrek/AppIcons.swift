import SwiftUI
import UIKit

struct AppIconOption: Identifiable {
    let id: String
    let name: String
    let plus: Bool
    var iconName: String? { id == "Default" ? nil : "AppIcon-\(id)" }
}

struct AppIconPicker: View {
    @Environment(AppState.self) private var state
    @State private var current = UIApplication.shared.alternateIconName
    @State private var paywall = false

    private let options = [
        AppIconOption(id: "Default", name: loc("Meadow"), plus: false),
        AppIconOption(id: "Snow", name: loc("Snow day"), plus: false),
        AppIconOption(id: "Night", name: loc("Night walk"), plus: true),
        AppIconOption(id: "Pumpkin", name: loc("Pumpkin"), plus: true),
        AppIconOption(id: "Lilac", name: loc("Lilac"), plus: true),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(options) { o in
                    let on = current == o.iconName
                    Button { pick(o) } label: {
                        VStack(spacing: 6) {
                            Image("icon-preview-\(o.id)").resizable().scaledToFit()
                                .frame(width: 62, height: 62)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? Color.grass : .clear, lineWidth: 3).padding(-3))
                                .overlay(alignment: .topTrailing) {
                                    if o.plus && !state.isPlus {
                                        Image(systemName: "crown.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.sunDark)
                                            .padding(4).background(Circle().fill(Color.paper)).offset(x: 6, y: -6)
                                    }
                                }
                            Text(o.name).font(.game(11, .semibold)).foregroundStyle(on ? Color.grassDark : Color.inkSoft)
                        }
                    }
                    .buttonStyle(SquishStyle())
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 2)
        }
        .sheet(isPresented: $paywall) { PaywallView() }
    }

    private func pick(_ o: AppIconOption) {
        guard !o.plus || state.isPlus else { paywall = true; return }
        guard UIApplication.shared.supportsAlternateIcons, current != o.iconName else { return }
        UIApplication.shared.setAlternateIconName(o.iconName) { error in
            if error == nil {
                current = o.iconName
                Telemetry.track("app_icon_changed")
            }
        }
    }
}
