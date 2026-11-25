import SwiftUI

struct StatusPill: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(app.online ? Theme.green : Theme.red).frame(width: 7, height: 7)
            Text(app.online ? "Terhubung" : "Terputus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(app.online ? Color(red: 0.43, green: 0.91, blue: 0.72) : Color(red: 0.99, green: 0.65, blue: 0.69))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill((app.online ? Theme.green : Theme.red).opacity(0.12)))
        .overlay(Capsule().stroke((app.online ? Theme.green : Theme.red).opacity(0.25), lineWidth: 1))
    }
}

struct SoundButton: View {
    @State private var on = Fx.soundOn
    var body: some View {
        Button {
            Fx.soundOn.toggle()
            on = Fx.soundOn
            if on { Fx.tap() }
        } label: {
            Image(systemName: on ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Suara")
    }
}

struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @State private var summary: Summary?
    @State private var detail: Sale?
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ScreenHeader(title: "Halo, \(app.me?.name ?? "")", subtitle: Fmt.dayTitle(Fmt.iso(Date()))) {
                    HStack(spacing: 8) {
                        StatusPill()
                        SoundButton()
                    }
                }
                if let s = summary {
                    content(s)
                } else if loading {
                    ProgressView().tint(Theme.blue3).padding(.top, 80)
                } else {
                    EmptyState(symbol: "wifi.slash", text: "Data belum bisa dimuat. Tarik layar ke bawah untuk mencoba lagi.")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $detail) { sale in ReceiptSheet(sale: sale) }
    }

    private func load() async {
        summary = await app.summary(days: 7)
        loading = false
        await app.loadSales()
    }

    @ViewBuilder
    private func content(_ s: Summary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            KPICard(title: "Omzet hari ini", value: s.today.omzet, money: true, icon: "chart.line.uptrend.xyaxis", note: "\(Int(s.today.count)) transaksi hari ini", tint: Theme.blue3)
            KPICard(title: "Total penjualan", value: s.all.omzet, money: true, icon: "creditcard.fill", note: "\(Int(s.all.count)) transaksi tersimpan", tint: Theme.cyan)
            KPICard(title: "Pelanggan", value: Double(s.customers), money: false, icon: "person.2.fill", note: "Pelanggan terdaftar", tint: Theme.green)
            KPICard(title: "Produk", value: Double(s.products), money: false, icon: "shippingbox.fill", note: "Siap dipakai di kasir", tint: Theme.violet)
        }

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "Penjualan 7 hari terakhir", subtitle: "Ketuk batang untuk melihat nilainya")
                Spacer()
                Pill(text: Fmt.money(s.period.omzet))
            }
            BarChart(points: s.daily)
        }
        .glassCard()

        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Produk terlaris", subtitle: "7 hari terakhir")
            if s.top.isEmpty {
                EmptyState(symbol: "shippingbox", text: "Belum ada penjualan pada periode ini.")
            } else {
                let maxV = max(s.top.map { $0.omzet }.max() ?? 1, 1)
                ForEach(Array(s.top.enumerated()), id: \.element.id) { index, t in
                    HBarRow(title: t.name, trailing: Fmt.money(t.omzet) + " · " + Fmt.qty(t.qty) + " terjual", ratio: t.omzet / maxV, index: index)
                }
            }
        }
        .glassCard()

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SectionTitle(title: "Transaksi terbaru")
                Spacer()
                Button("Lihat semua") {
                    Fx.select()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { app.tab = .riwayat }
                }
                .buttonStyle(SoftButtonStyle())
            }
            .padding(.bottom, 8)
            if s.recent.isEmpty {
                EmptyState(symbol: "doc.text", text: "Belum ada transaksi. Mulai dari menu Kasir.")
            } else {
                ForEach(s.recent) { r in
                    Button {
                        Task { @MainActor in
                            if let sale = await app.fetchSale(id: r.id) {
                                Fx.open()
                                detail = sale
                            }
                        }
                    } label: {
                        recentRow(r)
                    }
                    .buttonStyle(.plain)
                    if r.id != s.recent.last?.id { Divider().overlay(Theme.line) }
                }
            }
        }
        .glassCard()
    }

    private func recentRow(_ r: RecentSale) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(text: r.customerLabel, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.invoice).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text(r.customerLabel + " · " + Fmt.dateTime(r.date))
                    .font(.system(size: 12)).foregroundColor(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(Fmt.money(r.total)).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: laporan (7 / 30 / 90 hari)

struct ReportsView: View {
    @EnvironmentObject var app: AppState
    @State private var days = 30
    @State private var summary: Summary?
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    PillSegment(options: [7, 30, 90], title: { "\($0) hari" }, selection: $days)
                    Spacer()
                }
                if let s = summary {
                    content(s)
                } else if loading {
                    ProgressView().tint(Theme.blue3).padding(.top, 80)
                } else {
                    EmptyState(symbol: "wifi.slash", text: "Laporan belum bisa dimuat. Tarik layar ke bawah untuk mencoba lagi.")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Laporan")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: days) { _ in
            Task { @MainActor in await load() }
        }
    }

    private func load() async {
        let s = await app.summary(days: days)
        if s != nil { withAnimation(.easeInOut(duration: 0.25)) { summary = s } }
        loading = false
    }

    @ViewBuilder
    private func content(_ s: Summary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            KPICard(title: "Omzet periode", value: s.period.omzet, money: true, icon: "chart.line.uptrend.xyaxis", note: "\(s.period.days) hari terakhir", tint: Theme.blue3)
                .id("omzet\(s.period.days)")
            KPICard(title: "Transaksi", value: s.period.count, money: false, icon: "doc.text.fill", note: "Jumlah nota", tint: Theme.cyan)
                .id("count\(s.period.days)")
            KPICard(title: "Rata-rata per nota", value: s.period.avg, money: true, icon: "creditcard.fill", note: "Omzet dibagi jumlah nota", tint: Theme.green)
                .id("avg\(s.period.days)")
            KPICard(title: "Total diskon", value: s.period.discount, money: true, icon: "tag.fill", note: "Potongan yang diberikan", tint: Theme.violet)
                .id("disc\(s.period.days)")
        }

        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Omzet harian", subtitle: "Per hari, \(s.period.days) hari terakhir")
            BarChart(points: s.daily).id("chart\(s.period.days)")
        }
        .glassCard()

        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Produk terlaris")
            if s.top.isEmpty {
                EmptyState(symbol: "shippingbox", text: "Belum ada penjualan pada periode ini.")
            } else {
                let maxV = max(s.top.map { $0.omzet }.max() ?? 1, 1)
                ForEach(Array(s.top.enumerated()), id: \.element.id) { index, t in
                    HBarRow(title: t.name, trailing: Fmt.money(t.omzet) + " · " + Fmt.qty(t.qty), ratio: t.omzet / maxV, index: index)
                }
            }
        }
        .glassCard()
        .id("top\(s.period.days)")

        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Pelanggan teratas", subtitle: "Berdasarkan omzet pada periode ini")
            if s.topCustomers.isEmpty {
                EmptyState(symbol: "person.2", text: "Belum ada transaksi pada periode ini.")
            } else {
                let maxV = max(s.topCustomers.map { $0.omzet }.max() ?? 1, 1)
                ForEach(Array(s.topCustomers.enumerated()), id: \.element.id) { index, c in
                    HBarRow(title: c.name, trailing: Fmt.money(c.omzet) + " · \(Int(c.count)) nota", ratio: c.omzet / maxV, index: index)
                }
            }
        }
        .glassCard()
        .id("cust\(s.period.days)")
    }
}
