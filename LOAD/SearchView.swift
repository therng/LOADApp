import SwiftUI
import UIKit

struct SearchView: View {
    @EnvironmentObject private var vm: HomeViewModel
    @AppStorage("app_theme") private var theme: AppTheme = .system

    @FocusState private var isSearchFocused: Bool
    @State private var isSearchCollapsed: Bool = false
    @State private var showHistory: Bool = false
    @State private var selectedTab: Tab = .search
    @State private var keyboardVisible: Bool = false

    private enum Tab: String, CaseIterable {
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
        TabView(selection: $selectedTab) {
            searchTab
                .tabItem {
                    Label(Tab.search.title, systemImage: Tab.search.icon)
                }
                .tag(Tab.search)

            libraryTab
                .tabItem {
                    Label(Tab.library.title, systemImage: Tab.library.icon)
                }
                .tag(Tab.library)

            settingsTab
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(AppColors.accent)
        .background(AppColors.background.ignoresSafeArea())
        // Liquid glass-like tab bar
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbar(.visible, for: .tabBar)
        // Player accessory stacked above the tab bar
        .safeAreaInset(edge: .bottom) {
            tabAccessory
                .padding(.horizontal, 16)
                .padding(.bottom, keyboardVisible ? -8 : 4)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(vm)
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

// MARK: - Tab accessory (Player)
private extension SearchView {
    var tabAccessory: some View {
        VStack(spacing: 8) {
            if let _ = vm.nowPlaying {
                NowPlayingBar(isCompact: isSearchCollapsed)
                    .environmentObject(vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isSearchCollapsed && selectedTab == .search {
                HStack(spacing: 10) {
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isSearchCollapsed = false
                            isSearchFocused = true
                        }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(AppColors.surfaceStrong))

                    if let keyword = vm.recentKeywords.first {
                        Text(keyword)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Capsule().stroke(AppColors.surfaceStrong, lineWidth: 1))
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 18, y: 8)
        .padding(.top, 4)
        .opacity(keyboardVisible ? 0 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSearchCollapsed)
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
