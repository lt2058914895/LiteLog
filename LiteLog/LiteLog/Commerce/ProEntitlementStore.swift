import Combine
import Foundation
import StoreKit
import os

@MainActor
final class ProEntitlementStore: ObservableObject {
    static let shared = ProEntitlementStore()
    static let productID = "lt.LiteLog.pro.lifetime"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app",
        category: "ProEntitlementStore"
    )

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var loadError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
        Task { [weak self] in
            await self?.prepare()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var displayPrice: String {
        product?.displayPrice ?? "—"
    }

    func prepare() async {
        await refreshEntitlements()
        await loadProduct()
    }

    func loadProduct() async {
        guard product == nil, !isLoadingProduct else { return }
        isLoadingProduct = true
        loadError = nil
        defer { isLoadingProduct = false }

        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            if product == nil {
                loadError = NSLocalizedString("pro.error.product", comment: "")
            }
        } catch {
            Self.logger.error("Failed to load Pro product: \(error.localizedDescription)")
            loadError = NSLocalizedString("pro.error.product", comment: "")
        }
    }

    func refreshEntitlements() async {
        var hasEntitlement = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                hasEntitlement = true
            }
        }
        isPro = hasEntitlement
    }

    func purchase() async throws {
        guard !isPro else { return }
        guard let product else { throw ProError.productUnavailable }
        guard !isPurchasing else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                return
            case .pending:
                throw ProError.pending
            @unknown default:
                throw ProError.unknown
            }
        } catch let error as ProError {
            throw error
        } catch {
            Self.logger.error("Pro purchase failed: \(error.localizedDescription)")
            throw ProError.purchaseFailed
        }
    }

    func restore() async throws {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            guard isPro else { throw ProError.nothingToRestore }
        } catch let error as ProError {
            throw error
        } catch {
            Self.logger.error("Restore failed: \(error.localizedDescription)")
            throw ProError.restoreFailed
        }
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID else {
            return
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw ProError.verificationFailed
        }
    }
}

enum ProError: LocalizedError {
    case productUnavailable
    case pending
    case verificationFailed
    case purchaseFailed
    case nothingToRestore
    case restoreFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return NSLocalizedString("pro.error.product", comment: "")
        case .pending:
            return NSLocalizedString("pro.error.pending", comment: "")
        case .verificationFailed:
            return NSLocalizedString("pro.error.verification", comment: "")
        case .purchaseFailed:
            return NSLocalizedString("pro.error.purchase", comment: "")
        case .nothingToRestore:
            return NSLocalizedString("pro.error.nothing.to.restore", comment: "")
        case .restoreFailed:
            return NSLocalizedString("pro.error.restore", comment: "")
        case .unknown:
            return NSLocalizedString("pro.error.unknown", comment: "")
        }
    }
}

enum AppLinks {
    static let appStore = URL(string: "https://apps.apple.com/app/id6768547821")!
    static let review = URL(string: "https://apps.apple.com/app/id6768547821?action=write-review")!
    static let support = URL(string: "https://lt2058914895.github.io/LiteLog/support.html")!
    static let privacy = URL(string: "https://lt2058914895.github.io/LiteLog/privacy.html")!
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
