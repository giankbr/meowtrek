import SwiftUI

struct ClosetView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var slot: Slot = .hat
    @State private var buying: Item?
    @State private var showLooks = false
    @State private var hop = 0
    @State private var showShare = false

    private let left: [Slot] = [.fur, .hat, .eyes, .neck]
    private let right: [Slot] = [.body, .hand, .bag, .shoes]

    var body: some View {
        VStack(spacing: 0) {
            header
            stage
            picker
        }
        .foregroundStyle(Color.ink)
        .background(Color.cream)
        .toolbar(.hidden, for: .navigationBar)
        .buyDialog($buying)
        .sheet(isPresented: $showLooks) { LooksView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showShare) { ShareCardsView(kind: .outfit) }
        .sensoryFeedback(.selection, trigger: state.equipped)
        .onChange(of: state.equipped) { hop += 1 }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: { Image(systemName: "chevron.left").font(.game(16, .black)) }
                .buttonStyle(.chunky(.paper, radius: 20, padH: 11, padV: 8))
            VStack(alignment: .leading, spacing: -2) {
                Text("Closet").font(.game(28, .black))
                Text("Tap to wear").font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                .buttonStyle(.chunky(.paper, padH: 10, padV: 7))
            Button { showLooks = true } label: { Label("Looks", systemImage: "sparkles") }
                .buttonStyle(.chunky(.bubble, padH: 10, padV: 7))
            NavigationLink { ShopView(filter: slot) } label: { Label("Shop", systemImage: "bag.fill") }
                .buttonStyle(.chunky(.sun, padH: 10, padV: 7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var stage: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xD8F1FF), Color(hex: 0xF3FBE8)], startPoint: .top, endPoint: .bottom)
            Ellipse().sticker(Color.grassLight, 3).frame(width: 220, height: 46).offset(y: 124)
            HStack(alignment: .center) {
                VStack(spacing: 8) { ForEach(left) { slotButton($0) } }
                Spacer()
                VStack(spacing: 8) { ForEach(right) { slotButton($0) } }
            }
            .padding(.horizontal, 14)
            CatView(outfit: state.outfit, size: 176, mood: .happy, hop: hop)
                .offset(y: 4)
                .onTapGesture { hop += 1 }
        }
        .frame(height: 340)
    }

    private func slotButton(_ s: Slot) -> some View {
        let on = slot == s
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { slot = s } } label: {
            VStack(spacing: 3) {
                Group {
                    if let item = state.outfit[s] {
                        ItemArt(item: item, size: 38)
                    } else {
                        Image(systemName: s.icon).font(.system(size: 18, weight: .black)).foregroundStyle(Color.inkSoft.opacity(0.5))
                    }
                }
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(on ? Color.sun : Color.paper))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
                .offset(y: on ? 2 : 0)
                Text(s.title).font(.game(11, on ? .black : .bold)).foregroundStyle(on ? Color.ink : Color.inkSoft)
            }
        }
        .buttonStyle(SquishStyle())
    }

    private var picker: some View {
        let items = Catalog.items(for: slot)
            .filter { $0.forSale || state.owned.contains($0.id) || state.activeEvent?.event.id == $0.event }
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(slot.title).font(.game(22, .black))
                    Text(state.outfit[slot]?.name ?? "nothing on").font(.game(13, .bold)).foregroundStyle(Color.inkSoft)
                    Spacer()
                    Tag(text: "\(items.filter { state.owned.contains($0.id) }.count) yours", color: .grass)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
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
            .padding(.bottom, 20)
        }
    }
}

struct LooksView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var naming = false
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Button { naming = true } label: { Label("Save current", systemImage: "plus") }
                            .buttonStyle(.chunky(.grass, text: .white))
                        Button { withAnimation { state.undress() } } label: { Label("Undress", systemImage: "arrow.uturn.backward") }
                            .buttonStyle(.chunky(.paper))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if state.looks.isEmpty {
                        Text("No looks yet. Dress up, then save it here.")
                            .font(.game(14, .bold)).foregroundStyle(Color.inkSoft).padding(.top, 20)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(state.looks) { look in
                            Button {
                                withAnimation(.spring) { state.apply(look) }
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    CatView(outfit: state.outfit(of: look), size: 90, animated: false)
                                    Text(look.name).font(.game(15, .black)).lineLimit(1)
                                    Text("\(look.equipped.count) pieces").font(.game(11, .bold)).foregroundStyle(Color.inkSoft)
                                }
                                .frame(maxWidth: .infinity)
                                .card(padding: 10)
                            }
                            .buttonStyle(SquishStyle())
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    if let i = state.looks.firstIndex(of: look) { state.deleteLooks(at: IndexSet(integer: i)) }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .foregroundStyle(Color.ink)
            .background(Color.cream)
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
