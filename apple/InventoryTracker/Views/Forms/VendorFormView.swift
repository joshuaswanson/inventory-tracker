import SwiftData
import SwiftUI

struct VendorFormView: View {
    private let vendor: Vendor?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var contactName: String
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var notes: String
    @State private var errorMessage: String?

    init(vendor: Vendor?) {
        self.vendor = vendor
        _name = State(initialValue: vendor?.name ?? "")
        _contactName = State(initialValue: vendor?.contactName ?? "")
        _phone = State(initialValue: vendor.map { Format.phone($0.phone) } ?? "")
        _email = State(initialValue: vendor?.email ?? "")
        _address = State(initialValue: vendor?.address ?? "")
        _notes = State(initialValue: vendor?.notes ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        FormSheet(
            title: vendor == nil ? "New Vendor" : "Edit Vendor",
            canSave: !trimmedName.isEmpty,
            errorMessage: errorMessage,
            onSave: save
        ) {
            LabeledField(title: "Vendor Name", isRequired: true) {
                ThemedTextField("e.g. DentalCo Supply", text: $name)
            }
            LabeledField(title: "Contact Name") {
                ThemedTextField("Primary contact person", text: $contactName)
            }
            FieldRow {
                LabeledField(title: "Phone") {
                    ThemedTextField("(555) 123-4567", text: $phone, keyboard: .phone)
                }
                LabeledField(title: "Email") {
                    ThemedTextField("vendor@example.com", text: $email, keyboard: .email)
                }
            }
            LabeledField(title: "Address") {
                ThemedTextField("Street address", text: $address)
            }
            LabeledField(title: "Notes") {
                ThemedTextArea(placeholder: "Optional notes", text: $notes)
            }
        }
    }

    private func save() {
        let target = vendor ?? Vendor(name: trimmedName)
        target.name = trimmedName
        target.contactName = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.phone = Format.digits(phone)
        target.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        target.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if vendor == nil { modelContext.insert(target) }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
