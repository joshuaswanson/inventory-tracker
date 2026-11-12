import Foundation
import Observation
import SwiftData

struct SupplierImportResult {
    var summary: OrderImportSummary
    var warning: String?
}

enum SupplierImporter {
    /// Reads new orders through a signed-in browser and adds them to the inventory.
    static func importOrders(using browser: SupplierBrowser, into context: ModelContext) async throws -> SupplierImportResult {
        let supplier = browser.supplier
        let knownOrders = ImportWarning.knownOrders(from: supplier, in: context)
        let lines = try await browser.collectOrders(knownOrders: knownOrders)
        let previouslyImported = ImportWarning.previouslyImported(from: supplier, in: context)
        let summary = try OrderMerge.merge(lines, from: supplier, into: context)
        let foundNothingNew = lines.isEmpty && browser.ordersFound > 0
        let warning = foundNothingNew ? nil : ImportWarning.message(
            linesRead: lines.count, summary: summary, previouslyImported: previouslyImported, supplierName: supplier.name
        )
        if warning == nil {
            SupplierSettings.setLastImport(Date(), for: supplier)
        }
        return SupplierImportResult(summary: summary, warning: warning)
    }
}

enum ImportAllStatus: Equatable {
    case waiting
    case working
    case finished(newPurchases: Int)
    case needsSignIn
    case failed(String)
}

/// Imports from every supplier in turn, using the sign-ins already saved in the app's browser.
@Observable
final class ImportAllRun {
    private static let settlePolls = 160

    private(set) var statuses: [String: ImportAllStatus] = [:]
    private(set) var isRunning = false
    private(set) var newItemIDs: [String] = []
    private(set) var newPurchases = 0
    private(set) var hasFinished = false

    func status(of supplier: Supplier) -> ImportAllStatus? {
        statuses[supplier.id]
    }

    func run(_ suppliers: [Supplier], into context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        hasFinished = false
        newItemIDs = []
        newPurchases = 0
        statuses = Dictionary(uniqueKeysWithValues: suppliers.map { ($0.id, ImportAllStatus.waiting) })
        for supplier in suppliers {
            statuses[supplier.id] = .working
            statuses[supplier.id] = await importOne(supplier, into: context)
        }
        isRunning = false
        hasFinished = true
    }

    private func importOne(_ supplier: Supplier, into context: ModelContext) async -> ImportAllStatus {
        let browser = SupplierBrowser(supplier: supplier)
        browser.start()
        for _ in 0..<Self.settlePolls where browser.page == .loading {
            try? await Task.sleep(for: .milliseconds(250))
        }
        switch browser.page {
        case .signIn, .challenge:
            return .needsSignIn
        case .loading, .unreachable:
            return .failed("Couldn't reach \(supplier.name).")
        case .ready:
            break
        }
        do {
            let result = try await SupplierImporter.importOrders(using: browser, into: context)
            if result.warning != nil {
                return .failed("Something looks wrong. Press Import to see more.")
            }
            newItemIDs += result.summary.newItemIDs
            newPurchases += result.summary.imported
            return .finished(newPurchases: result.summary.imported)
        } catch ImportFailure.signInRequired, ImportFailure.challenge {
            return .needsSignIn
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
