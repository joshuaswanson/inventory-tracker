#if os(iOS)
import XCTest

@MainActor
final class CoreFlowUITests: XCTestCase {
    private let itemName = "CSR Wrap 20\" x 20\" & Co"
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["INVENTORY_EPHEMERAL"] = "1"
        app.launch()
    }

    private func tapButton(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing button \(label)")
        button.tap()
    }

    private func replaceText(in identifier: String, with text: String) {
        let field = app.textFields[identifier].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), "Missing field \(identifier)")
        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + text)
    }

    private func expectText(_ text: String) {
        XCTAssertTrue(app.staticTexts[text].firstMatch.waitForExistence(timeout: 8), "Missing text \(text)")
    }

    private func chooseItem(named name: String) {
        let picker = app.buttons["Item"].firstMatch
        if picker.exists {
            picker.tap()
        } else {
            app.buttons["Select an item..."].firstMatch.tap()
        }
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 8), "Missing option \(name)")
        option.tap()
    }

    func testAddingAnItemThenPurchaseThenUsageUpdatesStockAndDeleteRemovesIt() {
        expectText("Welcome to Inventory Tracker")
        tapButton("Add Item")
        expectText("New Item")
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        replaceText(in: "Name", with: itemName)
        replaceText(in: "Reorder Level", with: "0")
        tapButton("Save")

        tapButton("Items")
        expectText(itemName)
        app.staticTexts[itemName].firstMatch.tap()
        expectText("Current Stock")

        tapButton("Actions")
        tapButton("Add Purchase")
        expectText("New Purchase")
        replaceText(in: "Quantity", with: "10")
        replaceText(in: "Price per Unit", with: "0")
        tapButton("Save")
        expectText("10")
        expectText("ea (reorder at 0)")

        tapButton("Actions")
        tapButton("Record Usage")
        replaceText(in: "Quantity", with: "3")
        tapButton("Save")
        expectText("7")

        tapButton("Actions")
        tapButton("Edit")
        expectText("Edit Item")
        XCTAssertEqual(app.textFields["Name"].firstMatch.value as? String, itemName)
        tapButton("Cancel")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let row = app.staticTexts[itemName].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.press(forDuration: 1.2)
        tapButton("Delete")
        let confirm = app.alerts.buttons["Delete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 8))
        confirm.tap()
        expectText("No items yet")
    }

    func testBatchesTrackUsageAndAShelfCountSetsRealNumbers() {
        tapButton("Add Item")
        replaceText(in: "Name", with: "Lidocaine")
        tapButton("Perishable item")
        replaceText(in: "Reorder Level", with: "0")
        tapButton("Save")

        tapButton("Items")
        expectText("Lidocaine")
        app.staticTexts["Lidocaine"].firstMatch.tap()

        for quantity in ["5", "3"] {
            tapButton("Actions")
            tapButton("Add Purchase")
            replaceText(in: "Quantity", with: quantity)
            replaceText(in: "Price per Unit", with: "1")
            tapButton("Save")
            expectText("Batches")
        }

        tapButton("Actions")
        tapButton("Record Usage")
        expectText("Batch")
        replaceText(in: "Quantity", with: "99")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Only'")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        replaceText(in: "Quantity", with: "2")
        tapButton("Save")
        expectText("6")

        tapButton("Actions")
        tapButton("Count Stock")
        expectText("Count Stock")
        replaceText(in: "Batch 1", with: "1")
        replaceText(in: "Batch 2", with: "1")
        tapButton("Save")
        expectText("2")
        XCTAssertFalse(app.staticTexts["Estimated from past usage. Count your shelf to confirm."].exists)
    }

    func testTourWalksThroughTheAppAndRemovesPracticeItems() {
        tapButton("Take a Quick Tour")
        for title in ["Your dashboard", "Your items", "What you buy", "What to reorder"] {
            expectText(title)
            tapButton("Next")
        }
        expectText("Backups are automatic")
        expectText("The items you just saw are practice items.")
        tapButton("Remove Practice Items")
        expectText("Welcome to Inventory Tracker")
        XCTAssertFalse(app.staticTexts["Backups are automatic"].exists)
    }

    func testImportOrdersListsSuppliersAndCanRemoveAndAddThem() {
        tapButton("Import Orders")
        expectText("SupplyClinic")
        expectText("Not imported yet")
        tapButton("Remove SupplyClinic")
        expectText("Add a supplier to get started.")
        tapButton("+ Add a Supplier")
        tapButton("SupplyClinic")
        expectText("Not imported yet")
        tapButton("Done")
        expectText("Welcome to Inventory Tracker")
    }

    func testVendorCanBeAddedAndAppearsInTheList() {
        tapButton("Vendors")
        tapButton("+ Add Vendor")
        replaceText(in: "Vendor Name", with: "Acme Dental")
        replaceText(in: "Email", with: "orders@example.com")
        tapButton("Save")
        expectText("Acme Dental")
    }
}
#endif
