import SwiftUI
import SwiftData

struct TicketView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tickets: [Ticket]
    @State private var showForm = false
    @State private var editingTicket: Ticket? = nil

    var body: some View {
        NavigationSplitView {
            List {
                Section("In Progress") {
                    ForEach(tickets.filter { $0.status == "In Progress" }) { ticket in
                        NavigationLink {
                            TicketDetailView(ticket: ticket)
                        } label: {
                            TicketRow(ticket: ticket)
                        }
                        .contextMenu {
                            Button("Edit") { editingTicket = ticket; showForm = true }
                        }
                    }
                    .onDelete { deleteItems(at: $0, in: tickets.filter { $0.status == "In Progress" }) }
                }

                Section("Pending") {
                    ForEach(tickets.filter { $0.status == "Pending" }) { ticket in
                        NavigationLink {
                            TicketDetailView(ticket: ticket)
                        } label: {
                            TicketRow(ticket: ticket)
                        }
                        .contextMenu {
                            Button("Edit") { editingTicket = ticket; showForm = true }
                        }
                    }
                    .onDelete { deleteItems(at: $0, in: tickets.filter { $0.status == "Pending" }) }
                }

                Section("Done") {
                    ForEach(tickets.filter { $0.status == "Done" }) { ticket in
                        NavigationLink {
                            TicketDetailView(ticket: ticket)
                        } label: {
                            TicketRow(ticket: ticket)
                        }
                        .contextMenu {
                            Button("Edit") { editingTicket = ticket; showForm = true }
                        }
                    }
                    .onDelete { deleteItems(at: $0, in: tickets.filter { $0.status == "Done" }) }
                }
            }
            .navigationTitle("Tickets")
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
            .sheet(isPresented: $showForm) {
                TicketFormView(ticket: editingTicket) { result in
                    switch result {
                    case .create(let title, let details, let status):
                        let new = Ticket(title: title, details: details, status: status, timestamp: Date())
                        modelContext.insert(new)
                    case .update(let ticket, let title, let details, let status):
                        ticket.title = title
                        ticket.details = details
                        ticket.status = status
                    }
                    editingTicket = nil
                }
            }
        } detail: {
            Text("Select a ticket")
                .foregroundStyle(.secondary)
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
}

private struct TicketRow: View {
    let ticket: Ticket
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ticket.title.isEmpty ? "Untitled" : ticket.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(ticket.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                Text(ticket.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TicketDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let ticket: Ticket

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ticket.title.isEmpty ? "Untitled Ticket" : ticket.title)
                    .font(.largeTitle.bold())
                HStack {
                    Text("Status:")
                        .font(.headline)
                    Text(ticket.status)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Text("Details")
                    .font(.headline)
                Text(ticket.details.isEmpty ? "No details provided." : ticket.details)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text("Created: \(ticket.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Ticket")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

struct TicketFormView: View {
    enum Result {
        case create(title: String, details: String, status: String)
        case update(ticket: Ticket, title: String, details: String, status: String)
    }

    @Environment(\.dismiss) private var dismiss

    var ticket: Ticket?
    var onSave: (Result) -> Void

    @State private var title: String = ""
    @State private var details: String = ""
    @State private var status: String = "In Progress"

    private let statuses = ["In Progress", "Pending", "Done"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Title", text: $title)
                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(ticket == nil ? "New Ticket" : "Edit Ticket")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let ticket {
                            onSave(.update(ticket: ticket, title: title, details: details, status: status))
                        } else {
                            onSave(.create(title: title, details: details, status: status))
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let ticket {
                    title = ticket.title
                    details = ticket.details
                    status = ticket.status
                }
            }
        }
    }
}

#Preview {
    TicketView()
        .modelContainer(for: Ticket.self, inMemory: true)
}
