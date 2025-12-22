//
//  CustomerFormView.swift
//  Diary
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import QuickLook
import MapKit

struct CustomerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var item: Customer?   // nil = add, non-nil = edit

    @State private var custName = ""
    @State private var custAddress = ""
    @State private var custPhone = ""
    @State private var custEmail = ""
    @State private var custDescription = ""
    @State private var pickedLocation: PickedLocation? = nil
    @State private var showLocationPicker = false

    // Local editable arrays
    @State private var locations: [Location] = []
    @State private var attachments: [Attachment] = []

    // For pickers
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showDocPicker = false
    @State private var previewAttachment: Attachment? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer Info") {
                    TextField("Name", text: $custName)
                    TextField("Address", text: $custAddress)
                    TextField("Phone", text: $custPhone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $custEmail)
                        .keyboardType(.emailAddress)
                    TextField("Description", text: $custDescription, axis: .vertical)

                    // Locations UI: multiple locations support
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            showLocationPicker = true
                        } label: {
                            Label("Add Location", systemImage: "mappin.and.ellipse")
                        }

                        if locations.isEmpty {
                            Text("No locations yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(locations.enumerated()), id: \.element) { index, loc in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(loc.name)
                                            .font(.subheadline)
                                        if let lat = loc.latitude, let lon = loc.longitude {
                                            Text(String(format: "Lat: %.4f, Lon: %.4f", lat, lon))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        locations.remove(at: index)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Section("Attachments") {
                    if attachments.isEmpty {
                        Text("No attachments yet")
                            .foregroundColor(.secondary)
                    }

                    ForEach(attachments) { attachment in
                        HStack {
                            if attachment.fileType == "image",
                               let uiImage = UIImage(data: attachment.fileData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                            }

                            Text(attachment.fileName)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                previewAttachment = attachment
                            } label: {
                                Image(systemName: "eye")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let index = attachments.firstIndex(where: { $0.id == attachment.id }) {
                                    attachments.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // --- Separate Add Buttons ---
                Section {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                        Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: selectedPhotos) { _, newItems in
                        Task {
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    let attachment = Attachment(
                                        fileName: "photo-\(UUID().uuidString).jpg",
                                        fileType: "image",
                                        fileData: data
                                    )
                                    // Insert into modelContext right away so the object belongs to the context
                                    modelContext.insert(attachment)
                                    attachments.append(attachment)
                                }
                            }
                            selectedPhotos.removeAll()
                        }
                    }

                    Button {
                        showDocPicker = true
                    } label: {
                        Label("Add Documents", systemImage: "doc.badge.plus")
                    }
                    .sheet(isPresented: $showDocPicker) {
                        DocumentPicker { newFiles in
                            // insert each attachment into modelContext so they are managed objects
                            for att in newFiles {
                                modelContext.insert(att)
                            }
                            attachments.append(contentsOf: newFiles)
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "New Customer" : "Edit Customer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let item = item {
                            // Update existing
                            item.custName = custName
                            item.custAddress = custAddress
                            item.custPhone = custPhone
                            item.custEmail = custEmail
                            item.custDescription = custDescription

                            // replace attachments & locations (overwrite)
                            // ensure locations are inserted into modelContext before attaching
                            for loc in locations {
                                // if not managed yet, insert. SwiftData usually synthesizes identity; this is safe to call repeatedly
                                modelContext.insert(loc)
                            }
                            item.locations = locations
                            item.attachments = attachments
                        } else {
                            // Add new
                            let newItem = Customer(timestamp: Date())
                            newItem.custName = custName
                            newItem.custAddress = custAddress
                            newItem.custPhone = custPhone
                            newItem.custEmail = custEmail
                            newItem.custDescription = custDescription

                            // insert and attach locations
                            for loc in locations {
                                modelContext.insert(loc)
                                newItem.locations.append(loc)
                            }

                            // attach attachments (already inserted earlier)
                            newItem.attachments.append(contentsOf: attachments)

                            modelContext.insert(newItem)
                        }
                        dismiss()
                    }
                    .disabled(custName.isEmpty)
                }
            }
            .onAppear {
                if let item = item {
                    // Pre-fill fields for editing
                    custName = item.custName
                    custAddress = item.custAddress
                    custPhone = item.custPhone
                    custEmail = item.custEmail
                    custDescription = item.custDescription
                    attachments = item.attachments
                    locations = item.locations
                }
            }
            .sheet(item: $previewAttachment) { attachment in
                AttachmentPreviewView(attachment: attachment)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet { picked in
                    // create a managed Location and append locally; inserted on Save (or immediately inserted below)
                    let loc = Location(name: picked.name, latitude: picked.coordinate.latitude, longitude: picked.coordinate.longitude)
                    // Insert immediately into context so it's managed (helps with SwiftData lifecycles)
                    modelContext.insert(loc)
                    locations.append(loc)
                }
            }
        }
    }
}

// DocumentPicker unchanged except earlier usage; keep same implementation as you had
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: ([Attachment]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item, .pdf, .image], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: ([Attachment]) -> Void
        init(onPick: @escaping ([Attachment]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var results: [Attachment] = []
            for url in urls {
                if let data = try? Data(contentsOf: url) {
                    let attachment = Attachment(
                        fileName: url.lastPathComponent,
                        fileType: url.pathExtension,
                        fileData: data
                    )
                    results.append(attachment)
                }
            }
            onPick(results)
        }
    }
}

