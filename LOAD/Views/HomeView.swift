import SwiftUI
import UIKit
import AVKit
import Combine

@available(iOS 26.0, *)
@ViewBuilder

private func glassBackground() -> some View {

        Rectangle()
            .fill(.clear)
            .background(
                .thinMaterial
            )
            .overlay(
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 0))
            )
    }

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

    // Remove NSObjectProtocol tokens; use Combine publishers instead
    @State private var cancellables = Set<AnyCancellable>()

    private enum Metrics {
        static let horizontalPadding: CGFloat = 20
        static let bottomSafeSpacing: CGFloat = 20
        static let searchBarHeight: CGFloat = 44
        static let resultsBottomPadding: CGFloat = 120
        static let topResultsPadding: CGFloat = 10
    }
    @Binding var showSheet: Bool
    @Namespace var animationNamespace

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
            .onAppear {
                registerKeyboardPublishers()
            }
            .onDisappear {
                cancellables.removeAll()
            }
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
                        .matchedGeometryEffect(id: "title", in: animationNamespace)
                    
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
                    .matchedGeometryEffect(id: "title", in: animationNamespace)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "artist", in: animationNamespace)
            }

            Spacer()

            Button { vm.isPlaying ? vm.pause() : vm.play(track) } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

     
            }
        }
        AirPlayRoutePickerView()
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .accessibilityLabel("AirPlay")
        }
            .background(.ultraThinMaterial) // liquid glass effect
            .onTapGesture {
                withAnimation(.spring()) {
                    showSheet = true
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
                // MARK: - Helpers

                private func timeString(from seconds: Double) -> String {
                    guard seconds.isFinite && seconds >= 0 else { return "0:00" }
                    let s = Int(seconds)
                    let min = s / 60
                    let sec = s % 60
                    return String(format: "%d:%02d", min, sec)
                }

     
                // Explicit type-erased ShapeStyle to avoid inference issues
                private func materialBackground() -> AnyShapeStyle {
                    if #available(iOS 26.0, *) {
                        return AnyShapeStyle(.regularMaterial)
                    } else {
                        return AnyShapeStyle(.ultraThinMaterial)
                    }
                }
            }

    // MARK: - Keyboard Handling (Publishers)
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
                UIView.animate(withDuration: payload.duration, delay: 0, options: payload.curve, animations: {
                    self.keyboardHeight = payload.height
                }, completion: nil)
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
                UIView.animate(withDuration: payload.duration, delay: 0, options: payload.curve, animations: {
                    self.keyboardHeight = 0
                }, completion: nil)
            }
            .store(in: &cancellables)
    }

    // MARK: - Scroll Offset Key
    private struct ScrollOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
}

