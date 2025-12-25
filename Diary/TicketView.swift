// TicketView.swift
// Updated: tap opens details, long-press status dropdown, detail view status/edit support

import SwiftUI
import SwiftData

struct TicketView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tickets: [Ticket]
    @State private var showForm = false
    @State private var editingTicket: Ticket? = nil

    // optional ticket search in master list
    @State private var searchText: String = ""

    var body: some View {
        NavigationSplitView {
            ZStack {
                Color.white.ignoresSafeArea()

                // Precompute filtered arrays
                let filtered = tickets.filter { ticket in
                    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? true
                    : (ticket.serviceName.lowercased().contains(searchText.lowercased()) ||
                       ticket.locationName.lowercased().contains(searchText.lowercased()) ||
                       ticket.customer.custName.lowercased().contains(searchText.lowercased()))
                }

                let inProgressTickets = filtered.filter { $0.status == .inProgress }
                let pendingTickets = filtered.filter { $0.status == .pending }
                let doneTickets = filtered.filter { $0.status == .done }

                List {
                    TicketSection(title: "In Progress",
                                  tickets: inProgressTickets,
                                  onEdit: { t in editingTicket = t; showForm = true },
                                  onDelete: { offsets in deleteItems(at: offsets, in: inProgressTickets) },
                                  onChangeStatus: changeStatus(_:to:))

                    TicketSection(title: "Pending",
                                  tickets: pendingTickets,
                                  onEdit: { t in editingTicket = t; showForm = true },
                                  onDelete: { offsets in deleteItems(at: offsets, in: pendingTickets) },
                                  onChangeStatus: changeStatus(_:to:))

                    TicketSection(title: "Done",
                                  tickets: doneTickets,
                                  onEdit: { t in editingTicket = t; showForm = true },
                                  onDelete: { offsets in deleteItems(at: offsets, in: doneTickets) },
                                  onChangeStatus: changeStatus(_:to:))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .navigationTitle("Tickets")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tickets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingTicket = nil
                        showForm = true
                    } label: {
                        Label("Add Ticket", systemImage: "plus")
                    }
                }
            }
            // Explicit initializer to avoid ambiguity
            .sheet(isPresented: $showForm) {
                TicketFormView(ticket: editingTicket, onSave: { result in
                    switch result {
                    case .create(let customer, let serviceName, let location, let status, let attachments):
                        // dateCreated set here automatically on creation
                        let new = Ticket(customer: customer,
                                         dateCreated: Date(),
                                         status: status,
                                         serviceName: serviceName,
                                         locationName: location)
                        new.attachments.append(contentsOf: attachments)
                        if status == .done { new.dateClosed = Date() }
                        modelContext.insert(new)
                    case .update(let ticket, let customer, let serviceName, let location, let status, let attachments):
                        // update fields in-place
                        ticket.customer = customer
                        ticket.serviceName = serviceName
                        ticket.locationName = location
                        ticket.status = status
                        ticket.attachments = attachments
                        if status == .done, ticket.dateClosed == nil {
                            ticket.dateClosed = Date()
                        } else if status != .done {
                            ticket.dateClosed = nil
                        }
                    }
                    editingTicket = nil
                })
            }
        } detail: {
            Text("Select a ticket")
                .foregroundStyle(.secondary)
                .background(Color.white)
        }
    }

    private func deleteItems(at offsets: IndexSet, in source: [Ticket]) {
        withAnimation {
            for index in offsets {
                let item = source[index]
                modelContext.delete(item)
            }
        }
    }

    /// Set ticket status and adjust dateClosed automatically
    private func changeStatus(_ ticket: Ticket, to newStatus: TicketStatus) {
        withAnimation {
            ticket.status = newStatus
            if newStatus == .done {
                ticket.dateClosed = Date()
            } else {
                ticket.dateClosed = nil
            }
        }
    }
}


/// Section that renders tickets; the row includes a long-press menu to change status.
private struct TicketSection: View {
    let title: String
    let tickets: [Ticket]
    let onEdit: (Ticket) -> Void
    let onDelete: (IndexSet) -> Void
    let onChangeStatus: (Ticket, TicketStatus) -> Void

    var body: some View {
        Section(title) {
            ForEach(tickets) { ticket in
                NavigationLink {
                    // Opens detail view on tap
                    TicketDetailView(ticket: ticket) { updatedTicket in
                        // callback when detail edits saved — not necessary but provided if you want callback
                        // no-op here; changes are already persisted in SwiftData modelContext
                    }
                } label: {
                    TicketRow(ticket: ticket, onLongPressChange: { status in
                        onChangeStatus(ticket, status)
                    })
                }
                .contextMenu { // extra menu on row if system supports it
                    Button("Edit") { onEdit(ticket) }
                    Divider()
                    Button {
                        onChangeStatus(ticket, .pending)
                    } label: { Text("Set Pending") }
                    Button {
                        onChangeStatus(ticket, .inProgress)
                    } label: { Text("Set In Progress") }
                    Button {
                        onChangeStatus(ticket, .done)
                    } label: { Text("Set Done") }
                }
            }
            .onDelete(perform: onDelete)
        }
    }
}

/// Row view. Tap navigates (handled by outer NavigationLink). Long-press shows status menu (dropdown).
private struct TicketRow: View {
    let ticket: Ticket
    let onLongPressChange: (TicketStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ticket.serviceName.isEmpty ? "Untitled Service" : ticket.serviceName)
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(statusColor(for: ticket.status))
                    Text(displayName(for: ticket.status))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            HStack(spacing: 8) {
                Text(ticket.customer.custName.isEmpty ? "Unnamed Customer" : ticket.customer.custName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ticket.dateCreated, format: Date.FormatStyle(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let closed = ticket.dateClosed {
                    Text("Closed: \(closed, format: .dateTime.year().month().day())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        // long-press presents a contextual menu using confirmationDialog (iOS-friendly)
        .onLongPressGesture {
            // show a simple action sheet style menu: we use UIContextMenu above for richer options,
            // but here provide a simple long-press flow calling the handler to cycle to next status.
            // To show a dropdown with explicit choices, we use the menu presented by contextMenu (above).
            // As a fallback, we cycle status on long press:
            cycleStatus()
        }
    }

    private func cycleStatus() {
        let next: TicketStatus
        switch ticket.status {
        case .pending: next = .inProgress
        case .inProgress: next = .done
        case .done: next = .pending
        }
        onLongPressChange(next)
    }

    private func displayName(for status: TicketStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        }
    }

    private func statusColor(for status: TicketStatus) -> Color {
        switch status {
        case .pending: return .red
        case .inProgress: return .yellow
        case .done: return .green
        }
    }
}


/// Ticket detail view: shows ticket details, allows status updates and editing.
struct TicketDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let ticket: Ticket
    var onSaveCallback: ((Ticket) -> Void)? = nil

    @State private var showEditSheet: Bool = false
    @State private var statusSelection: TicketStatus

    // attachment preview
    @State private var showAttachmentPreview: Attachment? = nil

    init(ticket: Ticket, onSaveCallback: ((Ticket) -> Void)? = nil) {
        self.ticket = ticket
        self.onSaveCallback = onSaveCallback
        // initialize state from model object
        _statusSelection = State(initialValue: ticket.status)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ticket.serviceName.isEmpty ? "Untitled Service" : ticket.serviceName)
                    .font(.largeTitle.bold())

                HStack(spacing: 8) {
                    Text("Status:")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Circle().frame(width: 12, height: 12).foregroundColor(statusColor(for: statusSelection))
                        Text(displayName(for: statusSelection))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                }

                // Status editor
                Picker("Status", selection: $statusSelection) {
                    ForEach(TicketStatus.allCases, id: \.self) { s in
                        Text(displayName(for: s)).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: statusSelection) { new in
                    // apply change to model and adjust dateClosed
                    ticket.status = new
                    if new == .done {
                        ticket.dateClosed = ticket.dateClosed ?? Date()
                    } else {
                        ticket.dateClosed = nil
                    }
                    // allow caller to respond if needed
                    onSaveCallback?(ticket)
                }

                HStack {
                    Text("Customer:")
                        .font(.headline)
                    Text(ticket.customer.custName.isEmpty ? "Unnamed Customer" : ticket.customer.custName)
                }

                HStack {
                    Text("Location:")
                        .font(.headline)
                    Text(ticket.locationName.isEmpty ? "—" : ticket.locationName)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Created:")
                        .font(.headline)
                    Text(ticket.dateCreated, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }

                if let closed = ticket.dateClosed {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Closed:")
                            .font(.headline)
                        Text(closed, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                if !ticket.attachments.isEmpty {
                    Divider()
                    Text("Attachments").font(.headline)
                    ForEach(ticket.attachments) { attachment in
                        Button {
                            showAttachmentPreview = attachment
                        } label: {
                            if attachment.fileType == "image",
                               let uiImage = UIImage(data: attachment.fileData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                HStack {
                                    Image(systemName: "doc.fill")
                                    Text(attachment.fileName)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Ticket")
        .toolbar {
            // Edit button to open TicketFormView populated with this ticket
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            // present TicketFormView for editing; explicit onSave updates the same ticket
            TicketFormView(ticket: ticket, onSave: { result in
                switch result {
                case .create:
                    // shouldn't happen: creating from edit sheet - ignore
                    break
                case .update(let updatedTicket, let customer, let serviceName, let location, let status, let attachments):
                    // Patch the existing ticket (updatedTicket is same instance)
                    updatedTicket.customer = customer
                    updatedTicket.serviceName = serviceName
                    updatedTicket.locationName = location
                    updatedTicket.status = status
                    updatedTicket.attachments = attachments
                    if status == .done && updatedTicket.dateClosed == nil {
                        updatedTicket.dateClosed = Date()
                    } else if status != .done {
                        updatedTicket.dateClosed = nil
                    }
                }
                showEditSheet = false
            })
        }
        .sheet(item: $showAttachmentPreview) { attachment in
            AttachmentPreviewView(attachment: attachment)
        }
    }

    private func displayName(for status: TicketStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        }
    }

    private func statusColor(for status: TicketStatus) -> Color {
        switch status {
        case .pending: return .red
        case .inProgress: return .yellow
        case .done: return .green
        }
    }
}

#Preview {
    TicketView()
        .modelContainer(for: [Customer.self, Ticket.self], inMemory: true)
}

