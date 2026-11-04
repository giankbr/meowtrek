import SwiftUI

struct ClosetView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var slot: Slot = .hat
    @State private var trying: Item?
    @State private var showLooks = false
    @State private var hop = 0
    @State private var showShare = false

    var body: some View {
        VStack(spacing: 0) {
            header
            stage
            picker
        }
        .foregroundStyle(Color.ink)
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if let item = trying { TryOnBar(item: item) { trying = nil }.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .onChange(of: slot) { withAnimation(.snappy) { trying = nil } }
        .sheet(isPresented: $showLooks) { LooksView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showShare) { ShareCardsView(kind: .outfit) }
        .sensoryFeedback(.selection, trigger: state.equipped)
        .onChange(of: state.equipped) { hop += 1 }
    }

    private var header: some View {
        HStack(spacing: 10) {
            RoundIconButton(symbol: "chevron.left", size: 38) { dismiss() }
            VStack(alignment: .leading, spacing: 4) {
                StoryHeading(text: loc("Wardrobe"), size: 26)
                Text("Dress up \(state.petName)").font(.game(12, .medium)).foregroundStyle(Color.inkSoft).lineLimit(1)
            }
            .layoutPriority(-1)
            Spacer(minLength: 4)
            RoundIconButton(symbol: "square.and.arrow.up", size: 38) { showShare = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8).padding(.bottom, 12)
    }

    private var stage: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                LinearGradient(colors: [Color(hex: 0xE6F2EC), Color(hex: 0xFBF3E1)], startPoint: .top, endPoint: .bottom)
                Circle().fill(Color.sun.opacity(0.18)).frame(width: 220).offset(x: 110, y: -90)
                Circle().fill(Color.bubble.opacity(0.14)).frame(width: 180).offset(x: -130, y: 30)
                Ellipse().fill(Color.grass.opacity(0.22)).frame(width: 210, height: 34).offset(y: 92)
                CatView(outfit: previewOutfit, size: 170, mood: .happy, hop: hop)
                    .offset(y: -6)
                    .onTapGesture { hop += 1 }
                VStack {
                    HStack(alignment: .top) {
                        Button { showLooks = true } label: { tagLabel(loc("Outfits"), "sparkles", tilt: -4, color: .bubble) }
                            .buttonStyle(SquishStyle())
                        Spacer()
                        NavigationLink { ShopView(filter: slot) } label: { tagLabel(loc("Shop"), "bag.fill", tilt: 4, color: .sun) }
                            .buttonStyle(SquishStyle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 18)
            }
            .padding(.bottom, 30)
            bookmarks
        }
        .frame(height: 360)
        .clipped()
    }

    private func tagLabel(_ title: String, _ symbol: String, tilt: Double, color: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.story(14, .semibold))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 7)
            .background(PaperShape(radius: 4, seed: title.count).fill(Color.paper))
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1.5)
            .taped(.top, angle: -tilt * 1.5, color: color, width: 36)
            .rotationEffect(.degrees(tilt))
    }

    /// Slots as bookmark tabs poking up from the page below; the open one joins the page.
    private var bookmarks: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Slot.allCases) { s in bookmark(s) }
            }
            .padding(.horizontal, 12)
        }
        .scrollClipDisabled()
    }

    private func bookmark(_ s: Slot) -> some View {
        let on = slot == s
        let shape = UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous)
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { slot = s } } label: {
            VStack(spacing: 2) {
                Group {
                    if let item = state.outfit[s] {
                        ItemArt(item: item, size: 28)
                    } else {
                        Image(systemName: s.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.inkSoft.opacity(0.55))
                    }
                }
                .frame(height: 30)
                Text(s.title).font(.game(11, on ? .bold : .medium)).foregroundStyle(on ? Color.ink : Color.inkSoft).lineLimit(1)
            }
            .frame(width: 56)
            .padding(.top, 7).padding(.bottom, on ? 12 : 6)
            .background(shape.fill(on ? Color.cream : Color(hex: 0xEAE0CB)))
            .overlay(alignment: .top) {
                if on { Capsule().fill(Color.sunDark.opacity(0.7)).frame(width: 22, height: 3).padding(.top, 3) }
            }
        }
        .buttonStyle(SquishStyle())
    }

    private var previewOutfit: [Slot: Item] {
        var o = state.outfit
        if let t = trying { o[t.slot] = t }
        return o
    }

    private var picker: some View {
        let items = Catalog.items(for: slot)
            .filter { $0.forSale || state.owned.contains($0.id) || state.activeEvent?.event.id == $0.event }
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 8) {
                        StoryHeading(text: loc("\(slot.title) drawer"), size: 22, color: .grass)
                        Text(trying.map { loc("Trying on \($0.name)") } ?? state.outfit[slot].map { loc("Wearing \($0.name)") } ?? loc("Nothing on yet"))
                            .font(.game(12, .medium)).foregroundStyle(trying == nil ? Color.inkSoft : Color.sunDark).lineLimit(1)
                    }
                    Spacer()
                    Text("\(items.filter { state.owned.contains($0.id) }.count) of \(items.count) collected")
                        .font(.story(13, .semibold)).italic().foregroundStyle(Color.inkSoft)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                    if slot != .fur { noneCell }
                    ForEach(items) { item in
                        ItemCell(item: item) {
                            if state.owned.contains(item.id) {
                                trying = nil
                                withAnimation(.spring) { state.toggle(item) }
                            } else if item.event != nil {
                                state.show(loc("Earn it during the \(state.content.events.first { $0.id == item.event }?.name ?? "") event."))
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { trying = trying == item ? nil : item }
                                hop += 1
                            }
                        }
                        .overlay(PaperShape(radius: 8).stroke(trying == item ? Color.sunDark : .clear, lineWidth: 2.5))
                    }
                }
            }
            .padding(16)
            .padding(.bottom, trying == nil ? 20 : 110)
        }
    }

    private var noneCell: some View {
        let on = state.outfit[slot] == nil && trying == nil
        return Button {
            trying = nil
            withAnimation(.spring) { state.unequip(slot) }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "circle.slash")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(on ? Color.grassDark : Color.inkSoft.opacity(0.6))
                    .frame(maxWidth: .infinity).frame(height: 74)
                    .background(SketchSquare(on: on))
                Text("Nothing").font(.story(13, .semibold)).foregroundStyle(Color.ink)
                Text(on ? loc("Wearing") : loc("Take off")).font(.game(12, .semibold))
                    .foregroundStyle(on ? Color.grassDark : Color.inkSoft)
            }
            .padding(7)
            .card(padding: 0, radius: 8)
        }
        .buttonStyle(SquishStyle())
    }
}

/// Bottom bar while an unowned item is previewed on the cat.
struct TryOnBar: View {
    @Environment(AppState.self) private var state
    let item: Item
    let close: () -> Void

    var body: some View {
        let have = state.balance(item.currency)
        let afford = have >= item.price
        HStack(spacing: 12) {
            ItemArt(item: item, size: 44)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cream))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.game(16, .bold)).lineLimit(1)
                HStack(spacing: 4) {
                    ArtView(id: item.currency.art, size: 14, line: 1.2)
                    Text(afford ? "\(item.price)" : loc("Need \(item.price - have) more")).font(.game(12, .semibold))
                        .foregroundStyle(afford ? Color.ink : Color.tomato)
                }
            }
            Spacer(minLength: 4)
            RoundIconButton(symbol: "xmark", size: 36) { withAnimation(.snappy) { close() } }
            Button {
                state.buy(item)
                withAnimation(.snappy) { close() }
            } label: { Text("Buy").frame(minWidth: 56) }
            .buttonStyle(.chunky(.grass, text: .white, radius: 16, padH: 14, padV: 10))
            .disabled(!afford)
        }
        .foregroundStyle(Color.ink)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.paper))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 88)
    }
}

/// Shop preview: the cat wearing an item before buying it.
struct TryOnSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var hop = 0

    var body: some View {
        var outfit = state.outfit
        outfit[item.slot] = item
        let have = state.balance(item.currency)
        return VStack(spacing: 16) {
            ZStack {
                LinearGradient(colors: [Color(hex: 0xD8F1FF), Color(hex: 0xF3FBE8)], startPoint: .top, endPoint: .bottom)
                Ellipse().fill(Color.grassLight).frame(width: 200, height: 40).offset(y: 112)
                CatView(outfit: outfit, size: 170, mood: .happy, hop: hop)
            }
            .frame(height: 290)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture { hop += 1 }
            VStack(spacing: 4) {
                Text(item.name).font(.game(22, .bold))
                HStack(spacing: 4) {
                    ArtView(id: item.currency.art, size: 18, line: 1.4)
                    Text("\(item.price)").font(.game(16, .bold))
                    Text(loc("· you have \(have.formatted())")).font(.game(13, .medium)).foregroundStyle(Color.inkSoft)
                }
            }
            if state.owned.contains(item.id) {
                Button { state.toggle(item); dismiss() } label: { Text(state.equipped[item.slot] == item.id ? "Take off" : "Wear").frame(maxWidth: .infinity) }
                    .buttonStyle(.chunky(.grass, text: .white, radius: 18, padV: 14))
            } else {
                Button { state.buy(item); dismiss() } label: {
                    Text(have >= item.price ? loc("Buy for \(item.price)") : loc("Need \(item.price - have) more")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.chunky(.grass, text: .white, radius: 18, padV: 14))
                .disabled(have < item.price)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(20)
        .presentationDetents([.height(480)])
        .presentationBackground(Color.cream)
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
                    Text("Sets").font(.story(20, .bold)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    SetsSection()
                    Text("Saved outfits").font(.story(20, .bold)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    if state.looks.isEmpty {
                        Text("No outfits yet. Dress up, then save it here.")
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
            .paperBackground()
            .navigationTitle("Outfits")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Name this outfit", isPresented: $naming) {
                TextField("Spooky stroll", text: $name)
                Button("Save") { state.saveLook(name); name = "" }
                Button("Cancel", role: .cancel) { name = "" }
            }
        }
        .presentationBackground(Color.cream)
    }
}
