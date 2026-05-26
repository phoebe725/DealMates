import SwiftUI
import MapKit
import CoreLocation

struct RestaurantMapView: View {
    @EnvironmentObject var restaurantVM: RestaurantViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    @State private var currentRegion: MKCoordinateRegion?
    @State private var annotations: [RestaurantAnnotation] = []
    @State private var selected: Restaurant?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Map(position: $cameraPosition) {
                    ForEach(annotations) { ann in
                        Annotation(ann.restaurant.name, coordinate: ann.coordinate) {
                            Button {
                                selected = ann.restaurant
                            } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white, .orange)
                                    .background(Circle().fill(.white))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .mapControls {
                    MapPitchToggle()
                    MapCompass()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    currentRegion = context.region
                }
                .ignoresSafeArea(edges: .bottom)

                controlsOverlay

                if restaurantVM.isLoading {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selected) { restaurant in
                RestaurantBoardView(restaurant: restaurant)
                    .environmentObject(authViewModel)
            }
            .task { await loadAnnotations() }
        }
    }

    // MARK: - Controls overlay (zoom in / out / close)

    private var controlsOverlay: some View {
        VStack(spacing: 10) {
            mapButton(systemName: "xmark") { dismiss() }
            mapButton(systemName: "plus.magnifyingglass") { zoom(by: 0.5) }
            mapButton(systemName: "minus.magnifyingglass") { zoom(by: 2.0) }
        }
        .padding(.top, 12)
        .padding(.trailing, 12)
    }

    private func mapButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func zoom(by factor: Double) {
        let baseRegion = currentRegion ?? defaultRegion()
        let newSpan = MKCoordinateSpan(
            latitudeDelta: clamp(baseRegion.span.latitudeDelta * factor, min: 0.001, max: 180),
            longitudeDelta: clamp(baseRegion.span.longitudeDelta * factor, min: 0.001, max: 360)
        )
        let newRegion = MKCoordinateRegion(center: baseRegion.center, span: newSpan)
        cameraPosition = .region(newRegion)
        currentRegion = newRegion
    }

    private func clamp(_ value: Double, min lo: Double, max hi: Double) -> Double {
        max(lo, min(hi, value))
    }

    private func defaultRegion() -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    }

    private func loadAnnotations() async {
        var anns: [RestaurantAnnotation] = []
        let geocoder = CLGeocoder()
        for rest in restaurantVM.restaurants {
            if anns.contains(where: { $0.restaurant.id == rest.id }) { continue }

            if let lat = rest.latitude, let lon = rest.longitude {
                anns.append(RestaurantAnnotation(restaurant: rest, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                continue
            }

            if let loc = try? await geocoder.geocodeAddressString(rest.address).first?.location {
                anns.append(RestaurantAnnotation(restaurant: rest, coordinate: loc.coordinate))
            }
        }

        annotations = anns

        if let first = anns.first {
            let lats = anns.map(\.coordinate.latitude)
            let lons = anns.map(\.coordinate.longitude)
            let minLat = lats.min() ?? first.coordinate.latitude
            let maxLat = lats.max() ?? first.coordinate.latitude
            let minLon = lons.min() ?? first.coordinate.longitude
            let maxLon = lons.max() ?? first.coordinate.longitude
            let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
            let span = MKCoordinateSpan(
                latitudeDelta: max(0.05, (maxLat - minLat) * 1.5),
                longitudeDelta: max(0.05, (maxLon - minLon) * 1.5)
            )
            let region = MKCoordinateRegion(center: center, span: span)
            cameraPosition = .region(region)
            currentRegion = region
        }
    }
}

private struct RestaurantAnnotation: Identifiable {
    let id = UUID()
    let restaurant: Restaurant
    let coordinate: CLLocationCoordinate2D
}
