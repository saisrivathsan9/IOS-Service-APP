//
//  DiaryApp.swift
//  Diary
//
//  Created by Saisrivathsan Manikandan on 8/18/25.
//

import SwiftUI
import SwiftData

@main
struct DiaryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Customer.self,
            Ticket.self,
            Attachment.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
