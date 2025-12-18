import SwiftUI
import UIKit

struct SearchView: View {
    @EnvironmentObject private var vm: HomeViewModel
    @AppStorage("app_theme") private var theme: AppTheme = .system

    @FocusState private var isSearchFocused: Bool
    @State private var isSearchCollapsed: Bool = false
    @State private var showHistory: Bool = false
    @State private var selectedTab: Tab = .search
    enum Tab: String, CaseIterable {
        case search
        case library
        case settings

        var title: String {
            switch self {
            case .search: return "Search"
            case .library: return "Library"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .search: return "magnifyingglass"
            case .library: return "play.rectangle.on.rectangle"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        AdaptiveTabBarControllerRepresentable(
            selectedTab: $selectedTab,
            viewModel: vm,
            searchView: AnyView(searchTab),
            libraryView: AnyView(libraryTab),
            settingsView: AnyView(settingsTab),
            searchActivates: true,
            onSearchActivation: activateSearchTab
        )
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.accent)
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(vm)
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == .search {
                activateSearchTab()
            }
        }
    }
}

// MARK: - Tabs
private extension SearchView {
    var searchTab: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.background
                    .ignoresSafeArea()

                resultsArea
                    .overlay(alignment: .center) {
                        if vm.isLoading && !vm.results.isEmpty {
                            ProgressView()
                        }
                    }
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                searchHeader
                    .background(.thinMaterial)
                    .overlay(alignment: .top) {
                        Divider()
                            .offset(y: -1)
                            .opacity(isSearchCollapsed ? 0.3 : 0)
                    }
            }
        }
    }

    var libraryTab: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "rectangle.stack.badge.play")
                    .font(.system(size: 46))
                    .foregroundColor(AppColors.textSecondary)
                Text("Queue & Library")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("Keep listening where you left off. Coming soon.")
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Library")
        }
    }

    var settingsTab: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        Text("System").tag(AppTheme.system)
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Shortcuts") {
                    Button {
                        HapticManager.shared.selection()
                        showHistory = true
                    } label: {
                        Label("Search History", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Search Header
private extension SearchView {
    var searchHeader: some View {
        VStack(alignment: .leading, spacing: isSearchCollapsed ? 6 : 12) {
            HStack {
                Text(isSearchCollapsed ? "Search" : "Find your next track")
                    .font(.system(size: isSearchCollapsed ? 16 : 22, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                if isSearchCollapsed {
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isSearchCollapsed = false
                        }
                        isSearchFocused = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(10)
                            .background(Circle().fill(AppColors.surfaceStrong))
                    }
                    .accessibilityLabel("Expand search")
                }
            }

            if !isSearchCollapsed {
                searchBar
                HStack(spacing: 8) {
                    historyButton
                    if let keyword = vm.recentKeywords.first {
                        Text("Recent: \(keyword)")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.footnote)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isSearchCollapsed ? 8 : 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 6)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSearchCollapsed)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSearchFocused)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondary)

            TextField("Search", text: $vm.query)
                .focused($isSearchFocused)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    HapticManager.shared.selection()
                    vm.search()
                    isSearchFocused = false
                }

            if isSearchFocused && !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    HapticManager.shared.selection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if isSearchFocused {
                Button {
                    HapticManager.shared.selection()
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(AppColors.surfaceStrong.opacity(0.32))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
    }

    private var historyButton: some View {
        Button {
            HapticManager.shared.selection()
            showHistory = true
        } label: {
            Label("History", systemImage: "diamond.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Capsule().stroke(AppColors.surfaceStrong, lineWidth: 2))
        }
    }
}

// MARK: - Results
private extension SearchView {
    @ViewBuilder
    var resultsArea: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if vm.isLoading && vm.results.isEmpty {
                        VStack(alignment: .center, spacing: 16) {
                            Spacer()
                            ProgressView()
                                .controlSize(.large)
                            Text("Searching…")
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                    } else if let error = vm.errorMessage, vm.results.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundColor(.yellow)
                            Text(error)
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.textSecondary)
                            Button {
                                HapticManager.shared.selection()
                                vm.search()
                            } label: {
                                Text("Try Again")
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(AppColors.surfaceStrong)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height * 0.7, alignment: .center)
                    } else if vm.results.isEmpty {
                        VStack(alignment: .center, spacing: 10) {
                            Image(systemName: "music.quarternote.3")
                                .font(.system(size: 50))
                                .foregroundColor(AppColors.textSecondary)
                            Text("Search for music")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Text("Type a keyword and press Go to see results.")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height * 0.7, alignment: .center)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.results) { track in
                                TrackRow(track: track)
                                    .environmentObject(vm)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        let offset = proxy.frame(in: .named("resultsScroll")).minY
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: offset)
                    }
                )
            }
            .coordinateSpace(name: "resultsScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                let shouldCollapse = offset < -24
                if shouldCollapse != isSearchCollapsed {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isSearchCollapsed = shouldCollapse
                    }
                }
            }
        }
    }
}

// MARK: - Adaptive Tab Bar Controller
private extension SearchView {
    func activateSearchTab() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            isSearchCollapsed = false
        }
        isSearchFocused = true
    }
}

private struct AdaptiveTabBarControllerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedTab: SearchView.Tab
    let viewModel: HomeViewModel
    let searchView: AnyView
    let libraryView: AnyView
    let settingsView: AnyView
    let searchActivates: Bool
    let onSearchActivation: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> AdaptiveTabBarController {
        let controller = AdaptiveTabBarController(viewModel: viewModel)
        controller.configureTabs(tabs: tabControllers())
        controller.selectionHandler = { tab in
            context.coordinator.handleSelection(tab)
        }
        controller.applySelection(selectedTab)
        return controller
    }

    func updateUIViewController(_ uiViewController: AdaptiveTabBarController, context: Context) {
        uiViewController.configureTabs(tabs: tabControllers())
        uiViewController.applySelection(selectedTab)
    }

    private func tabControllers() -> [AdaptiveTabBarController.TabConfig] {
        [
            .init(tab: .search, controller: hostingController(for: searchView, tab: .search)),
            .init(tab: .library, controller: hostingController(for: libraryView, tab: .library)),
            .init(tab: .settings, controller: hostingController(for: settingsView, tab: .settings))
        ]
    }

    private func hostingController(for view: AnyView, tab: SearchView.Tab) -> UIViewController {
        let controller = UIHostingController(rootView: view.environmentObject(viewModel))
        controller.tabBarItem = UITabBarItem(title: tab.title, image: UIImage(systemName: tab.icon), tag: tab.hashValue)
        if tab == .search {
            controller.tabBarItem.badgeColor = UIColor(AppColors.accent.opacity(0.9))
        }
        return controller
    }

    final class Coordinator {
        private let parent: AdaptiveTabBarControllerRepresentable

        init(parent: AdaptiveTabBarControllerRepresentable) {
            self.parent = parent
        }

        func handleSelection(_ tab: SearchView.Tab) {
            guard parent.selectedTab != tab else {
                if tab == .search && parent.searchActivates {
                    parent.onSearchActivation()
                }
                return
            }

            DispatchQueue.main.async {
                parent.selectedTab = tab
                if tab == .search && parent.searchActivates {
                    parent.onSearchActivation()
                }
            }
        }
    }
}

private final class AdaptiveTabBarController: UITabBarController, UITabBarControllerDelegate {
    struct TabConfig {
        let tab: SearchView.Tab
        let controller: UIViewController
    }

    private var tabConfigs: [TabConfig] = []
    private let accessoryHost: TabAccessoryHostView
    var selectionHandler: ((SearchView.Tab) -> Void)?

    init(viewModel: HomeViewModel) {
        accessoryHost = TabAccessoryHostView(viewModel: viewModel)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        tabBarMinimizeBehavior = .onScrollDown

        let accessory = UITabAccessory(contentView: accessoryHost)
        tabBar.bottomAccessory = accessory
        accessoryHost.updatePlayerAppearance(inline: traitCollection.tabAccessoryEnvironment == .inline)
    }

    func configureTabs(tabs: [TabConfig]) {
        tabConfigs = tabs
        viewControllers = tabs.map { $0.controller }
    }

    func applySelection(_ tab: SearchView.Tab) {
        guard let index = tabConfigs.firstIndex(where: { $0.tab == tab }) else { return }
        selectedIndex = index
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard selectedIndex < tabConfigs.count else { return }
        selectionHandler?(tabConfigs[selectedIndex].tab)
    }
}

private final class TabAccessoryHostView: UIView {
    private let viewModel: HomeViewModel
    private var inline: Bool = false
    private var hostingController: UIHostingController<AccessoryPlayerView>

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        let initialView = AccessoryPlayerView(viewModel: viewModel, isInline: false)
        hostingController = UIHostingController(rootView: initialView)
        super.init(frame: .zero)

        addSubview(hostingController.view)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { (view: TabAccessoryHostView, _) in
            let isInline = view.traitCollection.tabAccessoryEnvironment == .inline
            view.updatePlayerAppearance(inline: isInline)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateConstraints() {
        super.updateConstraints()
        updatePlayerAppearance(inline: traitCollection.tabAccessoryEnvironment == .inline)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let isInline = traitCollection.tabAccessoryEnvironment == .inline
        updatePlayerAppearance(inline: isInline)
    }

    func updatePlayerAppearance(inline: Bool) {
        guard inline != self.inline else { return }
        self.inline = inline
        hostingController.rootView = AccessoryPlayerView(viewModel: viewModel, isInline: inline)
    }
}

private struct AccessoryPlayerView: View {
    @ObservedObject var viewModel: HomeViewModel
    var isInline: Bool

    var body: some View {
        VStack(spacing: 6) {
            if viewModel.nowPlaying != nil {
                NowPlayingBar(isCompact: isInline)
                    .environmentObject(viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
    }
}

// MARK: - Helpers
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct NowPlayingBar: View {
    @EnvironmentObject private var vm: HomeViewModel
    var isCompact: Bool

    var body: some View {
        if let t = vm.nowPlaying {
            HStack(spacing: 10) {
                Button {
                    HapticManager.shared.selection()
                    vm.togglePlayback()
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(AppColors.surface)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title)
                        .foregroundColor(AppColors.textPrimary)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(t.artist)
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 13))
                        .lineLimit(1)
                }

                Spacer()

                Text(t.durationText)
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: 13))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.surfaceStrong.opacity(0.9))
            .clipShape(Capsule())
            .scaleEffect(isCompact ? 0.96 : 1)
            .opacity(isCompact ? 0.92 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isCompact)
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(HomeViewModel.makeDefault())
}
