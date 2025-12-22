// TicketView.swift
// Updated ticket list + sections + tap-to-cycle-status + attachments & editing support
// Background set to white to match CustomerView

import SwiftUI
import SwiftData

struct TicketView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tickets: [Ticket]
    @State private var showForm = false
    @State private var editingTicket: Ticket? = nil

    // optional ticket search in master list (if you want)
    @State private var searchText: String = ""

    var body: some View {
        NavigationSplitView {
            // Put a ZStack so we can set a white background behind the List
            ZStack {
                // white background fills the whole area
                Color.white
                    .ignoresSafeArea()

                // Precompute filtered arrays to keep view builder simpler
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
                                  onToggleStatus: toggleStatus(_:))

                    TicketSection(title: "Pending",
                                  tickets: pendingTickets,
                                  onEdit: { t in editingTicket = t; showForm = true },
                                  onDelete: { offsets in deleteItems(at: offsets, in: pendingTickets) },
                                  onToggleStatus: toggleStatus(_:))

                    TicketSection(title: "Done",
                                  tickets: doneTickets,
                                  onEdit: { t in editingTicket = t; showForm = true },
                                  onDelete: { offsets in deleteItems(at: offsets, in: doneTickets) },
                                  onToggleStatus: toggleStatus(_:))
                }
                .scrollContentBackground(.hidden) // hide default list background so our Color.white shows
                .listStyle(.plain)
            }
            .navigationTitle("Tickets")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tickets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { editingTicket = nil; showForm = true } label: {
                        Label("Add Ticket", systemImage: "plus")
                    }
                }
            }
            // Use explicit initializer labels for TicketFormView to avoid ambiguity
            .sheet(isPresented: $showForm) {
                TicketFormView(ticket: editingTicket, onSave: { result in
                    switch result {
                    case .create(let customer, let serviceName, let location, let status, let attachments):
                        let new = Ticket(customer: customer,
                                         dateCreated: Date(),
                                         status: status,
                                         serviceName: serviceName,
                                         locationName: location)
                        // attach attachments (they were already inserted into model context in the form)
                        new.attachments.append(contentsOf: attachments)
                        modelContext.insert(new)
                    case .update(let ticket, let customer, let serviceName, let location, let status, let attachments):
                        ticket.customer = customer
                        ticket.serviceName = serviceName
                        ticket.locationName = location
                        ticket.status = status
                        // replace attachments (we replace to match the form behavior)
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
                .background(Color.white) // ensure detail area also uses white background
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

    // cycles ticket status and handles dateClosed update
    private func toggleStatus(_ ticket: Ticket) {
        withAnimation {
            switch ticket.status {
            case .pending:
                ticket.status = .inProgress
                ticket.dateClosed = nil
            case .inProgress:
                ticket.status = .done
                ticket.dateClosed = Date()
            case .done:
                ticket.status = .pending
                ticket.dateClosed = nil
            }
        }
    }
}




// TicketSection + TicketRow + TicketDetailView + helpers
// Kept small and reused; TicketRow now supports tap-to-toggle via onTap closure and shows status color pill.

import SwiftUI

private struct TicketSection: View {
    let title: String
    let tickets: [Ticket]
    let onEdit: (Ticket) -> Void
    let onDelete: (IndexSet) -> Void
    let onToggleStatus: (Ticket) -> Void

    var body: some View {
        Section(title) {
            ForEach(tickets) { ticket in
                NavigationLink {
                    TicketDetailView(ticket: ticket)
                } label: {
                    TicketRow(ticket: ticket, onToggleStatus: {
                        onToggleStatus(ticket)
                    })
                }
                .contextMenu {
                    Button("Edit") { onEdit(ticket) }
                }
            }
            .onDelete(perform: onDelete)
        }
    }
}

private struct TicketRow: View {
    @Environment(\.modelContext) private var modelContext
    let ticket: Ticket
    let onToggleStatus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ticket.serviceName.isEmpty ? "Untitled Service" : ticket.serviceName)
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    // status color pill
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
            }
        }
        .contentShape(Rectangle()) // make whole row tappable
        .onTapGesture(count: 1) {
            // Toggle status when user taps the row
            onToggleStatus()
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

struct TicketDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let ticket: Ticket
    @State private var showAttachmentPreview: Attachment? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ticket.serviceName.isEmpty ? "Untitled Service" : ticket.serviceName)
                    .font(.largeTitle.bold())

                HStack(spacing: 8) {
                    Text("Status:")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Circle()
                            .frame(width: 12, height: 12)
                            .foregroundColor(statusColor(for: ticket.status))
                        Text(displayName(for: ticket.status))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
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
                    Text("Attachments")
                        .font(.headline)

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
            ToolbarItem(placement: .primaryAction) {
                Button("Close") { dismiss() }
            }
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
