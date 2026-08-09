import SwiftUI

/// Simple, local Terms & Conditions and Privacy Policy views.
/// These are intentionally self-contained, static views stored in the app bundle.

struct TermsView: View {
    private let termsText = """
Terms & Conditions

1. Acceptance
By using Vivere ("the App"), you agree to these Terms & Conditions. If you do not agree, do not use the App.

2. Use of the App
The App is provided for personal, non-commercial use. You may not redistribute, reverse engineer, or otherwise misuse the App.

3. Intellectual Property
All content, design, and code in the App are the property of the developer unless otherwise stated.

4. Disclaimer of Warranties
The App is provided "as is" without warranties of any kind. The developer does not warrant uninterrupted or error-free operation.

5. Limitation of Liability
To the fullest extent permitted by law, the developer is not liable for any indirect, incidental, special or consequential damages arising from use of the App.

6. Changes
These Terms may be updated. Continued use after changes constitutes acceptance of the updated Terms.

7. Contact
For questions about these Terms, contact the developer in the app's support channels.
"""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Terms & Conditions")
                    .font(.title2)
                    .bold()
                Text(termsText)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding()
        }
        .navigationTitle("Terms & Conditions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    private let privacyText = """
Privacy Policy

1. Introduction
This Privacy Policy explains how Vivere collects, uses, and protects information when you use the App.

2. Data Collected
Vivere is designed to store personal habit data on your device. The App does not require an account, does not collect advertising identifiers, and does not include analytics SDKs by default.

3. Local Storage
Personal data created in the App (habits, journals, backups) is stored locally on your device unless you explicitly export it.

4. Backups and Exports
If you export a backup, you control where the file is stored. The App does not transmit backups to any third-party service by default.

5. Sharing and Third Parties
The App does not share your personal habit data with third parties, unless you explicitly use system share/export features or choose to integrate a third-party service.

6. Security
Reasonable measures are taken to protect local data, but no method of storage is 100% secure. Keep device-level protections (passcode, biometrics) enabled.

7. Children
The App is not intended for children under 13. If you believe we have collected data from a child, contact support.

8. Changes
This policy may be updated; the effective date is shown in the app release notes. Continued use constitutes acceptance.

9. Contact
For privacy questions contact the developer through the app's support channels.
"""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy Policy")
                    .font(.title2)
                    .bold()
                Text(privacyText)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
struct LegalViews_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TermsView()
        }
        NavigationStack {
            PrivacyPolicyView()
        }
    }
}
#endif
