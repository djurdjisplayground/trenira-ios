import Foundation

/// In-app legal document copy for the TestFlight beta.
/// LAWYER REVIEW required before public App Store release — not professional legal advice.
enum LegalDocumentContent {
    static var privacyTitle: String { "Privacy Policy" }
    static var termsTitle: String { "Terms & Conditions" }

    static var privacyMarkdown: String {
        """
        # Privacy Policy

        **Effective date:** \(AppConfiguration.legalEffectiveDate)

        **Operator:** \(AppConfiguration.operatorName)  
        **Brand:** \(AppConfiguration.appName)  
        **Contact:** \(AppConfiguration.supportEmail)  
        **Availability:** \(AppConfiguration.serviceAvailability)

        This Privacy Policy describes how \(AppConfiguration.appName) processes information during the current TestFlight beta. It is provided for transparency and has not been independently reviewed as formal legal advice.

        ## 1. Who We Are

        \(AppConfiguration.appName) is operated by \(AppConfiguration.operatorName). The app is a workout-planning and strength-training organisation tool available worldwide.

        ## 2. Who Can Use the App

        The minimum age to use \(AppConfiguration.appName) is \(AppConfiguration.minimumUserAge) years. Founder consultations are limited to adults aged \(AppConfiguration.minimumConsultationAge) or older.

        ## 3. Information We Process

        Depending on how you use the app, \(AppConfiguration.appName) may process:

        - account or authentication identifiers if you sign in,
        - workout plans, set logs and progression preferences stored on your device,
        - commercial or technical purchase status through Apple when StoreKit is used,
        - consultation request details that you choose to place in an email,
        - optional beta feedback that you choose to send by email.

        \(AppConfiguration.appName) does not collect Apple or Google passwords. The current beta does not use advertising, behavioural tracking, analytics SDKs or crash-reporting SDKs.

        ## 4. Account and Authentication Data

        If you continue with Sign in with Apple or Google Sign-In, those providers process authentication data according to their own terms and privacy policies. \(AppConfiguration.appName) stores local session pointers needed to keep your workouts associated with the signed-in identity on this device. The app does not receive or store your Apple or Google password.

        Guest use does not require an account provider.

        ## 5. Workout and Fitness Information

        Workout templates, completed sets, progression settings and related training information are primarily stored locally on your device. The current beta does not upload workout information to a \(AppConfiguration.appName) backend.

        ## 6. Commercial and Technical Information

        During sandbox or App Store testing, Apple’s StoreKit may process subscription or purchase status. \(AppConfiguration.appName) does not sell personal information.

        ## 7. Consultation Requests

        Optional founder consultation requests may include:

        - name,
        - email address,
        - timezone,
        - current training experience,
        - what you want help with,
        - optional notes,
        - acknowledgement of the consultation scope.

        Please do not submit unnecessary medical, injury, medication or detailed health information.

        \(AppConfiguration.appName) does not send consultation forms to a \(AppConfiguration.appName) backend. The app prepares an email to \(AppConfiguration.consultationEmail). You review the message and must explicitly send it. Copying a request does not send it. Sent messages may be stored by your email provider and by the operator’s email provider.

        ## 8. How Information Is Used

        Information is used to:

        - provide workout organisation and progression features on your device,
        - maintain your local session after sign-in,
        - respond to consultation or feedback emails you choose to send,
        - operate and improve the beta product based on messages you send.

        ## 9. Local Data Storage

        Core training data for the beta remains on your device. You can erase local \(AppConfiguration.appName) data from Settings. Erasing local data does not delete emails you already sent, nor does it delete your Apple ID or Google account.

        ## 10. Email and Third-Party Processing

        Email composition and delivery involve Apple’s Mail capabilities and the email providers used by you and by \(AppConfiguration.operatorName). Authentication and StoreKit involve Apple and, if used, Google. Those services process data under their own policies.

        ## 11. Data Sharing

        \(AppConfiguration.appName) does not sell personal information. Information may be processed by Apple, Google (if used for sign-in) and email providers only as needed for the features you use.

        ## 12. Data Retention

        Local app data remains on your device until you delete it, uninstall the app, or erase local data in Settings. Emails you send are retained according to the relevant email providers and the operator’s ordinary inbox practices.

        ## 13. User Rights

        Depending on where you live, you may have rights to access, correct or delete personal information. For requests related to emails you sent to \(AppConfiguration.supportEmail), contact \(AppConfiguration.operatorName) at that address. For local workout data, use the in-app erase options or remove the app from your device.

        ## 14. Data Deletion

        You can erase local \(AppConfiguration.appName) data from Settings. This removes workouts, progression state, consultation drafts and related local content on the device. It does not revoke Apple or Google accounts and does not recall emails already sent.

        ## 15. Data Security

        \(AppConfiguration.appName) relies on platform protections for local storage and third-party providers for authentication and email. No method of storage or transmission is completely secure.

        ## 16. Children’s Privacy

        \(AppConfiguration.appName) is not directed at children under \(AppConfiguration.minimumUserAge). Founder consultations are not offered to anyone under \(AppConfiguration.minimumConsultationAge).

        ## 17. International Users

        The service is available worldwide. If you contact \(AppConfiguration.operatorName) by email, your message may be processed where the operator and email providers operate.

        ## 18. Changes to the Policy

        This policy may change as the beta evolves. The effective date above will be updated when material changes are published in the app.

        ## 19. Contact

        \(AppConfiguration.operatorName)  
        \(AppConfiguration.supportEmail)
        """
    }

    static var termsMarkdown: String {
        """
        # Terms & Conditions

        **Effective date:** \(AppConfiguration.legalEffectiveDate)

        **Operator:** \(AppConfiguration.operatorName)  
        **Brand:** \(AppConfiguration.appName)  
        **Contact:** \(AppConfiguration.supportEmail)

        These Terms explain how you may use \(AppConfiguration.appName) during the TestFlight beta. They are provided for clarity and have not been independently reviewed as formal legal advice. **LAWYER REVIEW required before public App Store release.**

        ## 1. About trenira

        \(AppConfiguration.appName) is a workout-planning and strength-training organisation tool. It helps you build workouts, track progression and stay consistent. It is not a medical, healthcare, physiotherapy or rehabilitation service.

        ## 2. Eligibility

        You must be at least \(AppConfiguration.minimumUserAge) years old to use the app. Founder consultations are limited to adults aged \(AppConfiguration.minimumConsultationAge) or older.

        ## 3. User Accounts

        You may use \(AppConfiguration.appName) as a guest or with Sign in with Apple or Google Sign-In where available. You are responsible for activity on your device under your chosen sign-in method.

        ## 4. Health Disclaimer

        \(AppConfiguration.appName) helps you organise and track strength training. It does not provide medical advice, diagnosis, physiotherapy or rehabilitation. You remain responsible for exercise selection, weight, repetitions, technique and intensity. Train within your abilities and consult an appropriately qualified professional for medical or injury-related concerns.

        ## 5. Workout Information

        Workout plans and logs are tools for organisation. They do not guarantee results and do not replace professional coaching or clinical care.

        ## 6. Founder Consultations

        Founder consultations are optional educational and organisational discussions based on lived training experience. They are not medical advice, physiotherapy, diagnosis, rehabilitation or professional nutritional treatment. Booking and payment details, when offered, are arranged separately outside StoreKit for the current beta.

        ## 7. Subscriptions and Purchases

        Digital purchases may be processed by Apple. TestFlight purchases use Apple’s sandbox environment. Premium features may be unlocked for all testers during closed beta without requiring a purchase.

        ## 8. Acceptable Use

        Use \(AppConfiguration.appName) lawfully and respectfully. Do not attempt to disrupt the service, misuse authentication, or submit unlawful content in emails you send.

        ## 9. Intellectual Property

        \(AppConfiguration.appName), its branding and its software remain the property of \(AppConfiguration.operatorName) and its licensors. You retain ownership of the workout content you create.

        ## 10. Availability

        Features may change, be interrupted or be unavailable. Worldwide availability does not guarantee identical features in every region.

        ## 11. Beta and TestFlight Versions

        Beta software may contain bugs, change or be removed. Data may be lost during beta testing. Please keep backups of any information that matters to you outside the app if needed.

        ## 12. Limitation of Liability

        To the extent permitted by applicable law, \(AppConfiguration.operatorName) is not liable for indirect or consequential losses arising from use of the beta app. Nothing in these Terms excludes or limits liability that cannot legally be excluded. Mandatory consumer rights remain unaffected.

        ## 13. Termination

        You may stop using \(AppConfiguration.appName) at any time and erase local data from Settings. \(AppConfiguration.operatorName) may discontinue beta access.

        ## 14. Privacy

        Personal information is described in the Privacy Policy.

        ## 15. Changes to the Terms

        These Terms may be updated as the beta evolves. Continued use after an in-app update constitutes acceptance of the revised Terms to the extent permitted by law.

        ## 16. Governing Law

        These Terms are governed by the laws applicable to the business operations of \(AppConfiguration.operatorName), subject to mandatory consumer protection rights that may apply in the user’s country of residence.

        **Internal note — lawyer review before public release:** confirm jurisdiction and consumer-law wording for the operator’s place of establishment.

        ## 17. Contact

        \(AppConfiguration.operatorName)  
        \(AppConfiguration.supportEmail)
        """
    }
}
