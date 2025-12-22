import SwiftUI
import MapKit

struct PickedLocation: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D

    static func == (lhs: PickedLocation, rhs: PickedLocation) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct LocationPickerSheet: View {
    // <-- FIX: use the correct environment key path
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selected: MKMapItem? = nil

    var onPick: (PickedLocation) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack {
                    TextField("Search for a place", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit { Task { await performSearch() } } // call async from onSubmit
                    if isSearching { ProgressView().padding(.leading, 4) }
                }
                .padding(.horizontal)
                
                Map(position: $cameraPosition) {
                    if let selected {
                        let coord = selected.placemark.coordinate
                        Annotation(selected.name ?? "Selected", coordinate: coord) {
                            Image(systemName: "mappin.circle.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.title2)
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .frame(height: 300)

                List(Array(results.enumerated()), id: \.offset) { index, item in
                    Button {
                        withAnimation {
                            selected = item
                            cameraPosition = .region(MKCoordinateRegion(center: item.placemark.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Unknown")
                                .font(.headline)
                            Text(item.placemark.title ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Pick Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        guard let item = selected else { return }
                        let picked = PickedLocation(name: item.name ?? "", coordinate: item.placemark.coordinate)
                        onPick(picked)
                        dismiss()
                    }
                    .disabled(selected == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: query) {
            // Debounced search
            try? await Task.sleep(nanoseconds: 400_000_000)
            await performSearch()
        }
    }

    @MainActor
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            results = response.mapItems
        } catch {
            results = []
        }
    }
}

#Preview {
    LocationPickerSheet { picked in
        print(picked)
    }
}

