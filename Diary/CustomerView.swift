//
//  ContentView.swift
//  Diary
//
//  Created by Saisrivathsan Manikandan on 8/18/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Customer]
    @State private var menuID: Int = 0
    @State private var showForm = false

    var body: some View {
        
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        CustomerDetailView(item: item)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.custName.isEmpty ? "Unnamed Customer" : item.custName)
                                .font(.headline)
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .background(Color.white)
            .navigationTitle("Customers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: { showForm = true }) {
                        Label("Add Customer", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showForm) {
                CustomerFormView(item: nil) // New customer form
            }
        }
        detail: {
            Text("Select a customer")
        }
        
        // Bottom Bar (Menu Bar)
        BottomBar(menuID: $menuID)
            .ignoresSafeArea(edges: .bottom)
        
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
    ContentView()
        .modelContainer(for: Customer.self, inMemory: true)
}
