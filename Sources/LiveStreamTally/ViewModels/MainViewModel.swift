//
//  MainViewModel.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation
import SwiftUI
import Combine
import os
import Network

@MainActor
final class MainViewModel: ObservableObject {
    @Published var isLive = false {
        didSet {
            if oldValue != isLive {
                // Update timer interval when live status changes
                updateTimerInterval()
                Logger.debug("isLive changed from \(oldValue) to \(isLive)", category: .main)
            }
        }
    }
    @Published var viewerCount = 0 {
        didSet {
            if oldValue != viewerCount {
                Logger.debug("viewerCount changed from \(oldValue) to \(viewerCount)", category: .main)
            }
        }
    }
    @Published var title = "" {
        didSet {
            if oldValue != title {
                Logger.debug("title changed to: \(title)", category: .main)
            }
        }
    }
    @Published var error: String?
    @Published var isLoading = false
    @Published var currentTime: String = ""
    @Published var showDateTime: Bool = false
    @Published var showViewerCount: Bool = false

    // Remove @AppStorage properties
    // @AppStorage("youtube_channel_id") private var channelId = ""
    // @AppStorage("youtube_channel_id_cached") private var cachedChannelId = ""
    // @AppStorage("youtube_upload_playlist_id") private var uploadPlaylistId = ""

    // Add properties that will be updated from PreferencesManager
    private var channelId: String = ""
    private var cachedChannelId: String = ""
    private var uploadPlaylistId: String = ""

    private var youtubeService: (any YouTubeServiceProtocol)?
    private let preferences: any PreferencesManagerProtocol
    private let clock: any ClockProtocol
    private var statusCheckPublisher: AnyCancellable?
    private var timePublisher: AnyCancellable?

    // Flag to prevent concurrent Task accumulation in polling timer
    private var isCheckingStatus = false

    // Flag to prevent replacing injected services in tests
    private let serviceWasInjected: Bool

    // Shared date formatter for time updates
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a" // 12-hour format with AM/PM
        return formatter
    }()

    // Add cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // Track startup network retry state
    private var startupRetryCount = 0
    private let maxStartupRetries = 5
    private var startupRetryTask: Task<Void, Never>?

    /// Primary initializer with dependency injection for testing
    init(
        youtubeService: (any YouTubeServiceProtocol)? = nil,
        preferences: any PreferencesManagerProtocol,
        clock: any ClockProtocol = SystemClock(),
        isTestMode: Bool = false
    ) {
        Logger.debug("MainViewModel.init() called with injected dependencies", category: .main)

        self.youtubeService = youtubeService
        self.preferences = preferences
        self.clock = clock
        self.serviceWasInjected = isTestMode

        // Initialize with current values from preferences
        self.channelId = preferences.getChannelId()
        self.cachedChannelId = preferences.cachedChannelId
        self.uploadPlaylistId = preferences.uploadPlaylistId
        self.showDateTime = preferences.showDateTime
        self.showViewerCount = preferences.showViewerCount

        // Setup subscriptions to preferences publishers
        setupPreferenceSubscriptions()

        // Register for notifications
        registerForNotifications()
    }

    /// Convenience initializer for production use
    convenience init(apiKey: String? = nil) {
        Logger.debug("MainViewModel.init() called (convenience)", category: .main)

        let prefs = PreferencesManager.shared
        let keyToUse = apiKey ?? prefs.getApiKey()

        var service: (any YouTubeServiceProtocol)? = nil
        if let keyToUse = keyToUse, !keyToUse.isEmpty {
            do {
                // Create YouTubeService directly - no caching needed
                // Performance test shows service creation takes only ~0.03ms
                service = try YouTubeService(apiKey: keyToUse)
            } catch {
                Logger.error("Failed to initialize YouTube service: \(error.localizedDescription)", category: .main)
            }
        }

        self.init(
            youtubeService: service,
            preferences: prefs,
            clock: SystemClock()
        )
    }

    deinit {
        // Combine cancellables are automatically cancelled
    }

    private func setupPreferenceSubscriptions() {
        // Only subscribe if preferences is the real PreferencesManager (has publishers)
        // Test doubles don't need subscriptions
        guard let prefs = preferences as? PreferencesManager else {
            return
        }

        // Subscribe to channelId changes
        prefs.$channelId
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.channelId = newValue
            }
            .store(in: &cancellables)

        // Subscribe to cachedChannelId changes
        prefs.$cachedChannelId
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.cachedChannelId = newValue
            }
            .store(in: &cancellables)

        // Subscribe to uploadPlaylistId changes
        prefs.$uploadPlaylistId
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.uploadPlaylistId = newValue
            }
            .store(in: &cancellables)

        // Subscribe to showDateTime changes
        prefs.$showDateTime
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.showDateTime = newValue
            }
            .store(in: &cancellables)

        // Subscribe to showViewerCount changes
        prefs.$showViewerCount
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.showViewerCount = newValue
            }
            .store(in: &cancellables)
    }

    private func registerForNotifications() {
        Logger.debug("REGISTERING NOTIFICATIONS in MainViewModel", category: .main)

        // Register for API key changes using Combine
        NotificationCenter.default.publisher(for: PreferencesManager.NotificationNames.apiKeyChanged)
            .sink { [weak self] _ in
                self?.handleApiKeyChanged()
            }
            .store(in: &cancellables)

        // Register for channel ID changes using Combine
        NotificationCenter.default.publisher(for: PreferencesManager.NotificationNames.channelChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleChannelChangedAsync()
                }
            }
            .store(in: &cancellables)

        // Register for interval changes using Combine
        NotificationCenter.default.publisher(for: PreferencesManager.NotificationNames.intervalChanged)
            .sink { [weak self] _ in
                self?.handleIntervalChanged()
            }
            .store(in: &cancellables)
    }

    private func handleApiKeyChanged() {
        // Don't replace injected services (used in tests)
        guard !serviceWasInjected else {
            Logger.debug("Ignoring API key change - service was injected", category: .main)
            return
        }

        // Reinitialize YouTubeService with new API key
        if let apiKey = preferences.getApiKey() {
            do {
                // Create a new service instance - no caching needed
                youtubeService = try YouTubeService(apiKey: apiKey)
                error = nil
            } catch let serviceError {
                error = "Failed to initialize YouTube service: \(serviceError.localizedDescription)"
            }
        }
    }

    private func handleChannelChangedAsync() async {
        // Clear YouTube service cache when channel changes
        youtubeService?.clearCache()

        // Restart monitoring if active
        if statusCheckPublisher != nil {
            await stopMonitoring()
            await startMonitoring()
        }
    }

    private func handleIntervalChanged() {
        // Update timer interval when intervals are changed in preferences
        updateTimerInterval()
    }

    func getAPIKey() -> String? {
        return preferences.getApiKey()
    }

    private func updateTimerInterval() {
        guard statusCheckPublisher != nil else { return }

        // Cancel existing publisher
        statusCheckPublisher?.cancel()

        // Get new interval based on live status
        let interval = isLive ? preferences.getLiveCheckInterval() : preferences.getNotLiveCheckInterval()

        // Create new publisher with updated interval
        statusCheckPublisher = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                // Skip if a status check is already in progress
                guard !self.isCheckingStatus else {
                    Logger.warning("Skipping status check - previous check still in progress", category: .main)
                    return
                }

                Task { [weak self] in
                    await self?.checkLiveStatus()
                }
            }
    }

    /// Thread-safe flag for network availability check
    private final class NetworkCheckState: @unchecked Sendable {
        private let lock = NSLock()
        private var _hasResumed = false

        var hasResumed: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _hasResumed
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _hasResumed = newValue
            }
        }
    }

    /// Check if network is available
    private func isNetworkAvailable() async -> Bool {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.richardbolt.livestreamtally.networkcheck")
            let state = NetworkCheckState()

            monitor.pathUpdateHandler = { path in
                if !state.hasResumed {
                    state.hasResumed = true
                    monitor.cancel()
                    continuation.resume(returning: path.status == .satisfied)
                }
            }

            monitor.start(queue: queue)

            // Set a timeout to prevent indefinite waiting
            queue.asyncAfter(deadline: .now() + 1.0) {
                if !state.hasResumed {
                    state.hasResumed = true
                    monitor.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func startMonitoring() async {
        Logger.debug("Monitoring timer started", category: .main)

        // Cancel any existing retry task
        startupRetryTask?.cancel()
        startupRetryTask = nil

        guard youtubeService != nil else {
            error = "YouTube service not initialized. Please check your API key."
            return
        }

        guard !channelId.isEmpty else {
            error = "Channel ID not configured"
            return
        }

        // Stop any existing publisher
        await stopMonitoring()

        isLoading = true

        // Check immediately with network retry logic
        await checkLiveStatusWithStartupRetry()
        isLoading = false

        // Get initial interval from preferences
        let initialInterval = preferences.getNotLiveCheckInterval()

        // Start periodic checks with Combine publisher
        statusCheckPublisher = Timer.publish(every: initialInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                // Skip if a status check is already in progress
                guard !self.isCheckingStatus else {
                    Logger.warning("Skipping status check - previous check still in progress", category: .main)
                    return
                }

                Task { [weak self] in
                    await self?.checkLiveStatus()
                }
            }

        // Start time updates
        startTimeUpdates()
    }

    /// Check live status with automatic retry on network errors during startup
    private func checkLiveStatusWithStartupRetry() async {
        // Try the initial check
        await checkLiveStatus()

        // Check if we got a network error
        if let currentError = error, currentError.contains("Network error") {
            Logger.warning("Network error during startup, will retry with exponential backoff", category: .main)

            // Start exponential backoff retry
            startupRetryTask = Task { @MainActor in
                while startupRetryCount < maxStartupRetries {
                    // Calculate delay with exponential backoff: 1s, 2s, 4s, 8s, 16s
                    let delay = pow(2.0, Double(startupRetryCount))
                    Logger.info("Retrying in \(Int(delay)) seconds (attempt \(startupRetryCount + 1)/\(maxStartupRetries))", category: .main)

                    // Update error message to show we're retrying
                    error = "Network unavailable. Retrying in \(Int(delay))s... (attempt \(startupRetryCount + 1)/\(maxStartupRetries))"

                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Check if task was cancelled
                    if Task.isCancelled {
                        Logger.debug("Startup retry task cancelled", category: .main)
                        return
                    }

                    // Check if network is available
                    if !(await isNetworkAvailable()) {
                        Logger.info("Network still unavailable, continuing to wait...", category: .main)
                        startupRetryCount += 1
                        continue
                    }

                    // Try checking status again
                    Logger.info("Network available, retrying status check", category: .main)
                    await checkLiveStatus()

                    // If we got here without error, we succeeded
                    if error == nil || !error!.contains("Network error") {
                        Logger.info("Status check succeeded on retry", category: .main)
                        startupRetryCount = 0
                        error = nil // Clear any retry messages
                        return
                    }

                    startupRetryCount += 1
                }

                // Max retries reached
                if startupRetryCount >= maxStartupRetries {
                    Logger.error("Max startup retries reached, giving up", category: .main)
                    error = "Unable to connect to YouTube after \(maxStartupRetries) attempts. Please check your network connection."
                }
            }
        } else {
            // No network error, reset retry count
            startupRetryCount = 0
        }
    }

    func stopMonitoring() async {
        statusCheckPublisher?.cancel()
        statusCheckPublisher = nil
        stopTimeUpdates()

        // Cancel any startup retry task
        startupRetryTask?.cancel()
        startupRetryTask = nil
        startupRetryCount = 0

        // Reset the checking flag to prevent stuck state when stopping during active check
        isCheckingStatus = false

        Logger.info("Monitoring stopped", category: .main)
    }

    private func startTimeUpdates() {
        Logger.debug("TimeUpdates publisher started", category: .main)
        // Format initial time
        currentTime = timeFormatter.string(from: Date())

        // Use a publisher that doesn't trigger as many UI updates
        timePublisher = Timer.publish(every: 1.0, on: .main, in: .default)
            .autoconnect()
            // Throttle updates to reduce frequency
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Only update if the formatted time is actually different
                let newTime = self.timeFormatter.string(from: Date())
                if self.currentTime != newTime {
                    self.currentTime = newTime
                }
            }
    }

    private func stopTimeUpdates() {
        Logger.debug("TimeUpdates publisher stopped", category: .main)
        timePublisher?.cancel()
        timePublisher = nil
    }

    private func checkLiveStatus() async {
        guard let youtubeService = youtubeService else { return }

        // Set flag to prevent concurrent checks
        isCheckingStatus = true
        defer { isCheckingStatus = false }

        // Create a local copy of the service to avoid isolation issues
        let service = youtubeService

        do {
            // Get the latest values from preferences
            let currentChannelId = channelId
            let currentCachedChannelId = cachedChannelId
            let currentUploadPlaylistId = uploadPlaylistId

            // If we don't have a cached channel ID or playlist ID, resolve it
            if currentCachedChannelId.isEmpty || currentUploadPlaylistId.isEmpty {
                // Clear any cached video data when resolving a new channel
                service.clearCache()

                // Resolve the channel identifier
                let (resolvedChannelId, resolvedPlaylistId) = try await service.resolveChannelIdentifier(currentChannelId)

                // Update resolved info in preferences
                preferences.setResolvedChannelInfo(
                    channelId: resolvedChannelId,
                    playlistId: resolvedPlaylistId
                )

                // Use the newly resolved values for this check
                let status = try await service.checkLiveStatus(
                    channelId: resolvedChannelId,
                    uploadPlaylistId: resolvedPlaylistId
                )

                // Update UI state
                isLive = status.isLive
                viewerCount = status.viewerCount
                title = status.title
                error = nil
            } else {
                // Use existing cached values
                let status = try await service.checkLiveStatus(
                    channelId: currentCachedChannelId,
                    uploadPlaylistId: currentUploadPlaylistId
                )

                // Update UI state
                isLive = status.isLive
                viewerCount = status.viewerCount
                title = status.title
                error = nil
            }

            Logger.debug("Status updated - isLive: \(isLive), viewers: \(viewerCount), title: \(title)", category: .main)

        } catch let serviceError {
            if case YouTubeError.quotaExceeded = serviceError {
                self.error = "YouTube API quota exceeded. Please try again later."
            } else {
                self.error = "Failed to check live status: \(serviceError.localizedDescription)"
            }
            Logger.error("Failed to check live status: \(serviceError.localizedDescription)", category: .main)
        }
    }

    func updateApiKey(_ newApiKey: String) {
        if preferences.updateApiKey(newApiKey) {
            // The notification handler will reinitialize the service
            error = nil
        } else {
            error = "Failed to save API key to Keychain"
        }
    }

    func updateChannelId(_ newChannelId: String) {
        // Use preferences to update channel ID
        // This will trigger notifications that we observe
        preferences.updateChannelId(newChannelId)
    }
}
