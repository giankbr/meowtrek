import Observation
import StoreKit

@Observable
final class Store {
    static let plusIDs = ["id.gian.meowtrek.plus.monthly", "id.gian.meowtrek.plus.yearly"]
    static let gemPacks: [String: Int] = [
        "id.gian.meowtrek.gems.small": 20,
        "id.gian.meowtrek.gems.medium": 120,
        "id.gian.meowtrek.gems.large": 300,
    ]

    var plusProducts: [Product] = []
    var gemProducts: [Product] = []
    var isPlus = false
    var plusJWS: String?
    var plusRenewal: Date?
    var purchasing = false
    var loaded = false

    /// Credits gems once per transaction id; returns false when it was already credited.
    @ObservationIgnored var creditGems: (Int, String) -> Bool = { _, _ in false }
    /// Tags purchases so App Store Server Notifications can be matched back to this install.
    @ObservationIgnored var accountToken: UUID?
    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.handle(result) }
        }
    }

    deinit { updates?.cancel() }

    @MainActor
    func load() async {
        if let all = try? await Product.products(for: Self.plusIDs + Array(Self.gemPacks.keys)) {
            plusProducts = all.filter { Self.plusIDs.contains($0.id) }.sorted { $0.price < $1.price }
            gemProducts = all.filter { Self.gemPacks[$0.id] != nil }.sorted { $0.price < $1.price }
        }
        loaded = true
        for await result in Transaction.unfinished { await handle(result) }
        await refreshEntitlements()
    }

    @MainActor
    func refreshEntitlements() async {
        var plus = false
        var jws: String?
        var renewal: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, Self.plusIDs.contains(t.productID), t.revocationDate == nil else { continue }
            plus = true
            jws = result.jwsRepresentation
            renewal = t.expirationDate
        }
        isPlus = plus
        plusJWS = jws
        plusRenewal = renewal
    }

    @MainActor
    @discardableResult
    func buy(_ product: Product) async -> Bool {
        purchasing = true
        defer { purchasing = false }
        let options: Set<Product.PurchaseOption> = accountToken.map { [.appAccountToken($0)] } ?? []
        guard let result = try? await product.purchase(options: options) else { return false }
        if case .success(let verification) = result {
            await handle(verification)
            return true
        }
        return false
    }

    @MainActor
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    @MainActor
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else { return }
        if let gems = Self.gemPacks[t.productID], t.revocationDate == nil {
            _ = creditGems(gems * t.purchasedQuantity, String(t.id))
        }
        await t.finish()
        await refreshEntitlements()
    }

    func gems(for product: Product) -> Int { Self.gemPacks[product.id] ?? 0 }
}
