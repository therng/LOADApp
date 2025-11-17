import SwiftUI
import UIKit
import Combine

final class CancelBag: ObservableObject {
    var bag = Set<AnyCancellable>()
}

struct HomeView: View {
    @EnvironmentObject private var vm: HomeViewModel
    @Namespace private var animationNamespace
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isSearching = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showPlayerSheet = false
    @StateObject private var cancelBag = CancelBag()

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
                resultsContent
                    .animation(.easeInOut(duration: 0.25), value: keyboardHeight)

                bottomControls
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onSubmit(of: .search) {
                submitSearch()
            }
            .onAppear {
                registerKeyboardPublishers()
            }
            .onDisappear {
                cancelBag.bag.removeAll()
            }
        }
    }

    // MARK: - Results Content

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
                                }
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
                .background(Color.clear)
            }
        }
    }

    // MARK: - Bottom Controls (MiniPlayer + Search Button)

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

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search songs, artists, albums", text: $vm.query)
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.webSearch)
                    .submitLabel(.search)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        submitSearch()
                    }

                if !vm.query.isEmpty {
                    Button {
                        vm.query = ""
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
            .background(
                Capsule()
                    .fill(.thinMaterial.opacity(0.65))
                    .shadow(color: .black.opacity(0.06), radius: 25, y: 12)
            )
            .overlay(
                Capsule()
                    .stroke(
                        Color.primary.opacity(isSearchFieldFocused ? 0.35 : 0.20),
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
                Button {
                    withAnimation {
                        isSearching = false
                    }
                    isSearchFieldFocused = false
                    vm.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel search")
            }
        }
    }

    // MARK: - Mini Player (styled like Apple Music)

    private func miniPlayer(track: Track) -> some View {
        HStack(spacing: 10) {
            // Artwork / placeholder
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                // พื้นหลังด้านใน: เน้น contrast สูงขึ้นเล็กน้อย
                .fill(.ultraThinMaterial)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.92))
                )
                // เส้นขอบจางๆ เพื่อแบ่งจากฉากหลัง
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.18), lineWidth: 0.8)
                        .blendMode(.overlay)
                )
                .frame(width: 34, height: 34)
                .matchedGeometryEffect(id: "albumArt", in: animationNamespace)

            // Title
            Text(track.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary) // ให้คงคอนทราสต์
                .lineLimit(1)
                .matchedGeometryEffect(id: "title", in: animationNamespace)

            Spacer(minLength: 8)

            // Play/Pause
            Button {
                vm.isPlaying ? vm.pause() : vm.play(track)
            } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    // วงกลมโปร่งบางขึ้น
                    .background(.thinMaterial.opacity(0.9), in: Circle())
                    .overlay(
                        Circle().stroke(Color.primary.opacity(0.16), lineWidth: 0.9)
                            .blendMode(.overlay)
                    )
            }
            .buttonStyle(.plain)

            // AirPlay
            AirPlayRoutePickerView()
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
                // ให้โปร่งบางใกล้เคียงปุ่มเล่น
                .background(.thinMaterial.opacity(0.9), in: Circle())
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.14), lineWidth: 0.9)
                        .blendMode(.overlay)
                )
                .accessibilityLabel("AirPlay")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // พื้นหลังแคปซูล: โปร่งบางขึ้นเล็กน้อยและมีเส้นขอบนุ่ม
        .background(
            .regularMaterial.opacity(0.55),
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.20), lineWidth: 1)
                .blendMode(.overlay)
        )
        // เงานุ่มลงเล็กน้อยเพื่อไม่ดึงสายตาเกินไป
        .shadow(color: Color.black.opacity(0.26), radius: 16, y: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring()) {
                showPlayerSheet = true
            }
        }
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

    // MARK: - Glass Capsule Background (For Main Search Button)

    @MainActor
    @ViewBuilder
    private func glassCapsuleBackground() -> some View {
        if #available(iOS 16.4, *) {
            Capsule()
                .fill(.thinMaterial)
                .overlay(
                    Capsule()
                        .stroke(.primary.opacity(0.15), lineWidth: 1)
                        .blendMode(.overlay)
                )
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(.primary.opacity(0.2), lineWidth: 1)
                        .blendMode(.overlay)
                )
        }
    }

    // MARK: - Search Handling

    private func submitSearch() {
        let trimmed = vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        vm.query = trimmed
        vm.results.removeAll()
        vm.search()
        isSearchFieldFocused = false
    }

    // MARK: - Safe Area & Keyboard Handling

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
            .store(in: &cancelBag.bag)

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
            .store(in: &cancelBag.bag)
    }
}

#Preview {
    Group {
        HomeView()
            .environmentObject(HomeViewModel.makeDefault())
            .preferredColorScheme(.light)

        HomeView()
            .environmentObject(HomeViewModel.makeDefault())
            .preferredColorScheme(.dark)
    }
}
