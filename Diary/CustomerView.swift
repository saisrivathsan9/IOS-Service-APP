//
//  ContentView.swift
//  Diary
//
//  Created by Saisrivathsan Manikandan on 8/18/25.
//

import SwiftUI
import SwiftData

struct CustomerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Customer]
    @State private var showForm = false

    @State private var searchText: String = ""

    // derived groupings
    private var filteredCustomers: [Customer] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            return items.sorted { $0.custName.lowercased() < $1.custName.lowercased() }
        } else {
            return items.filter {
                $0.custName.lowercased().contains(trimmed) ||
                $0.custPhone.lowercased().contains(trimmed) ||
                $0.custEmail.lowercased().contains(trimmed)
            }.sorted { $0.custName.lowercased() < $1.custName.lowercased() }
        }
    }

    private var sections: [String: [Customer]] {
        Dictionary(grouping: filteredCustomers) { customer -> String in
            let first = customer.custName.trimmingCharacters(in: .whitespaces).first
            if let ch = first {
                return String(ch).uppercased()
            } else {
                return "#" // fallback
            }
        }
    }

    private var sectionTitles: [String] {
        sections.keys.sorted()
    }

    var body: some View {
        NavigationSplitView {
            ZStack {
                ScrollViewReader { proxy in
                    List {
                        ForEach(sectionTitles, id: \.self) { title in
                            Section(header: Text(title).id(title)) {
                                ForEach(sections[title] ?? []) { customer in
                                    NavigationLink {
                                        CustomerDetailView(item: customer)
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(customer.custName.isEmpty ? "Unnamed Customer" : customer.custName)
                                                .font(.headline)
                                            Text(customer.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    deleteInSection(offsets: offsets, sectionTitle: title)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search customers")
                    .navigationTitle("Customers")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { showForm = true }) {
                                Label("Add Customer", systemImage: "plus")
                            }
                        }
                    }
                    // Reserve right padding so rows don't get overlapped by the alphabet index
                    .padding(.trailing, 44)
                    // Alphabet index overlay
                    .overlay(alphabetIndex(proxy: proxy), alignment: .trailing)
                }
            }
            .background(Color.white)
            .sheet(isPresented: $showForm) {
                CustomerFormView(item: nil) // New customer form
            }
        } detail: {
            Text("Select a customer")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
        }
    }

    // Overlay: vertical alphabet index; tap to scroll
    @ViewBuilder
    private func alphabetIndex(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(sectionTitles, id: \.self) { letter in
                Button(action: {
                    withAnimation {
                        proxy.scrollTo(letter, anchor: .top)
                    }
                }) {
                    Text(letter)
                        .font(.caption2)
                        .frame(width: 28, height: 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .background(Color.clear)
        .padding(.trailing, 8)
        .frame(width: 36)
    }

    private func deleteInSection(offsets: IndexSet, sectionTitle: String) {
        // Convert section-local offsets into actual Customer objects and delete them
        guard let list = sections[sectionTitle] else { return }
        let toDelete = offsets.map { list[$0] }
        withAnimation {
            for cust in toDelete {
                modelContext.delete(cust)
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    CustomerView()
        .modelContainer(for: Customer.self, inMemory: true)
}

