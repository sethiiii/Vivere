import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isComplete: Bool
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "checkmark.circle.fill",
            eyebrow: "MAKE IT YOURS",
            title: "Small actions,\nbeautifully simple.",
            detail: "Build routines with one-tap check-ins, flexible goals, and a calm view of today."
        ),
        OnboardingPage(
            symbol: "book.closed.fill",
            eyebrow: "REFLECT",
            title: "Your habits tell\na bigger story.",
            detail: "Pair progress with a private daily journal, thoughtful prompts, photos, and inspiration."
        ),
        OnboardingPage(
            symbol: "lock.shield.fill",
            eyebrow: "YOURS, ALWAYS",
            title: "Premium tools.\nNo subscription.",
            detail: "Everything stays on your device. Enable advanced modules only when you want them."
        )
    ]

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { isComplete = true }
                        .foregroundStyle(.secondary)
                        .opacity(page == pages.count - 1 ? 0 : 1)
                        .disabled(page == pages.count - 1)
                }
                .padding(.horizontal, 24)
                .frame(height: 52)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        pageView(item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? AppTheme.accent : Color.secondary.opacity(0.22))
                            .frame(width: index == page ? 26 : 8, height: 8)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: page)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(page + 1) of \(pages.count)")
                .padding(.bottom, 28)

                Button {
                    if page == pages.count - 1 {
                        isComplete = true
                    } else if reduceMotion {
                        page += 1
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Begin" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
        .interactiveDismissDisabled()
    }

    private func pageView(_ item: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 16)

            Image(systemName: item.symbol)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 88, height: 88)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 26))
                .accessibilityHidden(true)

            Text(item.eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Text(item.title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-1)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.detail)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 30)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingPage {
    let symbol: String
    let eyebrow: String
    let title: String
    let detail: String
}
