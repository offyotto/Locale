import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: LocaleStore
    @State private var currentStep = 0
    @State private var stepAppeared = false
    @Environment(\.dismiss) private var dismiss

    let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "globe",
            iconColor: Color(red: 0.3, green: 0.55, blue: 0.95),
            title: "Welcome to Locale",
            subtitle: "macOS Network Context Manager",
            description: "Locale lets you switch between named /etc/hosts configurations without editing system files by hand.",
            detail: nil
        ),
        OnboardingStep(
            icon: "list.bullet.rectangle",
            iconColor: Color(red: 0.25, green: 0.72, blue: 0.42),
            title: "What are Contexts?",
            subtitle: "One context per environment",
            description: "A context is a named set of hosts entries for an environment such as a client VPN, local API, lab network, or temporary debug setup.",
            detail: "Create as many contexts as you need. Locale preserves everything outside its own managed block in /etc/hosts."
        ),
        OnboardingStep(
            icon: "doc.text",
            iconColor: Color(red: 0.95, green: 0.55, blue: 0.2),
            title: "Hosts Entries",
            subtitle: "IP to hostname mappings",
            description: "Each context holds a list of IP to hostname mappings. When you activate a context, enabled entries are written to Locale's managed block in /etc/hosts.",
            detail: "Locale asks you to approve its helper once, creates a backup before writing, and flushes the local DNS cache after a successful apply."
        ),
        OnboardingStep(
            icon: "menubar.rectangle",
            iconColor: Color(red: 0.95, green: 0.65, blue: 0.2),
            title: "Menu Bar Access",
            subtitle: "Always one click away",
            description: "Locale lives in your menu bar. Click the globe icon to see your active context and switch instantly — without opening the main window.",
            detail: "The menu bar item shows the active context so you always know which environment is applied."
        )
    ]

    var isLastStep: Bool { currentStep == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(steps: steps, currentStep: currentStep)

            StepView(step: steps[currentStep], appeared: $stepAppeared)
                .id(currentStep)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            .frame(maxWidth: .infinity, minHeight: 320)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)

            Spacer()

            OnboardingNavigationBar(
                currentStep: currentStep,
                isLastStep: isLastStep,
                accentColor: steps[currentStep].iconColor,
                back: prevStep,
                next: isLastStep ? finish : nextStep
            )
        }
        .frame(width: 520, height: 480)
        .background(.background)
        .onChange(of: currentStep) { _, _ in
            stepAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    stepAppeared = true
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                stepAppeared = true
            }
        }
    }

    private func nextStep() {
        withAnimation { currentStep = min(currentStep + 1, steps.count - 1) }
    }
    private func prevStep() {
        withAnimation { currentStep = max(currentStep - 1, 0) }
    }
    private func finish() {
        store.markOnboarded()
    }
}

private struct OnboardingProgressDots: View {
    let steps: [OnboardingStep]
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { index in
                Capsule()
                    .fill(dotColor(for: index))
                    .frame(width: index == currentStep ? 24 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentStep)
        .padding(.top, 32)
        .padding(.bottom, 28)
    }

    private func dotColor(for index: Int) -> Color {
        index == currentStep ? steps[index].iconColor : Color.primary.opacity(0.15)
    }
}

private struct OnboardingNavigationBar: View {
    let currentStep: Int
    let isLastStep: Bool
    let accentColor: Color
    let back: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button(action: back) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            Button(action: next) {
                HStack(spacing: 7) {
                    Text(isLastStep ? "Get Started" : "Continue")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: isLastStep ? "checkmark" : "chevron.right")
                        .font(.system(size: 11, weight: isLastStep ? .bold : .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor)
                        .shadow(color: accentColor.opacity(0.4), radius: 12, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 32)
        .animation(.spring(response: 0.3), value: currentStep)
    }
}

// MARK: - Step View
struct StepView: View {
    let step: OnboardingStep
    @Binding var appeared: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.1))
                    .frame(width: 90, height: 90)
                Circle()
                    .fill(step.iconColor.opacity(0.18))
                    .frame(width: 70, height: 70)
                Image(systemName: step.icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(step.iconColor)
            }
            .scaleEffect(appeared ? 1.0 : 0.6)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)
            .padding(.bottom, 22)

            // Title
            Text(step.title)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .offset(y: appeared ? 0 : 14)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.05), value: appeared)

            // Subtitle
            Text(step.subtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(step.iconColor)
                .padding(.top, 4)
                .padding(.bottom, 14)
                .offset(y: appeared ? 0 : 10)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.1), value: appeared)

            // Description
            Text(step.description)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 48)
                .offset(y: appeared ? 0 : 8)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.15), value: appeared)

            // Detail
            if let detail = step.detail {
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 48)
                    .padding(.top, 12)
                    .offset(y: appeared ? 0 : 6)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.2), value: appeared)
            }
        }
        .padding(.horizontal, 36)
    }
}

// MARK: - Onboarding Step Model
struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    let detail: String?
}
