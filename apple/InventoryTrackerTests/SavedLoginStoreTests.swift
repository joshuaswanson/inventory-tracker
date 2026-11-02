import Foundation
import Testing
@testable import InventoryTracker

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
