import SwiftUI
import MapKit
import CoreLocation

struct RestaurantMapView: View {
    @EnvironmentObject var restaurantVM: RestaurantViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var annotations: [RestaurantAnnotation] = []
    @State private var selected: Restaurant?
    @State private var isShowingCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: annotations) { ann in
                    MapAnnotation(coordinate: ann.coordinate) {
                        Button {
                            selected = ann.restaurant
                            isShowingCreate = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                Text(ann.restaurant.name)
                                    .font(.caption2)
                                    .fixedSize()
                            }
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                if restaurantVM.isLoading {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: centerOnUser) {
                        Image(systemName: "location.fill")
                    }
                }
            }
            .task {
                await loadAnnotations()
            }
            .sheet(isPresented: $isShowingCreate, onDismiss: { selected = nil }) {
                if let r = selected {
                    CreatePlanView(restaurant: r, planVM: PlanViewModel(restaurantId: r.id))
                        .environmentObject(authViewModel)
                }
            }
        }
    }

    private func centerOnUser() {
        // No-op placeholder — could request user location
    }

    private func loadAnnotations() async {
        // Use stored latitude/longitude when available, otherwise geocode address.
        var anns: [RestaurantAnnotation] = []
        let geocoder = CLGeocoder()
        for rest in restaurantVM.restaurants {
            if let existing = anns.first(where: { $0.restaurant.id == rest.id }) { continue }

            // Prefer explicit coordinates from DB
            if let lat = rest.latitude, let lon = rest.longitude {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                anns.append(RestaurantAnnotation(restaurant: rest, coordinate: coord))
                continue
            }

            // Fallback to geocoding address
            var coord: CLLocationCoordinate2D? = nil
            do {
                let res = try await geocoder.geocodeAddressString(rest.address)
                if let loc = res.first?.location { coord = loc.coordinate }
            } catch {
                coord = nil
            }
            if let c = coord {
                anns.append(RestaurantAnnotation(restaurant: rest, coordinate: c))
            }
        }

        if let first = anns.first {
            region.center = first.coordinate
        }
        annotations = anns
    }
}

private struct RestaurantAnnotation: Identifiable {
    let id = UUID()
    let restaurant: Restaurant
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    RestaurantMapView()
        .environmentObject(RestaurantViewModel())
        .environmentObject(AuthViewModel())
}
