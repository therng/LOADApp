import SwiftUI
import UIKit

// MARK: - App Theme
enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Haptic Manager
final class HapticManager {
    static let shared = HapticManager()
    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

@main
struct LOADApp: App {

    // MARK: - Global States
    @StateObject private var homeVM = HomeViewModel.makeDefault()
    @AppStorage("app_theme") private var theme: AppTheme = .system

    init() {
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(homeVM)
                .preferredColorScheme(theme.colorScheme)
                .tint(AppColors.accent)
        }
    }
}

// MARK: - Appearance Configuration
private extension LOADApp {

    func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.background)

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.accent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.accent)
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - App Colors (Design Tokens)
enum AppColors {
    static let background = Color.black
    static let surface = Color.white.opacity(0.12)
    static let surfaceStrong = Color.white.opacity(0.18)

    static let accent = Color.red
    static let secondaryAccent = Color.green

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
}
