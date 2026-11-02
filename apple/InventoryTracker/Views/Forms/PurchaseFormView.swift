import SwiftData
import SwiftUI

struct PurchaseFormView: View {
    private let purchase: Purchase?
    @Query private var items: [Item]
    @Query private var vendors: [Vendor]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var itemID: String
    @State private var vendorID: String
    @State private var date: String
    @State private var quantity: String
    @State private var price: String
    @State private var productNumber: String
    @State private var expirationDate: String?
    @State private var notes: String
    @State private var errorMessage: String?

    init(purchase: Purchase?, preselectedItemID: String?) {
        self.purchase = purchase
        _itemID = State(initialValue: purchase?.item?.id ?? preselectedItemID ?? "")
        _vendorID = State(initialValue: purchase?.vendor?.id ?? "")
        _date = State(initialValue: purchase?.date ?? Day.today)
        _quantity = State(initialValue: "\(purchase?.quantity ?? 1)")
        _price = State(initialValue: purchase.map { "\($0.pricePerUnit)" } ?? "")
        _productNumber = State(initialValue: purchase?.productNumber ?? "")
        _expirationDate = State(initialValue: purchase?.expirationDate)
        _notes = State(initialValue: purchase?.notes ?? "")
    }

    private var sortedItems: [Item] {
        items.sorted { orderedText($0.name, $1.name, ascending: true) }
    }

    private var sortedVendors: [Vendor] {
        vendors.sorted { orderedText($0.name, $1.name, ascending: true) }
    }

    private var parsedQuantity: Int? {
        Int(quantity.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
    }

    private var quantityError: String? {
        guard let purchase, let quantity = parsedQuantity, quantity < purchase.unitsTaken else { return nil }
        return "\(purchase.unitsTaken) from this batch are already used or counted."
    }

    private var parsedPrice: Double? {
        Double(price.trimmingCharacters(in: .whitespaces)).flatMap { $0 >= 0 ? $0 : nil }
    }

    var body: some View {
        FormSheet(
            title: purchase == nil ? "New Purchase" : "Edit Purchase",
            canSave: !itemID.isEmpty && parsedQuantity != nil && parsedPrice != nil && quantityError == nil,
            errorMessage: quantityError ?? errorMessage,
            onSave: save
        ) {
            LabeledField(title: "Item", isRequired: true) {
                ThemedPicker(selection: $itemID) {
                    Text("Select an item...").tag("")
                    ForEach(sortedItems) { Text($0.name).tag($0.id) }
                }
            }
            LabeledField(title: "Vendor") {
                ThemedPicker(selection: $vendorID) {
                    Text("None").tag("")
                    ForEach(sortedVendors) { Text($0.name).tag($0.id) }
                }
            }
            LabeledField(title: "Date") {
                DayField(day: $date)
            }
            FieldRow {
                LabeledField(title: "Quantity", isRequired: true) {
                    ThemedTextField(text: $quantity, keyboard: .number)
                }
                LabeledField(title: "Price per Unit", isRequired: true) {
                    ThemedTextField("0.00", text: $price, keyboard: .decimal)
                }
            }
            FieldRow {
                LabeledField(title: "Product Number") {
                    ThemedTextField("Optional", text: $productNumber)
                }
                LabeledField(title: "Expiration Date") {
                    OptionalDayField(day: $expirationDate)
                }
            }
            LabeledField(title: "Notes") {
                ThemedTextArea(placeholder: "Optional notes", text: $notes)
            }
        }
    }

    private func save() {
        guard let quantity = parsedQuantity, let price = parsedPrice, let item = items.first(where: { $0.id == itemID }) else {
            return
        }
        let target = purchase ?? Purchase(date: date, item: nil, quantity: quantity, pricePerUnit: price)
        if purchase == nil { modelContext.insert(target) }
        if let purchase, purchase.item?.id != item.id {
            BatchOperations.release(purchase, in: modelContext)
        }
        target.date = date
        target.item = item
        target.vendor = vendors.first { $0.id == vendorID }
        target.quantity = quantity
        target.pricePerUnit = price
        target.productNumber = productNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        target.expirationDate = expirationDate
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
