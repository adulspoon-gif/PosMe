import SwiftUI

/// Warna dan gaya yang sama dengan versi web (navy biru, kartu kaca, aksen biru).
enum Theme {
    static let bg0 = Color(red: 0.020, green: 0.043, blue: 0.094)      // #050b18
    static let bg1 = Color(red: 0.027, green: 0.063, blue: 0.133)      // #071022
    static let bg2 = Color(red: 0.055, green: 0.114, blue: 0.239)      // #0e1d3d
    static let card = Color(red: 0.047, green: 0.094, blue: 0.200)     // #0c1833
    static let text = Color(red: 0.886, green: 0.910, blue: 0.941)     // #e2e8f0
    static let muted = Color(red: 0.580, green: 0.639, blue: 0.722)    // #94a3b8
    static let blue = Color(red: 0.231, green: 0.510, blue: 0.965)     // #3b82f6
    static let blue2 = Color(red: 0.145, green: 0.388, blue: 0.922)    // #2563eb
    static let blue3 = Color(red: 0.376, green: 0.647, blue: 0.980)    // #60a5fa
    static let indigo = Color(red: 0.310, green: 0.275, blue: 0.898)   // #4f46e5
    static let cyan = Color(red: 0.133, green: 0.827, blue: 0.933)     // #22d3ee
    static let green = Color(red: 0.204, green: 0.827, blue: 0.600)    // #34d399
    static let red = Color(red: 0.984, green: 0.443, blue: 0.522)      // #fb7185
    static let amber = Color(red: 0.984, green: 0.749, blue: 0.141)    // #fbbf24
    static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)   // #a78bfa
    static let line = Color.white.opacity(0.09)

    static let brand = LinearGradient(colors: [blue, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let primary = LinearGradient(colors: [blue2, blue], startPoint: .leading, endPoint: .trailing)
    static let bar = LinearGradient(colors: [blue3, blue, Color(red: 0.114, green: 0.306, blue: 0.847)], startPoint: .top, endPoint: .bottom)
}

/// Latar navy dengan cahaya lembut di pojok, sama seperti halaman web.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bg1, Theme.bg0], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.bg2, Color.clear], center: .topLeading, startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Theme.cyan.opacity(0.10), Color.clear], center: .bottomTrailing, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Kartu kaca: isi biru gelap transparan, garis tipis, bayangan lembut.
    func glassCard(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.card.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
    }

    /// Gaya kolom isian gelap.
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.28)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .foregroundColor(Theme.text)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: LinearGradient = Theme.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(color))
            .shadow(color: Theme.blue2.opacity(0.55), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.text
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct Pill: View {
    var text: String
    var tint: Color = Theme.blue3
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
            .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

struct SectionTitle: View {
    var title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            if let s = subtitle { Text(s).font(.system(size: 12)).foregroundColor(Theme.muted) }
        }
    }
}

struct EmptyState: View {
    var symbol: String
    var text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 30)).foregroundColor(Theme.muted.opacity(0.8))
            Text(text).font(.system(size: 13)).foregroundColor(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
