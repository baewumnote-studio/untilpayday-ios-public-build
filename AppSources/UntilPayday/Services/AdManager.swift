import Foundation
import Combine
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    private let frequency = AdFrequencyController()
    private var initialized = false

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    #endif

    private override init() {}

    func initializeAndPreload(canRequestAds: Bool) async {
        guard canRequestAds else { return }
        #if canImport(GoogleMobileAds)
        if !initialized {
            AdPrivacyConfiguration.configure()
            await MobileAds.shared.start()
            initialized = true
        }
        await preload()
        #endif
    }

    func preload() async {
        #if canImport(GoogleMobileAds)
        guard interstitial == nil, !AdConfig.interstitialUnitID.isEmpty else { return }
        do {
            let request = Request()
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
            let ad = try await InterstitialAd.load(with: AdConfig.interstitialUnitID, request: request)
            ad.fullScreenContentDelegate = self
            interstitial = ad
        } catch {
            interstitial = nil
        }
        #endif
    }

    func presentIfEligible(trigger: AdTrigger) {
        #if canImport(GoogleMobileAds)
        guard let interstitial else {
            Task { await preload() }
            return
        }
        guard frequency.mayShow(for: trigger) else { return }
        interstitial.present(from: nil)
        #endif
    }
}

#if canImport(GoogleMobileAds)
extension AdManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        frequency.recordShown()
        interstitial = nil
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitial = nil
        Task { await preload() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
        Task { await preload() }
    }
}
#endif

enum AdConfig {
    #if DEBUG
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let interstitialUnitID = Bundle.main.object(forInfoDictionaryKey: "GADInterstitialAdUnitID") as? String ?? ""
    #endif
}
