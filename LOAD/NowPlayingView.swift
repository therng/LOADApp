import Combine
import UIKit
import SwiftUI

final class MiniPlayerView: UIView {
    private enum Constants {
        static let playButtonSize: CGFloat = 36
        static let floatingCornerRadius: CGFloat = 18
        static let inlineCornerRadius: CGFloat = 0
    }
    
    private let chromeView = UIView()
    private let effectView = UIVisualEffectView(effect: nil)
    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    
    private var stateCancellable: AnyCancellable?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupBindings()
        updateInitialAppearance()
        configureTraitTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupBindings()
        updateInitialAppearance()
        configureTraitTracking()
    }
    
    private func setupView() {
        backgroundColor = .clear
        layoutMargins = UIEdgeInsets(top: 6, left: 16, bottom: 10, right: 16)
        
        chromeView.translatesAutoresizingMaskIntoConstraints = false
        chromeView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        chromeView.layer.cornerRadius = Constants.floatingCornerRadius
        chromeView.layer.masksToBounds = false
        addSubview(chromeView)
        
        NSLayoutConstraint.activate([
            chromeView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            chromeView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            chromeView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            chromeView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
        
        chromeView.layoutMargins = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        
        // Background effect view for material/blur styling
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.clipsToBounds = true
        chromeView.addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: chromeView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: chromeView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: chromeView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: chromeView.bottomAnchor)
        ])
        
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingTail
        
        subtitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.lineBreakMode = .byTruncatingTail
        
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.tintColor = .label
        playPauseButton.backgroundColor = .tertiarySystemFill
        playPauseButton.layer.cornerRadius = Constants.playButtonSize / 2
        playPauseButton.addTarget(self, action: #selector(handlePlayPauseTapped), for: .touchUpInside)
        
        chromeView.addSubview(textStack)
        chromeView.addSubview(playPauseButton)
        
        NSLayoutConstraint.activate([
            playPauseButton.trailingAnchor.constraint(equalTo: chromeView.layoutMarginsGuide.trailingAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: chromeView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: Constants.playButtonSize),
            playPauseButton.heightAnchor.constraint(equalToConstant: Constants.playButtonSize),
            
            textStack.leadingAnchor.constraint(equalTo: chromeView.layoutMarginsGuide.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: chromeView.centerYAnchor)
        ])
        
        updateState(.idle)
    }
    
    private func setupBindings() {
        stateCancellable = AudioPlayerService.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateState(state)
            }
    }
    
    @objc private func handlePlayPauseTapped() {
        // TODO: Wire this up to AudioPlayerService to toggle play/pause.
        // Leaving empty to avoid compile errors if service API is unknown here.
    }
    
    private func configureTraitTracking() {
        registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { (view: MiniPlayerView, _) in
            view.updateProperties()
        }
    }
    
    private func updateInitialAppearance() {
        updateProperties()
    }
    
    override func updateProperties() {
        _ = traitCollection.tabAccessoryEnvironment == .inline
    }
    
    private func updateState(_ state: AudioPlayerService.PlayerState) {
        switch state {
        case .idle:
            titleLabel.text = "Nothing playing"
            subtitleLabel.text = "Search for a track to start"
            playPauseButton.isEnabled = false
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        case .loading(let track):
            titleLabel.text = track.title
            subtitleLabel.text = "Loading..."
            playPauseButton.isEnabled = false
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        case .ready(let track):
            titleLabel.text = track.title
            subtitleLabel.text = track.artist
            playPauseButton.isEnabled = true
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        case .playing(let track):
            titleLabel.text = track.title
            subtitleLabel.text = track.artist
            playPauseButton.isEnabled = true
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        case .paused(let track):
            titleLabel.text = track.title
            subtitleLabel.text = track.artist
            playPauseButton.isEnabled = true
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        case .failed(let message):
            titleLabel.text = "Playback failed"
            subtitleLabel.text = message
            playPauseButton.isEnabled = false
            playPauseButton.setImage(UIImage(systemName: "exclamationmark.triangle.fill"), for: .normal)
        }
        
        playPauseButton.alpha = playPauseButton.isEnabled ? 1.0 : 0.6
    }
}

#Preview("MiniPlayerView") {

      }

