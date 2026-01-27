import SwiftUI
import MapKit
import CoreLocation

class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocation?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        print("LocationFetcher: requestLocation called. Current authorization status: \(CLLocationManager.authorizationStatus().rawValue)")
        errorMessage = nil
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            errorMessage = "Location access is denied. Please enable it in settings."
        case .authorizedAlways, .authorizedWhenInUse:
            isLoading = true
            locationManager.requestLocation()
        @unknown default:
            errorMessage = "Unknown location authorization status."
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("LocationFetcher: didChangeAuthorization to \(status.rawValue)")
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            requestLocation()
        } else if status == .denied || status == .restricted {
            errorMessage = "Location access is denied. Please enable it in settings."
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLoading = false
        if let location = locations.first {
            print("LocationFetcher: didUpdateLocations: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            userLocation = location
            errorMessage = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationFetcher: didFailWithError: \(error.localizedDescription)")
        isLoading = false
        errorMessage = "Failed to get location: \(error.localizedDescription)"
    }
}

struct BottomSheetLocationPicker: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isSearching = false
    
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    
    @StateObject private var locationFetcher = LocationFetcher()
    @State private var locationError: String?
    
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
            
            Button {
                locationFetcher.requestLocation()
            } label: {
                if locationFetcher.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Get My Location")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(locationFetcher.isLoading)
            .padding(.horizontal)
            .padding(.bottom, 4)
            
            if let error = locationFetcher.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            
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
        .onAppear {
            print("BottomSheetLocationPicker appeared")
            locationFetcher.requestLocation()
        }
        .onChange(of: searchQuery, initial: false) { oldValue, newValue in
            performSearch(query: newValue)
        }
        .onChange(of: locationFetcher.userLocation) { newLocation in
            guard let location = newLocation else { return }
            withAnimation {
                let coordinate = location.coordinate
                let newRegion = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                region = newRegion
                cameraPosition = .region(newRegion)
            }
            // Construct an MKMapItem and call onSelectLocation automatically
            let placemark = MKPlacemark(coordinate: location.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            onSelectLocation(mapItem)
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
        Map(position: $cameraPosition, interactionModes: .all) {
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
        }
        .onMapCameraChange { context in
            // keep MKCoordinateRegion in sync for searches
            region = context.region
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
