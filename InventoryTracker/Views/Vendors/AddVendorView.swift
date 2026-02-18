import SwiftUI
import SwiftData
import PhotosUI

struct AddVendorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var contactName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Image (Optional)") {
                    HStack {
                        if let imageData, let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "building.2")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Select Photo", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.bordered)

                            if imageData != nil {
                                Button(role: .destructive) {
                                    imageData = nil
                                    selectedPhoto = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Vendor Details") {
                    TextField("Vendor Name", text: $name)
                    TextField("Contact Name (Optional)", text: $contactName)
                }

                Section("Contact Information (Optional)") {
                    TextField("Phone", text: $phone)
                        .onChange(of: phone) { _, newValue in
                            let formatted = PhoneFormatter.format(newValue)
                            if formatted != newValue {
                                phone = formatted
                            }
                        }
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
                        .font(.body)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
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
        #endif
    }

    private func addVendor() {
        let vendor = Vendor(
            name: name,
            contactName: contactName,
            phone: PhoneFormatter.stripFormatting(phone),
            email: email,
            address: address,
            notes: notes
        )
        vendor.imageData = imageData
        modelContext.insert(vendor)
        dismiss()
    }
}

#Preview {
    AddVendorView()
        .modelContainer(for: Vendor.self, inMemory: true)
}
