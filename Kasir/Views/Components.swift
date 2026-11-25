import SwiftUI
import UIKit

// MARK: angka yang menghitung naik

struct CountUp: View, Animatable {
    var value: Double
    var money: Bool
    var animatableData: Double {
        get { return value }
        set { value = newValue }
    }
    var body: some View {
        Text(money ? Fmt.money(value) : String(Int(value.rounded())))
    }
}

struct KPICard: View {
    var title: String
    var value: Double
    var money: Bool
    var icon: String
    var note: String
    var tint: Color = Theme.blue3
    @State private var shown: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 12)).foregroundColor(Theme.muted).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.16)))
            }
            CountUp(value: shown, money: money)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(note).font(.system(size: 11)).foregroundColor(Theme.muted).lineLimit(1)
        }
        .glassCard(padding: 14, radius: 18)
        .onAppear { animateIn() }
        .onChange(of: value) { _ in animateIn() }
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.9)) { shown = value }
    }
}

// MARK: grafik batang (disentuh untuk melihat nilai)

struct BarChart: View {
    var points: [DayPoint]
    @State private var grown = false
    @State private var selected: String? = nil

    private var maxValue: Double { return max(points.map { $0.omzet }.max() ?? 0, 1) }

    var body: some View {
        let step = points.count <= 7 ? 1 : (points.count <= 31 ? 5 : 15)
        HStack(alignment: .bottom, spacing: points.count > 14 ? 3 : 8) {
            ForEach(Array(points.enumerated()), id: \.element.id) { index, p in
                column(p, index: index, showLabel: points.count <= 7 || index % step == 0)
            }
        }
        .frame(height: 210)
        .task {
            try? await Task.sleep(nanoseconds: 90_000_000)
            grown = true
        }
    }

    private func column(_ p: DayPoint, index: Int, showLabel: Bool) -> some View {
        let ratio = CGFloat(p.omzet / maxValue)
        let h: CGFloat = grown ? max(4, 150 * ratio) : 4
        let parts = Fmt.chartDay(p.day)
        return VStack(spacing: 6) {
            Text(selected == p.id ? Fmt.short(p.omzet) : " ")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.blue3)
                .frame(height: 14)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            bar(filled: p.omzet > 0, selected: selected == p.id)
                .frame(height: h)
                .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(Double(index) * 0.03), value: grown)
            VStack(spacing: 0) {
                Text(showLabel ? parts.0 : " ").font(.system(size: 10)).foregroundColor(Theme.muted)
                Text(showLabel ? parts.1 : " ").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.text.opacity(0.8))
            }
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Fx.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = (selected == p.id) ? nil : p.id
            }
        }
    }

    @ViewBuilder
    private func bar(filled: Bool, selected: Bool) -> some View {
        if filled {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.bar)
                .shadow(color: Theme.blue.opacity(selected ? 0.8 : 0.35), radius: selected ? 14 : 8, x: 0, y: 0)
                .scaleEffect(x: selected ? 1.12 : 1, y: 1, anchor: .bottom)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.12))
        }
    }
}

// MARK: batang horizontal (produk terlaris)

struct HBarRow: View {
    var title: String
    var trailing: String
    var ratio: Double
    var index: Int
    @State private var grown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.text).lineLimit(1)
                Spacer(minLength: 8)
                Text(trailing).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.blue3).lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.blue2, Theme.blue, Theme.cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: grown ? max(8, geo.size.width * CGFloat(ratio)) : 8)
                        .shadow(color: Theme.blue.opacity(0.5), radius: 6, x: 0, y: 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(Double(index) * 0.08), value: grown)
                }
            }
            .frame(height: 9)
        }
        .task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            grown = true
        }
    }
}

// MARK: segmen dengan pil yang meluncur

struct PillSegment: View {
    var options: [Int]
    var title: (Int) -> String
    @Binding var selection: Int
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { opt in
                Button {
                    Fx.select()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selection = opt }
                } label: {
                    Text(title(opt))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selection == opt ? .white : Theme.muted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if selection == opt {
                                    Capsule().fill(Theme.primary).matchedGeometryEffect(id: "segPill", in: ns)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.card.opacity(0.9)))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: bilah menu melayang dengan pil yang meluncur

struct FloatingTabBar: View {
    @EnvironmentObject var app: AppState
    @Namespace private var ns

    private struct Item: Identifiable {
        var tab: AppTab
        var title: String
        var icon: String
        var id: Int { return tab.rawValue }
    }

    private let items: [Item] = [
        Item(tab: .dashboard, title: "Dashboard", icon: "square.grid.2x2.fill"),
        Item(tab: .kasir, title: "Kasir", icon: "cart.fill"),
        Item(tab: .riwayat, title: "Riwayat", icon: "doc.text.fill"),
        Item(tab: .pelanggan, title: "Pelanggan", icon: "person.2.fill"),
        Item(tab: .lainnya, title: "Lainnya", icon: "ellipsis")
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Theme.card.opacity(0.88))
                .background(Capsule().fill(.ultraThinMaterial))
        )
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func tabButton(_ item: Item) -> some View {
        let selected = app.tab == item.tab
        return Button {
            if app.tab != item.tab {
                Fx.select()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { app.tab = item.tab }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .overlay(alignment: .topTrailing) {
                        if item.tab == .kasir && app.cartCount > 0 {
                            Text("\(app.cartCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 15, minHeight: 15)
                                .background(Capsule().fill(Theme.red))
                                .offset(x: 10, y: -8)
                                .transition(.scale)
                        }
                    }
                if selected {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .foregroundColor(selected ? .white : Theme.muted)
            .padding(.horizontal, selected ? 14 : 12)
            .frame(height: 44)
            .frame(maxWidth: selected ? nil : 52)
            .background(
                ZStack {
                    if selected {
                        Capsule()
                            .fill(Theme.primary)
                            .shadow(color: Theme.blue.opacity(0.55), radius: 10, x: 0, y: 4)
                            .matchedGeometryEffect(id: "tabPill", in: ns)
                    }
                }
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }
}

// MARK: pesan singkat di atas layar

struct ToastHost: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack {
            if let t = app.toast {
                HStack(spacing: 10) {
                    Circle().fill(t.isError ? Theme.red : Theme.blue3).frame(width: 8, height: 8)
                    Text(t.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(t.isError ? Color(red: 1, green: 0.8, blue: 0.84) : Color(red: 0.86, green: 0.92, blue: 1))
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(t.isError ? Color(red: 0.18, green: 0.055, blue: 0.095) : Color(red: 0.043, green: 0.098, blue: 0.21)).opacity(0.97)
                )
                .overlay(Capsule().stroke((t.isError ? Theme.red : Theme.blue3).opacity(0.4), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { app.toast = nil }
            }
            Spacer()
        }
        .padding(.top, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: app.toast)
        .allowsHitTesting(app.toast != nil)
    }
}

// MARK: efek goyang saat login gagal

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 3), y: 0))
    }
}

// MARK: lembar bagikan (UIActivityViewController)

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: kepala layar dan baris umum

struct ScreenHeader<Trailing: View>: View {
    var title: String
    var subtitle: String
    var trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 13)).foregroundColor(Theme.muted)
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

struct SaleRow: View {
    var sale: Sale
    var showDate: Bool = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.blue3)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.blue.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(sale.invoice).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text(sale.customerLabel + " · " + Fmt.dateTime(sale.date))
                    .font(.system(size: 12)).foregroundColor(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.money(sale.total)).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                Text("\(sale.items.count) item").font(.system(size: 11)).foregroundColor(Theme.muted)
            }
        }
    }
}

struct AvatarCircle: View {
    var text: String
    var size: CGFloat = 40
    var body: some View {
        Text(String(text.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.brand))
    }
}

/// Memotong teks angka menjadi hanya digit lalu menjadi Double.
func digitsToDouble(_ s: String) -> Double {
    let digits = s.filter { $0.isNumber }
    return Double(digits) ?? 0
}
