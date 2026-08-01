import AuthenticationServices

/// Builds Sign in with Apple requests with the minimum scopes trenira needs.
///
/// trenira uses only `ASAuthorizationAppleIDCredential.user` for local vault ownership.
/// Name and email scopes are intentionally not requested.
enum AppleSignInRequestFactory {
    /// Empty on purpose — no Contact Info scopes.
    static let requestedScopes: [ASAuthorization.Scope] = []

    static func makeRequest(
        provider: ASAuthorizationAppleIDProvider = ASAuthorizationAppleIDProvider()
    ) -> ASAuthorizationAppleIDRequest {
        let request = provider.createRequest()
        request.requestedScopes = requestedScopes
        return request
    }
}
