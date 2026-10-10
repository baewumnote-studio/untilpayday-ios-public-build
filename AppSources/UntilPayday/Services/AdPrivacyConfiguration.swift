#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdPrivacyConfiguration {
    static func configure() {
        #if canImport(GoogleMobileAds)
        let configuration = MobileAds.shared.requestConfiguration
        configuration.setPublisherFirstPartyIDEnabled(false)
        configuration.maxAdContentRating = GADMaxAdContentRating.general
        configuration.publisherPrivacyPersonalizationState = .disabled
        #endif
    }
}
