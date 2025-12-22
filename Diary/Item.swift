//
//  Item.swift
//  Diary
//
//  Created by Saisrivathsan Manikandan on 8/18/25.
//

import Foundation
import SwiftData

@Model
final class Attachment {
    var fileName: String
    var fileType: String  // "image", "pdf", "doc", etc.
    var fileData: Data    // The actual file contents

    init(fileName: String, fileType: String, fileData: Data) {
        self.fileName = fileName
        self.fileType = fileType
        self.fileData = fileData
    }
}

// New model: Location (multiple per customer)
@Model
final class Location {
    var name: String
    var latitude: Double?
    var longitude: Double?

    init(name: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

// Ticket status for workflow tracking
enum TicketStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case done = "done"
}

@Model
final class Ticket {
    // One ticket belongs to exactly one customer (Customer)
    @Relationship(inverse: \Customer.tickets)
    var customer: Customer

    // Core attributes
    var dateCreated: Date
    var dateClosed: Date?
    var status: TicketStatus
    var serviceName: String
    var locationName: String
    var latitude: Double?
    var longitude: Double?

    // Attachments for this ticket (images, videos, pdfs, etc.)
    @Relationship(deleteRule: .cascade)
    var attachments: [Attachment] = []

    init(customer: Customer,
         dateCreated: Date = .init(),
         status: TicketStatus = .pending,
         serviceName: String = "",
         locationName: String = "",
         latitude: Double? = nil,
         longitude: Double? = nil,
         attachments: [Attachment] = []) {
        self.customer = customer
        self.dateCreated = dateCreated
        self.status = status
        self.serviceName = serviceName
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.attachments = attachments
        self.dateClosed = nil
    }

    // Helper to mark as done and set closed date
    func close(now: Date = .init()) {
        self.status = .done
        self.dateClosed = now
    }
}

@Model
final class Customer {
    var timestamp: Date
    var custName: String = ""
    var custAddress: String = ""
    var custPhone: String = ""
    var custEmail: String = ""
    var custDescription: String = ""

    // Multiple locations relationship
    @Relationship(deleteRule: .cascade)
    var locations: [Location] = []

    // Relationship: One customer can have many attachments
    @Relationship(deleteRule: .cascade)
    var attachments: [Attachment] = []

    // Relationship: One customer can have many tickets
    @Relationship(deleteRule: .cascade)
    var tickets: [Ticket] = []

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

