import SwiftUI
import UIKit
import Combine

struct HomeView: View {
    @EnvironmentObject private var vm: HomeViewModel
    @Namespace private var animationNamespace
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isSearching = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showPlayerSheet = false
    @State private var cancellables = Set<AnyCancellable>()

    private enum Metrics {
        static let horizontalPadding: CGFloat = 20
        static let bottomSafeSpacing: CGFloat = 20
        static let searchBarHeight: CGFloat = 44
        static let resultsBottomPadding: CGFloat = 120
        static let topResultsPadding: CGFloat = 10
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                backgroundGradient

                resultsContent
                    .animation(.easeInOut(duration: 0.25), value: keyboardHeight)

                bottomControls
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: vm.searchText) { _, newValue in
                vm.query = newValue
            }
            .onSubmit(of: .search) {
                submitSearch()
            }
            .onAppear {
                registerKeyboardPublishers()
            }
            .onDisappear {
                cancellables.removeAll()
            }
        }
        .sheet(isPresented: $showPlayerSheet) {
            if let track = vm.nowPlaying {
                PlayerView(track: track, namespace: animationNamespace)
                    .environmentObject(vm)
            }
        }
    }

    private var resultsContent: some View {
        VStack(spacing: 0) {
            if vm.results.isEmpty {
                ScrollView {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, Metrics.resultsBottomPadding)
                }
                .scrollIndicators(.hidden)
            } else {
                List {
                    Section {
                        ForEach(vm.results) { track in
                            TrackRow(track: track)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    vm.play(track)
                                    withAnimation(.spring()) {
                                        showPlayerSheet = true
                                    }
                                }
                                .listRowBackground(Color.clear)
                        }
                    } header: {
                        resultsHeader
                            .textCase(nil)
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
                .background(Color.clear)
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [.black, .gray.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var resultsHeader: some View {
        Text("Search Results (\(vm.results.count))")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Metrics.horizontalPadding)
            .padding(.top, Metrics.topResultsPadding)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if let nowPlaying = vm.nowPlaying {
                miniPlayer(track: nowPlaying)
                    .padding(.horizontal, Metrics.horizontalPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isSearching {
                searchBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, Metrics.horizontalPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, max(keyboardHeight + 8, Metrics.bottomSafeSpacing))
        .animation(.easeInOut(duration: 0.25), value: isSearching)
        .animation(.easeInOut(duration: 0.25), value: vm.nowPlaying)
        .overlay(alignment: .bottom) {
            if !isSearching {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isSearching = true
                        isSearchFieldFocused = true
                    }
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .padding(.horizontal, 16)
                        .frame(height: Metrics.searchBarHeight)
                        .background(
                            glassCapsuleBackground()
                        )
                        .shadow(color: Color.black.opacity(0.24), radius: 12, x: 0, y: 3)
                        .shadow(color: Color.black.opacity(0.37), radius: 40, x: 0, y: 18)
                }
                .padding(.bottom, max(10, keyboardHeight + 16))
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search songs, artists, albums", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.webSearch)
                    .submitLabel(.search)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        submitSearch()
                    }

                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }

                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: Metrics.searchBarHeight)
            .background(glassCapsuleBackground())
            .overlay(
                Capsule()
                    .stroke(
                        Color.white.opacity(isSearchFieldFocused ? 0.35 : 0.20),
                        lineWidth: isSearchFieldFocused ? 1.5 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.10),
                radius: isSearchFieldFocused ? 50 : 40,
                x: 0,
                y: 2
            )
            .animation(.easeInOut(duration: 0.2), value: isSearchFieldFocused)

            if isSearchFieldFocused {
                Button("Cancel") {
                    withAnimation {
                        isSearching = false
                    }
                    isSearchFieldFocused = false
                    vm.searchText = ""
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func miniPlayer(track: Track) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "waveform")
                        .foregroundStyle(.white.opacity(0.8))
                )
                .matchedGeometryEffect(id: "albumArt", in: animationNamespace)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.callout)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "title", in: animationNamespace)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "artist", in: animationNamespace)
            }

            Spacer()

            Button {
                if vm.isPlaying {
                    vm.pause()
                } else {
                    vm.play(track)
                }
            } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            AirPlayRoutePickerView()
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .accessibilityLabel("AirPlay")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(glassCapsuleBackground())
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring()) {
                showPlayerSheet = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 80)
            Image(systemName: "music.note.list")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Search by artist, title, or version")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 40)
        }
    }

    @MainActor
    @ViewBuilder
    private func glassCapsuleBackground() -> some View {
        if #available(iOS 16.4, *) {
            Capsule()
                .fill(.thinMaterial)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                        .blendMode(.overlay)
                )
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                        .blendMode(.overlay)
                )
        }
    }

    private func submitSearch() {
        let trimmed = vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        vm.searchText = trimmed
        vm.results.removeAll()
        vm.search()
        isSearchFieldFocused = false
    }

    @MainActor
    private func bottomSafeAreaInset() -> CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom) ?? 0
    }

    @MainActor
    private func registerKeyboardPublishers() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo }
            .map { userInfo -> (height: CGFloat, duration: Double, curve: UIView.AnimationOptions) in
                let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
                let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
                let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
                let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)
                let height = max(0, endFrame.height - bottomSafeAreaInset())
                return (height, duration, curve)
            }
            .receive(on: RunLoop.main)
            .sink { payload in
                UIView.animate(
                    withDuration: payload.duration,
                    delay: 0,
                    options: payload.curve,
                    animations: {
                        keyboardHeight = payload.height
                    },
                    completion: nil
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { $0.userInfo }
            .map { userInfo -> (duration: Double, curve: UIView.AnimationOptions) in
                let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
                let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
                let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)
                return (duration, curve)
            }
            .receive(on: RunLoop.main)
            .sink { payload in
                UIView.animate(
                    withDuration: payload.duration,
                    delay: 0,
                    options: payload.curve,
                    animations: {
                        keyboardHeight = 0
                    },
                    completion: nil
                )
            }
            .store(in: &cancellables)
    }
}
