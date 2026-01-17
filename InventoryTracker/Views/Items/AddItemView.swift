import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedUnit: UnitOfMeasure = .each
    @State private var reorderLevel = 10
    @State private var isPerishable = false
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
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
                                    Image(systemName: "photo")
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

                Section("Item Details") {
                    TextField("Item Name", text: $name)

                    Picker("Unit of Measure", selection: $selectedUnit) {
                        ForEach(UnitOfMeasure.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }

                    Stepper("Reorder Level: \(reorderLevel)", value: $reorderLevel, in: 0...1000)

                    Toggle("Perishable Item", isOn: $isPerishable)
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
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
                        .navigationTitle("Add Item")
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
                        addItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 350)
        .padding()
        #endif
    }

    private func addItem() {
        let item = Item(
            name: name,
            unitOfMeasure: selectedUnit,
            reorderLevel: reorderLevel,
            isPerishable: isPerishable,
            notes: notes,
            imageData: imageData
        )
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: Item.self, inMemory: true)
}
