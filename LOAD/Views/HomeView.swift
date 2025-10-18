import SwiftUI
import UIKit
import AVKit

@available(iOS 26.0, *)
@ViewBuilder
private func glassCapsuleIOS26() -> some View {
    Capsule().glassEffect(.regular, in: .capsule)
}

struct HomeView: View {
    @EnvironmentObject private var vm: HomeViewModel
    @FocusState private var focused: Bool
    @State private var isSearching = false
    @State private var offset: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedTrack: Track?
    @State private var accessoryInline: Bool = false

    // Keep observer tokens so we can remove them properly
    @State private var kbShowObserver: NSObjectProtocol?
    @State private var kbHideObserver: NSObjectProtocol?

    private enum Metrics {
        static let horizontalPadding: CGFloat = 20
        static let bottomSafeSpacing: CGFloat = 20
        static let searchBarHeight: CGFloat = 44
        static let resultsBottomPadding: CGFloat = 120
        static let topResultsPadding: CGFloat = 10
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                // Results area (List/Empty)
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
                                        .onTapGesture { vm.play(track) }
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
                .animation(.easeInOut(duration: 0.25), value: keyboardHeight)

                bottomControls
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: vm.searchText) { _, newValue in
                vm.query = newValue
            }
            .onSubmit(of: .search) {
                vm.search()
            }
            .onAppear { registerKeyboardObservers() }
            .onDisappear { removeKeyboardObservers() }

            // เปลี่ยนเป็น inspector sheet (iOS 18+) พร้อม fallback เป็น sheet
            .modifier(PlayerPresentationModifier(selectedTrack: $selectedTrack, vm: vm))
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(colors: [.black, .gray.opacity(0.4)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
        .ignoresSafeArea()
    }

    // MARK: - Header & Results
    private var resultsHeader: some View {
        Text("Search Results (\(vm.results.count))")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Metrics.horizontalPadding)
            .padding(.top, Metrics.topResultsPadding)
    }

    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 12) {
            if let nowPlaying = vm.nowPlaying {
                miniPlayer(track: nowPlaying)
                    .padding(.horizontal, Metrics.horizontalPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // เปลี่ยนจากกดค้าง -> แตะ เพื่อเปิด player sheet/inspector
                    .onTapGesture { selectedTrack = nowPlaying }
            }

            if isSearching {
                if accessoryInline, let np = vm.nowPlaying {
                    searchBarInlineMini(np)
                        .focused($focused)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear { focused = true }
                        .padding(.horizontal, Metrics.horizontalPadding)
                } else {
                    searchBar
                        .focused($focused)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear { focused = true }
                        .padding(.horizontal, Metrics.horizontalPadding)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 8 : 0)
        .animation(.easeInOut(duration: 0.25), value: offset)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .overlay(alignment: .bottom) {
            if !isSearching {
                Button {
                    withAnimation { isSearching = true }
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .padding(.horizontal, 16)
                        .frame(height: 44)
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

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            // Inner search field capsule
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
                    .focused($focused)
                    .onSubmit {
                        vm.query = vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        vm.results.removeAll()
                        vm.search()
                    }

                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }

                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: Metrics.searchBarHeight)
            .background(
                glassCapsuleBackground()
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(focused ? 0.35 : 0.20), lineWidth: focused ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: focused ? 50 : 40, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.2), value: focused)

            if focused {
                Button("Cancel") {
                    focused = false
                    withAnimation { isSearching = false }
                }
                .foregroundStyle(.secondary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    // MARK: - Search Bar + Inline Mini
    private func searchBarInlineMini(_ track: Track) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                // Mini area
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "waveform").font(.footnote).foregroundStyle(.white.opacity(0.85)))

                    Text(track.title)
                        .font(.footnote)
                        .lineLimit(1)
                        .frame(maxWidth: 90, alignment: .leading)
                        .foregroundStyle(.primary)

                    Button { vm.isPlaying ? vm.pause() : vm.play(track) } label: {
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill").font(.footnote)
                    }
                    .buttonStyle(.plain)
                }
                .frame(minWidth: 0)
                .layoutPriority(1)

                Divider().frame(height: 18).opacity(0.25)

                // Search field area
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

                    TextField("Search songs, artists, albums", text: $vm.searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.webSearch)
                        .submitLabel(.search)
                        .onSubmit {
                            vm.query = vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            vm.results.removeAll()
                            vm.search()
                        }

                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                    }

                    if vm.isLoading {
                        ProgressView().progressViewStyle(.circular).tint(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: Metrics.searchBarHeight)
            .background(glassCapsuleBackground())
            .overlay(
                Capsule().stroke(Color.white.opacity(focused ? 0.35 : 0.20), lineWidth: focused ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: focused ? 50 : 40, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.2), value: focused)

            if focused {
                Button("Cancel") {
                    focused = false
                    withAnimation { isSearching = false }
                }
                .foregroundStyle(.secondary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    // MARK: - Mini Player
    private func miniPlayer(track: Track) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "waveform")
                        .foregroundStyle(.white.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.callout)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button { vm.isPlaying ? vm.pause() : vm.play(track) } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            AirPlayRoutePickerView(
                tintColor: UIColor.white,
                activeTintColor: UIColor.systemBlue,
                prioritizesVideoDevices: false
            )
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .accessibilityLabel("AirPlay")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            glassCapsuleBackground()
        )
    }

    // MARK: - Empty State
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

    // MARK: - Liquid Glass Helpers
    @MainActor
    @ViewBuilder
    private func glassCapsuleBackground() -> some View {
        if #available(iOS 26.0, *) {
            glassCapsuleIOS26()
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

    // MARK: - Keyboard Observers
    @MainActor
    private func registerKeyboardObservers() {
        kbShowObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
            let bottomInset = (UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?.safeAreaInsets.bottom ?? 0)
            withAnimation(.easeInOut(duration: duration)) {
                keyboardHeight = max(0, frame.height - bottomInset)
            }
        }

        kbHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { note in
            let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            withAnimation(.easeInOut(duration: duration)) {
                keyboardHeight = 0
            }
        }
    }

    @MainActor
    private func removeKeyboardObservers() {
        if let o = kbShowObserver { NotificationCenter.default.removeObserver(o) }
        if let o = kbHideObserver { NotificationCenter.default.removeObserver(o) }
        kbShowObserver = nil
        kbHideObserver = nil
    }

    // MARK: - Scroll Offset Key
    private struct ScrollOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
}

// MARK: - Player Presentation (Inspector with fallback)
private struct PlayerPresentationModifier: ViewModifier {
    @Binding var selectedTrack: Track?
    let vm: HomeViewModel

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .inspector(item: $selectedTrack) { track in
                    FullPlayerView(track: track)
                        .environmentObject(vm)
                        .inspectorColumnWidth(min: 280, ideal: 360, max: 420)
                        .presentationDragIndicator(.visible)
                }
        } else {
            content
                .sheet(item: $selectedTrack) { track in
                    FullPlayerView(track: track)
                        .environmentObject(vm)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
        }
    }
}
