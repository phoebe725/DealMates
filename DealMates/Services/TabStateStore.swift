import SwiftUI
import Combine

/// Survives the `.id(languageCode)` rebuild of the root view tree so that when
/// the user changes language, they stay on whichever tab they were on rather
/// than getting bounced back to Discover.
///
/// Owned at the `DealMatesApp` level (`@StateObject` outside the `.id()`
/// boundary). `ContentView` reads from this store instead of holding its own
/// `@State` for the selected tab.
@MainActor
final class TabStateStore: ObservableObject {
    @Published var selectedTab: Int = 0
}
