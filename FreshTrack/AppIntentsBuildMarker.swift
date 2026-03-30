import AppIntents

@available(iOS 17.0, *)
private enum AppIntentsBuildMarker {
    // Keep a direct AppIntents type reference so Xcode's metadata extraction
    // step sees the framework dependency even before we add real shortcuts.
    static let frameworkType: (any AppIntent.Type)? = nil
}
