import SwiftUI
import MapKit

struct BottomSheetLocationPicker: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isSearching = false
    
    // Callback to return selected location
    var onSelectLocation: (MKMapItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            capsule
                .padding(.top, 8)
            
            searchField
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            Divider()
            
            if isSearching && searchResults.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if !searchResults.isEmpty {
                resultsList
            } else {
                mapView
                    .transition(.opacity)
            }
        }
        .background(.regularMaterial)
        .cornerRadius(16)
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: searchQuery) { newValue in
            performSearch(query: newValue)
        }
    }
    
    private var capsule: some View {
        RoundedRectangle(cornerRadius: 3)
            .frame(width: 40, height: 6)
            .foregroundColor(.secondary.opacity(0.5))
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search for a place or address", text: $searchQuery, onEditingChanged: { began in
                withAnimation {
                    isSearching = began || !searchQuery.isEmpty
                }
            })
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .submitLabel(.search)
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    withAnimation {
                        isSearching = false
                        searchResults = []
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
    
    private var resultsList: some View {
        List {
            ForEach(searchResults, id: \.self) { item in
                Button {
                    onSelectLocation(item)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Unknown")
                            .font(.headline)
                        Text(parseAddress(from: item.placemark))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var mapView: some View {
        Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true, annotationItems: []) { item in
            // no annotations by default
            MapMarker(coordinate: item.coordinate)
        }
        .frame(minHeight: 300)
        .cornerRadius(16)
        .padding()
    }
    
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            withAnimation {
                searchResults = []
                isSearching = false
            }
            return
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                if let items = response?.mapItems, error == nil {
                    searchResults = items
                } else {
                    searchResults = []
                }
                isSearching = false
            }
        }
    }
    
    private func parseAddress(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
}

struct BottomSheetLocationPicker_Previews: PreviewProvider {
    static var previews: some View {
        BottomSheetLocationPicker { selected in
            print("Selected location: \(selected.name ?? "Unknown")")
        }
        .presentationDetents([.fraction(0.6), .fraction(0.9)])
    }
}
