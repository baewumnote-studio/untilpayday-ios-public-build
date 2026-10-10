import Foundation
import Combine
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

@MainActor
final class ConsentManager: ObservableObject {
    @Published private(set) var canRequestAds = false
    @Published private(set) var privacyOptionsRequired = false

    func refresh() async {
        #if canImport(UserMessagingPlatform)
        let parameters = RequestParameters()
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }
        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // Budgeting must remain usable even when consent UI fails.
        }
        canRequestAds = ConsentInformation.shared.canRequestAds
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        canRequestAds = false
        privacyOptionsRequired = false
        #endif
    }

    func presentPrivacyOptions() async {
        #if canImport(UserMessagingPlatform)
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
        canRequestAds = ConsentInformation.shared.canRequestAds
        #endif
    }
}
