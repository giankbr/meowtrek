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
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .padding(5)
                                .background(SketchSquare(on: on))
                                .overlay(alignment: .topTrailing) {
                                    if on {
                                        Stamp(text: loc("On"), color: .grassDark, size: 28, angle: 14).offset(x: 8, y: -8)
                                    } else if o.plus && !state.isPlus {
                                        Image(systemName: "crown.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.sunDark)
                                            .padding(4).background(Circle().fill(Color.paper)).offset(x: 6, y: -6)
                                    }
                                }
                            Text(o.name).font(.story(12, on ? .bold : .medium)).foregroundStyle(on ? Color.grassDark : Color.inkSoft)
                        }
                    }
                    .buttonStyle(SquishStyle())
                }
            }
            .padding(.vertical, 10).padding(.horizontal, 4)
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
