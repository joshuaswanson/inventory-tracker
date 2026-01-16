import SwiftUI
import SwiftData

struct AddVendorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var contactName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Vendor Details") {
                    TextField("Vendor Name", text: $name)
                    TextField("Contact Name (Optional)", text: $contactName)
                }

                Section("Contact Information (Optional)") {
                    TextField("Phone", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Address", text: $address)
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Vendor")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addVendor()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        .padding()
        #endif
    }

    private func addVendor() {
        let vendor = Vendor(
            name: name,
            contactName: contactName,
            phone: phone,
            email: email,
            address: address,
            notes: notes
        )
        modelContext.insert(vendor)
        dismiss()
    }
}

#Preview {
    AddVendorView()
        .modelContainer(for: Vendor.self, inMemory: true)
}
