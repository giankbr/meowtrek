import SwiftUI

struct ClosetView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var slot: Slot = .hat
    @State private var buying: Item?
    @State private var showLooks = false

    private let left: [Slot] = [.fur, .hat, .eyes, .neck]
    private let right: [Slot] = [.body, .hand, .bag, .shoes]

    var body: some View {
        VStack(spacing: 0) {
            header
            stage
            picker
        }
        .background(Color.cream)
        .toolbar(.hidden, for: .navigationBar)
        .buyDialog($buying)
        .sheet(isPresented: $showLooks) { LooksView().presentationDetents([.medium, .large]) }
        .sensoryFeedback(.selection, trigger: state.equipped)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.headline)
                    .frame(width: 36, height: 36)
                    .background(.white, in: Circle())
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Closet").font(.title2.weight(.bold))
                Text("Tap to wear").font(.caption).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Button { showLooks = true } label: {
                Label("Looks", systemImage: "sparkles").font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.white, in: Capsule())
            }
            NavigationLink { ShopView(filter: slot) } label: {
                Label("Shop", systemImage: "bag").font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.white, in: Capsule())
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var stage: some View {
        HStack(alignment: .center) {
            VStack(spacing: 10) { ForEach(left) { slotButton($0) } }
            Spacer()
            CatView(outfit: state.outfit, size: 180)
                .animation(.spring, value: state.equipped)
            Spacer()
            VStack(spacing: 10) { ForEach(right) { slotButton($0) } }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(LinearGradient(colors: [Color(hex: 0xEAF2E0), Color(hex: 0xDDEBCF)], startPoint: .top, endPoint: .bottom))
    }

    private func slotButton(_ s: Slot) -> some View {
        Button { withAnimation(.snappy) { slot = s } } label: {
            VStack(spacing: 3) {
                Group {
                    if let item = state.outfit[s] {
                        ItemArt(item: item, size: 34)
                    } else {
                        Image(systemName: s.icon).foregroundStyle(Color.inkSoft.opacity(0.45))
                    }
                }
                .frame(width: 50, height: 50)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(slot == s ? Color.leaf : .clear, lineWidth: 2))
                Text(s.title).font(.caption2).foregroundStyle(Color.inkSoft)
            }
        }
        .buttonStyle(.plain)
    }

    private var picker: some View {
        let items = Catalog.items(for: slot).filter { $0.forSale || state.owned.contains($0.id) || state.activeEvent?.event.id == $0.event }
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(slot.title).font(.headline)
                    Text("· \(state.outfit[slot]?.name ?? "nothing on")").font(.caption).foregroundStyle(Color.inkSoft)
                    Spacer()
                    Text("\(items.filter { state.owned.contains($0.id) }.count) yours")
                        .font(.caption).foregroundStyle(Color.inkSoft)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(items) { item in
                        ItemCell(item: item) {
                            if state.owned.contains(item.id) {
                                withAnimation(.spring) { state.toggle(item) }
                            } else {
                                buying = item
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.cream)
    }
}

struct LooksView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var naming = false
    @State private var name = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { naming = true } label: { Label("Save current look", systemImage: "plus.circle.fill") }
                    Button(role: .destructive) { withAnimation { state.undress() } } label: {
                        Label("Undress", systemImage: "arrow.uturn.backward")
                    }
                }
                Section("Saved") {
                    if state.looks.isEmpty {
                        Text("No looks yet. Dress up, then save it here.").font(.subheadline).foregroundStyle(Color.inkSoft)
                    }
                    ForEach(state.looks) { look in
                        Button {
                            withAnimation(.spring) { state.apply(look) }
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                CatView(outfit: state.outfit(of: look), size: 48)
                                    .frame(width: 56, height: 60)
                                    .background(Color.cream, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading) {
                                    Text(look.name).font(.headline).foregroundStyle(Color.ink)
                                    Text("\(look.equipped.count) pieces").font(.caption).foregroundStyle(Color.inkSoft)
                                }
                            }
                        }
                    }
                    .onDelete(perform: state.deleteLooks)
                }
            }
            .navigationTitle("Looks")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Name this look", isPresented: $naming) {
                TextField("Spooky stroll", text: $name)
                Button("Save") { state.saveLook(name); name = "" }
                Button("Cancel", role: .cancel) { name = "" }
            }
        }
    }
}
