import SwiftUI
import UIKit

/// Wraps `UITabBarController` so we can override `selectedIndex` with `UIView.performWithoutAnimation`.
/// This kills the iOS 18 tab-bar zoom animation that SwiftUI's `TabView` exposes no API to disable.
struct NoAnimationTabBar: UIViewControllerRepresentable {
    @Binding var selectedIndex: Int
    let tabs: [Tab]
    let tintColor: UIColor

    struct Tab {
        let view: AnyView
        let title: String
        let systemImage: String
        let badge: String?
    }

    func makeUIViewController(context: Context) -> InstantTabBarController {
        let controller = InstantTabBarController()
        controller.delegate = context.coordinator
        controller.tabBar.tintColor = tintColor
        controller.viewControllers = tabs.map { tab in
            let host = UIHostingController(rootView: tab.view)
            host.tabBarItem = UITabBarItem(title: tab.title, image: UIImage(systemName: tab.systemImage), tag: 0)
            host.tabBarItem.badgeValue = tab.badge
            return host
        }
        controller.selectedIndex = selectedIndex
        return controller
    }

    func updateUIViewController(_ controller: InstantTabBarController, context: Context) {
        if controller.selectedIndex != selectedIndex {
            controller.selectedIndex = selectedIndex
        }
        guard let vcs = controller.viewControllers else { return }
        for (i, tab) in tabs.enumerated() where i < vcs.count {
            vcs[i].tabBarItem.badgeValue = tab.badge
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(selectedIndex: $selectedIndex) }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        @Binding var selectedIndex: Int
        init(selectedIndex: Binding<Int>) { _selectedIndex = selectedIndex }
        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            if let idx = tabBarController.viewControllers?.firstIndex(of: viewController) {
                selectedIndex = idx
            }
        }
    }
}

final class InstantTabBarController: UITabBarController {
    override var selectedIndex: Int {
        get { super.selectedIndex }
        set { UIView.performWithoutAnimation { super.selectedIndex = newValue } }
    }
    override var selectedViewController: UIViewController? {
        get { super.selectedViewController }
        set { UIView.performWithoutAnimation { super.selectedViewController = newValue } }
    }
}
