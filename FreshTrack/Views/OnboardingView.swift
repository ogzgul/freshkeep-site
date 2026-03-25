import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "🛒",
            title: "Welcome to FreshKeep",
            description: "Track expiry dates of everything in your fridge and pantry. Stop throwing away food and money.",
            accentColor: .green
        ),
        OnboardingPage(
            icon: "📷",
            title: "Scan or Add Manually",
            description: "Tap + to add a product. Scan the barcode for instant name & category — or just type it in. Takes under 5 seconds.",
            accentColor: .blue
        ),
        OnboardingPage(
            icon: "🔔",
            title: "Get Notified in Time",
            description: "FreshKeep sends you a reminder 2 days before, 1 day before, and on the expiry day — so you never miss it.",
            accentColor: .orange
        ),
        OnboardingPage(
            icon: "🧺",
            title: "Shopping List Built-In",
            description: "Consumed or expired products are added to your shopping list automatically. You can also swipe any product left to add it manually.",
            accentColor: .purple
        ),
        OnboardingPage(
            icon: "📊",
            title: "See Your Savings",
            description: "The Statistics screen shows how much you've saved by using products before they expire — and how much was wasted.",
            accentColor: .teal
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        PageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? pages[currentPage].accentColor : Color(.systemGray4))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            isPresented = false
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(pages[currentPage].accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }

                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            isPresented = false
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - Page View

private struct PageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                Text(page.icon)
                    .font(.system(size: 72))
            }

            // Text
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 12)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Model

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}
