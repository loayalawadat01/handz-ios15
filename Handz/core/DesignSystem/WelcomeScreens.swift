//
//  WelcomeScreens.swift
//  Handz
//
//  1. HandzSplashView: dark green splash each time the app opens —
//     the logo pops in, the mint dot bounces, the name fades up.
//  2. HandzStartView: the welcome page for people who aren't logged in —
//     floating Handz cards, "Get a hand. Or lend one.", "Get started" and "Log in".
//

import SwiftUI
import UIKit

private let splashGreen = Color(red: 15 / 255, green: 43 / 255, blue: 38 / 255)   // #0F2B26
private let logoMint = Color(red: 158 / 255, green: 230 / 255, blue: 220 / 255)   // #9EE6DC
private let logoTealTop = Color(red: 20 / 255, green: 140 / 255, blue: 128 / 255) // #148C80
private let logoTealBottom = Color(red: 11 / 255, green: 84 / 255, blue: 78 / 255) // #0B544E

// MARK: - Start: the welcome page, with Sign up and Log in

/// Shown whenever nobody is logged in.
struct HandzStartView: View {
    init() {}

    var body: some View {
        NavigationStack {
            HandzWelcomeView()
                .toolbar(.hidden, for: .navigationBar)
        }
        .tint(HandzColor.primary)
    }
}

// MARK: - The logo (same as the app icon)

/// Teal rounded square with a white "h" and a mint dot.
struct HandzLogoMark: View {
    let size: CGFloat
    var showDot: Bool

    init(size: CGFloat, showDot: Bool = true) {
        self.size = size
        self.showDot = showDot
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [logoTealTop, logoTealBottom],
                                     startPoint: UnitPoint(x: 0.25, y: 0),
                                     endPoint: UnitPoint(x: 0.75, y: 1)))
            Text("h")
                .font(.custom(HandzTypography.headingFontName, fixedSize: size * 0.74))
                .foregroundColor(.white)
                .offset(x: -size * 0.04, y: size * 0.045)
            Circle()
                .fill(logoMint)
                .frame(width: size * 0.15, height: size * 0.15)
                .scaleEffect(showDot ? 1 : 0.01)
                .offset(x: size * 0.2, y: -size * 0.15)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 1. Splash (ContentView shows it each time the app opens)

struct HandzSplashView: View {
    @State private var showMark = false
    @State private var showDot = false
    @State private var showWords = false
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {}

    var body: some View {
        ZStack {
            splashGreen.ignoresSafeArea()

            // Soft teal light behind the logo
            RadialGradient(colors: [logoTealTop.opacity(0.45), .clear],
                           center: .center, startRadius: 10, endRadius: 260)
                .scaleEffect(glow ? 1 : 0.5)
                .opacity(glow ? 1 : 0)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HandzLogoMark(size: 96, showDot: showDot)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .scaleEffect(showMark ? 1 : 0.5)
                    .opacity(showMark ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Handz")
                        .font(.custom(HandzTypography.headingFontName, fixedSize: 40))
                        .foregroundColor(.white)
                    Text("Get a hand. Lend a hand.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(logoMint.opacity(0.9))
                }
                .opacity(showWords ? 1 : 0)
                .offset(y: showWords ? 0 : 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Handz. Get a hand. Lend a hand.")
        .onAppear(perform: play)
    }

    private func play() {
        if reduceMotion {
            glow = true
            showMark = true
            showDot = true
            showWords = true
            return
        }
        withAnimation(.easeOut(duration: 0.9)) { glow = true }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { showMark = true }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.45).delay(0.4)) { showDot = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) { showWords = true }
    }
}

// MARK: - 2. Welcome page

private struct HandzWelcomeView: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let canvas = CGSize(width: 340, height: 360)

    /// The day highlighted in the little calendar (3 days from today).
    private let highlightedDay = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    init() {}

    var body: some View {
        VStack(spacing: 0) {
            logoRow
                .welcomePopIn(appeared, delay: 0)
                .padding(.top, 8)

            GeometryReader { geo in
                collage
                    .frame(width: canvas.width, height: canvas.height)
                    .scaleEffect(fitScale(geo.size))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .dynamicTypeSize(.large)
            .accessibilityHidden(true)

            textBlock
                .welcomePopIn(appeared, delay: 0.45)

            buttons
                .padding(.top, 24)
                .welcomePopIn(appeared, delay: 0.55)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HandzColor.background.ignoresSafeArea())
        .onAppear { appeared = true }
    }

    private func fitScale(_ size: CGSize) -> CGFloat {
        let scale = min(size.width / canvas.width, size.height / canvas.height)
        return max(0.5, min(1, scale))
    }

    // MARK: Top logo

    private var logoRow: some View {
        HStack(spacing: 10) {
            HandzLogoMark(size: 34)
            Text("Handz")
                .font(.custom(HandzTypography.headingFontName, fixedSize: 24))
                .foregroundColor(HandzColor.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Handz")
    }

    // MARK: Words

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get a hand.\nOr lend one.")
                .font(HandzTypography.largeTitle)
                .foregroundColor(HandzColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Post a job in minutes, or find paid work near you.")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Buttons

    private var buttons: some View {
        VStack(spacing: 4) {
            NavigationLink {
                SignupView()
            } label: {
                Text("Get started")
            }
            .buttonStyle(PrimaryButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { HandzHaptics.press() })

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
                NavigationLink {
                    LoginView()
                } label: {
                    Text("Log in")
                        .font(HandzTypography.callout.weight(.bold))
                        .foregroundColor(HandzColor.primary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: Floating cards

    private var collage: some View {
        ZStack {
            WelcomeLoopShape()
                .trim(from: 0, to: appeared ? 1 : 0)
                .stroke(HandzColor.primary.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))
                .frame(width: 56, height: 70)
                .offset(x: -146, y: -34)
                .animation(reduceMotion ? nil : Animation.easeInOut(duration: 1.0).delay(0.5), value: appeared)

            place(jobCard, x: 12, y: -78, angle: -2, float: 5, duration: 3.2, delay: 0.1)
            place(tag("Urgent", icon: "bolt.fill", fill: HandzColor.warning, ink: HandzColor.onFill),
                  x: -104, y: -152, angle: -8, float: 4, duration: 2.6, delay: 0.3)
            place(pill("4.9", icon: "star.fill", ink: HandzColor.warningInk),
                  x: 124, y: -160, angle: 5, float: 4, duration: 2.9, delay: 0.35)
            place(dayStrip, x: 0, y: 46, angle: 0, float: 3, duration: 3.6, delay: 0.2)
            place(tag("You earn $92.50", icon: "dollarsign.circle.fill", fill: HandzColor.accent, ink: HandzColor.onFill),
                  x: 92, y: 106, angle: 5, float: 5, duration: 2.8, delay: 0.4)
            place(pill("On the way · 12 min", icon: "car.fill", ink: HandzColor.primaryInk),
                  x: -80, y: 128, angle: -4, float: 4, duration: 3.0, delay: 0.45)
            place(logoTile, x: 4, y: 146, angle: 6, float: 6, duration: 3.4, delay: 0.5)
        }
    }

    /// Puts a card at its spot, tilts it, makes it pop in and gently float.
    private func place<V: View>(_ view: V, x: CGFloat, y: CGFloat, angle: Double,
                                float: CGFloat, duration: Double, delay: Double) -> some View {
        view
            .rotationEffect(.degrees(angle))
            .welcomeFloat(float, duration: duration, delay: delay)
            .welcomePopIn(appeared, delay: delay)
            .offset(x: x, y: y)
    }

    private var jobCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                HandzChip(text: "Moving", icon: "shippingbox", kind: .info)
                HandzChip(text: "3 hours", icon: "clock", kind: .neutral)
            }

            Text("Help moving a couch")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(HandzColor.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Workers hired")
                    Spacer()
                    Text("2 of 2")
                        .fontWeight(.bold)
                        .foregroundColor(HandzColor.primaryInk)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(HandzColor.textSecondary)

                ZStack(alignment: .leading) {
                    Capsule().fill(HandzColor.border)
                    Capsule()
                        .fill(HandzColor.primary)
                        .frame(width: appeared ? 222 : 0)
                        .animation(reduceMotion ? nil : Animation.easeOut(duration: 0.9).delay(0.7), value: appeared)
                }
                .frame(height: 6)
            }

            HStack {
                HStack(spacing: -8) {
                    avatar("AM", fill: HandzColor.primaryTint, ink: HandzColor.primaryInk)
                    avatar("JR", fill: HandzColor.accentTint, ink: HandzColor.accentInk)
                }
                Spacer()
                Label(highlightedDay.formatted(.dateTime.weekday(.abbreviated)) + " 9:00 AM",
                      systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
        .padding(14)
        .frame(width: 250, alignment: .leading)
        .background(cardBackground(radius: 22))
    }

    private func avatar(_ initials: String, fill: Color, ink: Color) -> some View {
        Text(initials)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(ink)
            .frame(width: 26, height: 26)
            .background(Circle().fill(fill))
            .overlay(Circle().stroke(HandzColor.surface, lineWidth: 2))
    }

    private var dayStrip: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { offset in
                dayCell(offset)
            }
        }
        .padding(8)
        .background(cardBackground(radius: 18))
    }

    private func dayCell(_ offset: Int) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        let isSelected = offset == 3
        return VStack(spacing: 2) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundColor(isSelected ? HandzColor.onFill : HandzColor.textSecondary)
        .frame(width: 40, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? HandzColor.primary : Color.clear)
        )
    }

    private var logoTile: some View {
        HandzLogoMark(size: 34)
            .padding(12)
            .background(cardBackground(radius: 18))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HandzColor.primary)
                    .offset(x: 8, y: -8)
            }
    }

    /// Solid colored tag ("Urgent", "You earn $92.50").
    private func tag(_ text: String, icon: String, fill: Color, ink: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundColor(ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(fill))
        .shadow(color: HandzColor.shadow.opacity(0.14), radius: 8, x: 0, y: 4)
    }

    /// White pill with a colored icon ("4.9", "On the way · 12 min").
    private func pill(_ text: String, icon: String, ink: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundColor(ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(HandzColor.surface)
                .overlay(Capsule().stroke(HandzColor.border, lineWidth: 1))
        )
        .shadow(color: HandzColor.shadow.opacity(0.10), radius: 8, x: 0, y: 4)
    }

    private func cardBackground(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(HandzColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(HandzColor.border, lineWidth: 1)
            )
            .shadow(color: HandzColor.shadow.opacity(0.10), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Motion helpers

/// Pops a piece in (fade + grow + rise), each a moment after the last.
private struct WelcomePopIn: ViewModifier {
    let shown: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(shown: Bool, delay: Double) {
        self.shown = shown
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.8)
            .offset(y: shown || reduceMotion ? 0 : 20)
            .animation(reduceMotion ? Animation.easeOut(duration: 0.3) : HandzMotion.bouncy.delay(delay), value: shown)
    }
}

/// Slowly bobs a piece up and down forever (off when Reduce Motion is on).
private struct WelcomeFloating: ViewModifier {
    let amplitude: CGFloat
    let duration: Double
    let delay: Double
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(amplitude: CGFloat, duration: Double, delay: Double) {
        self.amplitude = amplitude
        self.duration = duration
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .offset(y: reduceMotion ? 0 : (up ? -amplitude : amplitude))
            .animation(reduceMotion ? nil
                       : Animation.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay),
                       value: up)
            .onAppear {
                guard !reduceMotion else { return }
                DispatchQueue.main.async { up = true }
            }
    }
}

private extension View {
    func welcomePopIn(_ shown: Bool, delay: Double) -> some View {
        modifier(WelcomePopIn(shown: shown, delay: delay))
    }

    func welcomeFloat(_ amplitude: CGFloat, duration: Double, delay: Double) -> some View {
        modifier(WelcomeFloating(amplitude: amplitude, duration: duration, delay: delay))
    }
}

/// A hand-drawn looking swoosh next to the job card.
private struct WelcomeLoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.15),
                      control1: CGPoint(x: rect.minX - rect.width * 0.5, y: rect.minY + rect.height * 0.25),
                      control2: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

struct HandzStartView_Previews: PreviewProvider {
    static var previews: some View {
        HandzStartView()
            .environmentObject(AuthSession.shared)
    }
}
