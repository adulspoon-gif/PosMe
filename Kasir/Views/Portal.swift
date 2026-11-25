import SwiftUI

/// Tampilan untuk pelanggan: hanya transaksi, detail, dan nota miliknya sendiri.
struct CustomerShell: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var detail: Sale?
    @State private var showPassword = false
    @State private var confirmLogout = false

    private var filtered: [Sale] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return app.sales }
        return app.sales.filter { $0.invoice.lowercased().contains(q) }
    }

    private var totalSpent: Double { return app.sales.reduce(0) { $0 + $1.total } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScreenHeader(title: "Halo, \(app.me?.name ?? "")", subtitle: "Berikut riwayat transaksi Anda") {
                    HStack(spacing: 8) {
                        StatusPill()
                        SoundButton()
                        menu
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    KPICard(title: "Total transaksi", value: Double(app.sales.count), money: false, icon: "doc.text.fill", note: "Tercatat atas nama Anda", tint: Theme.blue3)
                    KPICard(title: "Total belanja", value: totalSpent, money: true, icon: "creditcard.fill", note: "Akumulasi seluruh transaksi", tint: Theme.green)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.muted)
                    TextField("Cari nomor nota", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Theme.muted) }
                            .buttonStyle(.plain)
                    }
                }
                .fieldStyle()

                if filtered.isEmpty {
                    EmptyState(symbol: "doc.text", text: app.sales.isEmpty ? "Belum ada transaksi atas nama Anda." : "Nota tidak ditemukan.")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { s in
                            Button {
                                Fx.open()
                                detail = s
                            } label: {
                                SaleRow(sale: s).glassCard(padding: 12, radius: 18)
                            }
                            .buttonStyle(ProductCardStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await app.loadSales() }
        .sheet(item: $detail) { sale in ReceiptSheet(sale: sale) }
        .sheet(isPresented: $showPassword) { ChangePasswordSheet() }
        .confirmationDialog("Keluar dari akun?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Keluar", role: .destructive) { Task { await app.logout() } }
            Button("Batal", role: .cancel) {}
        }
    }

    private var menu: some View {
        Menu {
            Button { showPassword = true } label: { Label("Ganti password", systemImage: "lock.fill") }
            Toggle(isOn: $app.biometricLock) { Label("Kunci dengan Face ID", systemImage: "faceid") }
            Button(role: .destructive) { confirmLogout = true } label: { Label("Keluar", systemImage: "rectangle.portrait.and.arrow.right") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
        }
    }
}
