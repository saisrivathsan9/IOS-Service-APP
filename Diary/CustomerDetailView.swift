//
//  CustomerDetailView.swift
//  Diary
//

import SwiftUI
import QuickLook

struct CustomerDetailView: View {
    let item: Customer
    @State private var showEditForm = false
    @State private var previewAttachment: Attachment? = nil

    // ticket search text
    @State private var ticketSearch: String = ""

    // reserve space for the app bottom bar so scrolling reaches the bottom
    private let bottomBarHeight: CGFloat = 100

    var filteredTickets: [Ticket] {
        let all = item.tickets.sorted { $0.dateCreated > $1.dateCreated }
        if ticketSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return all
        } else {
            let s = ticketSearch.lowercased()
            return all.filter { ticket in
                (ticket.serviceName.lowercased().contains(s) ||
                 ticket.locationName.lowercased().contains(s) ||
                 ticket.status.rawValue.lowercased().contains(s))
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.custName)
                    .font(.title)
                    .bold()

                if !item.custEmail.isEmpty {
                    Text("📧 \(item.custEmail)")
                }
                if !item.custPhone.isEmpty {
                    Text("📱 \(item.custPhone)")
                }
                if !item.custAddress.isEmpty {
                    Text("🏠 \(item.custAddress)")
                }

                if !item.custDescription.isEmpty {
                    Text("📝 \(item.custDescription)")
                }

                if !item.locations.isEmpty {
                    Divider()
                    Text("Locations")
                        .font(.headline)

                    ForEach(item.locations) { loc in
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            VStack(alignment: .leading) {
                                Text(loc.name)
                                if let lat = loc.latitude, let lon = loc.longitude {
                                    Text(String(format: "Lat: %.4f, Lon: %.4f", lat, lon))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !item.attachments.isEmpty {
                    Divider()
                    Text("Attachments")
                        .font(.headline)

                    ForEach(item.attachments) { attachment in
                        Button {
                            previewAttachment = attachment
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

                // Tickets area
                Divider()
                HStack {
                    Text("Tickets")
                        .font(.headline)
                    Spacer()
                }

                // Search field for tickets
                TextField("Search tickets", text: $ticketSearch)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 4)

                // Group by status in custom order: inProgress, pending, done
                let grouped = Dictionary(grouping: filteredTickets) { $0.status }

                // Show In Progress, Pending, Done in that order
                TicketSectionView(title: "In Progress", tickets: grouped[.inProgress] ?? [])
                TicketSectionView(title: "Pending", tickets: grouped[.pending] ?? [])
                TicketSectionView(title: "Done", tickets: grouped[.done] ?? [])

                // add some bottom padding so content isn't cramped before inset
            }
            .padding()
            .padding(.bottom, 8) // small extra padding
        }
        .safeAreaInset(edge: .bottom) {
            // Reserve space equal to bottom bar height so content can scroll above it
            Color.clear.frame(height: bottomBarHeight)
        }
        .navigationTitle("Details")
        .toolbar {
            Button("Edit") {
                showEditForm = true
            }
        }
        .sheet(isPresented: $showEditForm) {
            CustomerFormView(item: item)
        }
        .sheet(item: $previewAttachment) { attachment in
            AttachmentPreviewView(attachment: attachment)
        }
    }
}

struct TicketSectionView: View {
    let title: String
    let tickets: [Ticket]

    var body: some View {
        if tickets.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                ForEach(tickets) { ticket in
                    NavigationLink {
                        TicketDetailView(ticket: ticket)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(ticket.serviceName.isEmpty ? "No Service" : ticket.serviceName)
                                    .font(.headline)
                                Spacer()
                                Text(ticket.dateCreated, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !ticket.locationName.isEmpty {
                                Text(ticket.locationName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Divider()
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

