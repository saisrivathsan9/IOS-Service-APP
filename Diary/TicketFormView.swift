// TicketFormView.swift
// Supports attachments (photos + documents), location selection from customer's locations,
// and "Add New Location" via LocationPickerSheet which writes a Location into the customer's locations.

import SwiftUI
import SwiftData
import PhotosUI
import MapKit

struct TicketFormView: View {
    enum Result {
        case create(customer: Customer, serviceName: String, location: String, status: TicketStatus, attachments: [Attachment])
        case update(ticket: Ticket, customer: Customer, serviceName: String, location: String, status: TicketStatus, attachments: [Attachment])
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Removed ambiguous `sort: []` which caused "Generic parameter 'Element' could not be inferred"
    @Query private var customers: [Customer]

    var ticket: Ticket?
    var onSave: (Result) -> Void

    @State private var selectedCustomer: Customer?
    @State private var serviceName: String = ""
    @State private var locationChoice: String = "" // string name for display / storage
    @State private var status: TicketStatus = .pending

    // attachments local array
    @State private var attachments: [Attachment] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showDocPicker = false
    @State private var previewAttachment: Attachment? = nil

    // Location picker controls
    @State private var showLocationPicker = false
    // special flag representing "Add new location" selection in Picker
    private let addNewLocationID = "__ADD_NEW_LOCATION__"

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    if customers.isEmpty {
                        Text("No customers found. Please create a customer first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Customer", selection: $selectedCustomer) {
                            ForEach(customers) { customer in
                                Text(customer.custName.isEmpty ? "Unnamed Customer" : customer.custName)
                                    .tag(Optional(customer))
                            }
                        }
                    }
                }

                Section("Service") {
                    TextField("Service Name", text: $serviceName)
                }

                // Location selection: from customer's locations, or add new
                Section("Location") {
                    if let selectedCustomer {
                        // Build choices: each existing location name + "Add New Location"
                        let locationNames = selectedCustomer.locations.map { $0.name }
                        Picker("Location", selection: $locationChoice) {
                            ForEach(locationNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                            Text("Add New Location").tag(addNewLocationID)
                        }
                        .onChange(of: locationChoice) { newValue in
                            if newValue == addNewLocationID {
                                // present location picker to create new location and attach to selected customer
                                showLocationPicker = true
                            }
                        }

                        // preview chosen location
                        if !locationChoice.isEmpty && locationChoice != addNewLocationID {
                            Text("Selected: \(locationChoice)").font(.caption).foregroundColor(.secondary)
                        } else if selectedCustomer.locations.isEmpty {
                            Text("No saved locations for this customer. Use Add New Location to pick one.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select a customer first to choose from their saved locations.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(TicketStatus.allCases, id: \.self) { s in
                            Text(displayName(for: s)).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Attachments") {
                    if attachments.isEmpty {
                        Text("No attachments yet").foregroundColor(.secondary)
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
                                Image(systemName: "doc.fill").foregroundColor(.blue)
                            }
                            Text(attachment.fileName).lineLimit(1)
                            Spacer()
                            Button {
                                previewAttachment = attachment
                            } label: {
                                Image(systemName: "eye").foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let idx = attachments.firstIndex(where: { $0.id == attachment.id }) {
                                    attachments.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                        Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: selectedPhotos) { _, newItems in
                        Task {
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    let att = Attachment(fileName: "photo-\(UUID().uuidString).jpg", fileType: "image", fileData: data)
                                    modelContext.insert(att)
                                    attachments.append(att)
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
                            for att in newFiles {
                                modelContext.insert(att)
                            }
                            attachments.append(contentsOf: newFiles)
                        }
                    }
                }
            }
            .navigationTitle(ticket == nil ? "New Ticket" : "Edit Ticket")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let customer = selectedCustomer ?? customers.first else { return }

                        // If no explicit locationChoice chosen, try default (first location)
                        var finalLocation = locationChoice
                        if finalLocation.isEmpty, let first = customer.locations.first?.name {
                            finalLocation = first
                        }
                        // If still empty, leave empty string

                        if let ticket {
                            onSave(.update(ticket: ticket,
                                           customer: customer,
                                           serviceName: serviceName,
                                           location: finalLocation,
                                           status: status,
                                           attachments: attachments))
                        } else {
                            onSave(.create(customer: customer,
                                           serviceName: serviceName,
                                           location: finalLocation,
                                           status: status,
                                           attachments: attachments))
                        }
                        dismiss()
                    }
                    .disabled(serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || customers.isEmpty)
                }
            }
            .onAppear {
                if let ticket {
                    selectedCustomer = ticket.customer
                    serviceName = ticket.serviceName
                    locationChoice = ticket.locationName
                    status = ticket.status
                    attachments = ticket.attachments
                } else {
                    selectedCustomer = customers.first
                    if let first = selectedCustomer, !first.locations.isEmpty {
                        locationChoice = first.locations.first!.name
                    }
                }
            }
            .sheet(item: $previewAttachment) { attachment in
                AttachmentPreviewView(attachment: attachment)
            }
            // Present the shared LocationPickerSheet to add a new location
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet { picked in
                    // create and insert Location into context and attach to selected customer
                    guard let selCust = selectedCustomer else { return }
                    let loc = Location(name: picked.name, latitude: picked.coordinate.latitude, longitude: picked.coordinate.longitude)
                    modelContext.insert(loc)
                    // attach to customer
                    var mut = selCust.locations
                    mut.append(loc)
                    selCust.locations = mut
                    // select the newly added location
                    locationChoice = loc.name
                }
            }
        }
    }

    private func displayName(for status: TicketStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        }
    }
}

