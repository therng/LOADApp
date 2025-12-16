import SwiftUI
import UIKit

struct SearchView: View {
    @EnvironmentObject private var vm: HomeViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var isSearchCollapsed: Bool = false
    @State private var showHistory: Bool = false

    var body: some View {
            NavigationStack {
                ZStack {List(
                    
                    AppColors.background.ignoresSafeArea()
                    
                    // Main content (make THIS scrollable if needed)
                    {        resultsArea

                        .overlay {
                            if vm.isLoading && !vm.results.isEmpty {
                                ProgressView()
                            }
                        }
                }
                .onChange(of: vm.results) { _, newResults in
                    if newResults.isEmpty {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isSearchCollapsed = false
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    bottomControls
                }
                .sheet(isPresented: $showHistory) {
                    HistoryView()
                        .environmentObject(vm)
                }
            }
    }
    
    // MARK: - Bottom Controls (History + Mini Player + Search)
    private var bottomControls: some View {
        VStack(spacing: isSearchCollapsed ? 3 : 10) {
            if isSearchFocused, vm.nowPlaying != nil {
                NowPlayingBar()
                    .environmentObject(vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if isSearchCollapsed {
                collapsedBottomRow
            } else {
                expandedBottomRow
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSearchCollapsed)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSearchFocused)
        .padding(.horizontal, 16)
        .padding(.vertical, isSearchCollapsed ? 3 : 10)
        .background(
            Group {
                if isSearchCollapsed {
                    Color.clear
                } else {
                    AppColors.background.opacity(0.9)
                }
            }
        )
    }
    
        private var collapsedBottomRow: some View { .accessibilityScrollAction(<#T##self: View##View#>)
        HStack(spacing: 12) {
            if !isSearchFocused {
                historyButton
                    .shadow(color: controlShadowColor, radius: 6, y: 3)
            }
            
            if vm.nowPlaying != nil && !isSearchFocused {
                NowPlayingBar()
                    .environmentObject(vm)
                    .shadow(color: controlShadowColor, radius: 8, y: 4)
            }
            
            collapsedSearchButton
                .shadow(color: controlShadowColor, radius: 6, y: 3)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var expandedBottomRow: some View {
        HStack(spacing: 10) {
            if !isSearchFocused {
                historyButton
            }
            
            if vm.nowPlaying != nil && !isSearchFocused {
                NowPlayingBar()
                    .environmentObject(vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            searchBar
                .transition(.move(edge: .trailing).combined(with: .opacity))
            
            if isSearchFocused {
                closeSearchFocusButton
                    .transition(.opacity)
            }
        }
    }
    
    private var historyButton: some View {
        Button {
            HapticManager.shared.selection()
            showHistory = true
        } label: {
            Image(systemName: "diamond.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .stroke(AppColors.surfaceStrong, lineWidth: 2)
                )
        }
    }
    
    private var controlShadowColor: Color {
        Color.black.opacity(0.08)
    }
    
    private var collapsedSearchButton: some View {
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
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .stroke(AppColors.surfaceStrong, lineWidth: 2)
                )
        }
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
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(AppColors.surfaceStrong.opacity(0.32))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
    }
    
    private var closeSearchFocusButton: some View {
        Button {
            HapticManager.shared.selection()
            isSearchFocused = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .stroke(AppColors.surfaceStrong, lineWidth: 2)
                )
        }
    }
    
    // MARK: - Results / States
    @ViewBuilder
    private var resultsArea: some View {
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
              
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height * 0.7, alignment: .center)
                    } else if vm.results.isEmpty {
                        // Empty state centered on screen
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
                // Emit scroll offset so we can collapse the search bar on scroll
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
    
    // MARK: - Now Playing Bar
    private struct NowPlayingBar: View {
        @EnvironmentObject private var vm: HomeViewModel
        
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
                            .frame(width: 5, height: 30)
  
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
                .padding(.horizontal, 1)
                .padding(.vertical, 10)
                .clipShape(Capsule())
                .layoutPriority(1)
            }
        }
    }
    
    private struct ScrollOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(HomeViewModel.makeDefault())
}
