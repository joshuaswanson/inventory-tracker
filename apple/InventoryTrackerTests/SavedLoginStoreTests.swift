import Foundation
import Testing
@testable import InventoryTracker

@Suite struct SupplierTests {
    @Test func everySupplierHasAUniqueIDAndSecureAddresses() {
        #expect(Set(Supplier.all.map(\.id)).count == Supplier.all.count)
        for supplier in Supplier.all {
            #expect(supplier.ordersURL.scheme == "https")
            #expect(supplier.signInURL.scheme == "https")
            #expect(Supplier.withID(supplier.id) == supplier)
        }
        #expect(Supplier.supplyClinic.ordersURL(page: 1).absoluteString == "https://www.supplyclinic.com/checkout/orders")
        #expect(Supplier.supplyClinic.ordersURL(page: 3).absoluteString == "https://www.supplyclinic.com/checkout/orders?page=3")
    }

    @Test func settingsRememberSuppliersEmailsAndImportDates() {
        let name = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(SupplierSettings.added(in: defaults) == [.supplyClinic])
        #expect(Supplier.all.contains(.benco))
        SupplierSettings.setAdded([], in: defaults)
        #expect(SupplierSettings.added(in: defaults).isEmpty)

        defaults.set("old@example.com", forKey: "supplyClinicEmail")
        #expect(SupplierSettings.email(for: .supplyClinic, in: defaults) == "old@example.com")
        SupplierSettings.setEmail("new@example.com", for: .supplyClinic, in: defaults)
        #expect(SupplierSettings.email(for: .supplyClinic, in: defaults) == "new@example.com")

        #expect(SupplierSettings.lastImport(for: .supplyClinic, in: defaults) == nil)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        SupplierSettings.setLastImport(now, for: .supplyClinic, in: defaults)
        #expect(SupplierSettings.lastImport(for: .supplyClinic, in: defaults) == now)
    }

    @Test func eachSupplierKeepsItsOwnSavedLogin() {
        #expect(SavedLoginStore(supplierID: "supplyclinic").service == "com.joshuaswanson.inventorytracker.supplyclinic")
        #expect(SavedLoginStore(supplierID: "other").service != SavedLoginStore(supplierID: "supplyclinic").service)
    }
}

@Suite struct SavedLoginStoreTests {
    private func makeStore() -> SavedLoginStore {
        SavedLoginStore(service: "com.joshuaswanson.inventorytracker.tests.\(UUID().uuidString)")
    }

    @Test func emptyStoreHasNoLogin() throws {
        let store = makeStore()
        #expect(store.savedEmail() == nil)
        #expect(try store.password() == nil)
    }

    @Test func savedLoginRoundTrips() throws {
        let store = makeStore()
        defer { store.delete() }
        let password = #"p"a'ss\word`${1}<b> é"#
        try store.save(email: "office@example.com", password: password)
        #expect(store.savedEmail() == "office@example.com")
        #expect(try store.password() == password)
    }

    @Test func savingAgainReplacesTheOnlyLogin() throws {
        let store = makeStore()
        defer { store.delete() }
        try store.save(email: "old@example.com", password: "one")
        try store.save(email: "new@example.com", password: "two")
        #expect(store.savedEmail() == "new@example.com")
        #expect(try store.password() == "two")
    }

    @Test func deleteRemovesTheLogin() throws {
        let store = makeStore()
        try store.save(email: "office@example.com", password: "one")
        store.delete()
        #expect(store.savedEmail() == nil)
    }
}
