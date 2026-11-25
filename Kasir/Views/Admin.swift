import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: menu "Lainnya"

struct MoreCard: View {
    var title: String
    var subtitle: String
    var icon: String
    var tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(tint.opacity(0.16)))
            Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(subtitle).font(.system(size: 12)).foregroundColor(Theme.muted).lineLimit(2).multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16, radius: 20)
    }
}

struct MoreView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    AvatarCircle(text: app.me?.name ?? "A", size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.me?.name ?? "Admin").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        Text("Administrator").font(.system(size: 13)).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    StatusPill()
                }
                .glassCard(padding: 16, radius: 22)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    NavigationLink { ProductsView() } label: {
                        MoreCard(title: "Produk", subtitle: "Harga, stok, dan satuan barang", icon: "shippingbox.fill", tint: Theme.violet)
                    }
                    NavigationLink { ReportsView() } label: {
                        MoreCard(title: "Laporan", subtitle: "Omzet 7, 30, dan 90 hari", icon: "chart.bar.fill", tint: Theme.blue3)
                    }
                    NavigationLink { AccountsView() } label: {
                        MoreCard(title: "Akun akses", subtitle: "Login untuk pelanggan Anda", icon: "key.fill", tint: Theme.green)
                    }
                    NavigationLink { SettingsView() } label: {
                        MoreCard(title: "Pengaturan", subtitle: "Toko, nota, keamanan, backup", icon: "gearshape.fill", tint: Theme.cyan)
                    }
                }
                .buttonStyle(MoreLinkStyle())
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle("Lainnya")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct MoreLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed { Fx.tap() }
            }
    }
}

// MARK: daftar akun pelanggan

struct AccountsView: View {
    @EnvironmentObject var app: AppState
    @State private var users: [UserAccount] = []
    @State private var loading = true
    @State private var accessFor: Int?

    private struct Target: Identifiable { var id: Int }

    var body: some View {
        List {
            if users.isEmpty && !loading {
                EmptyState(symbol: "key", text: "Belum ada akun pelanggan. Buat dari menu Pelanggan: geser baris lalu ketuk Akses.")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(users) { u in
                Button {
                    if let cid = u.customerId {
                        Fx.open()
                        accessFor = cid
                    }
                } label: {
                    HStack(spacing: 12) {
                        AvatarCircle(text: u.customerName ?? u.username, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(u.customerName ?? "-").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            Text("@" + u.username).font(.system(size: 12)).foregroundColor(Theme.muted)
                            Text(u.lastLogin == nil ? "Belum pernah login" : "Login terakhir " + Fmt.dateTime(u.lastLogin ?? ""))
                                .font(.system(size: 11)).foregroundColor(Theme.muted)
                        }
                        Spacer()
                        Pill(text: u.isActive ? "Aktif" : "Nonaktif", tint: u.isActive ? Theme.green : Theme.muted)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Theme.card.opacity(0.85))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Akun akses")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: Binding(get: { accessFor.map { Target(id: $0) } }, set: { if $0 == nil { accessFor = nil; Task { await load() } } })) { t in
            AccessSheet(customerId: t.id)
        }
    }

    private func load() async {
        let all = await app.loadUsers()
        users = all.filter { $0.role == "pelanggan" }
        loading = false
    }
}

// MARK: ganti password

struct ChangePasswordSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    var forced: Bool = false
    @State private var current = ""
    @State private var next = ""
    @State private var again = ""
    @State private var saving = false

    private var valid: Bool { return !current.isEmpty && next.count >= 6 && next == again && !saving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if forced {
                        Text("Password Anda masih password bawaan. Segera ganti agar akun aman.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.99, green: 0.9, blue: 0.54))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.amber.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.amber.opacity(0.3), lineWidth: 1))
                    }
                    SecureField("Password saat ini", text: $current).fieldStyle()
                    SecureField("Password baru (minimal 6 karakter)", text: $next).fieldStyle()
                    SecureField("Ulangi password baru", text: $again).fieldStyle()
                    if !again.isEmpty && next != again {
                        Text("Ulangi password baru dengan benar.").font(.system(size: 12)).foregroundColor(Theme.red)
                    }
                    Button {
                        saving = true
                        Task { @MainActor in
                            let ok = await app.changePassword(current: current, next: next)
                            saving = false
                            if ok { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if saving { ProgressView().tint(.white) }
                            Text("Simpan password")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!valid)
                    .opacity(valid ? 1 : 0.5)
                    .padding(.top, 4)
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Ganti password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(forced ? "Nanti saja" : "Batal") { dismiss() } } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: pengaturan (toko, nota, keamanan, backup)

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var name = ""
    @State private var subtitle = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var storeNo = ""
    @State private var policy = ""
    @State private var footer = ""
    @State private var saving = false
    @State private var loaded = false
    @State private var showPassword = false
    @State private var serverText = ""
    @State private var showServerEdit = false
    @State private var exportURL: URL?
    @State private var showExport = false
    @State private var showImporter = false
    @State private var importData: Data?
    @State private var importName = ""
    @State private var importPreview: ImportResult?
    @State private var importDone: ImportResult?
    @State private var importing = false
    @State private var confirmLogout = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                storeCard
                receiptCard
                preferencesCard
                securityCard
                backupCard
                Button(role: .destructive) { confirmLogout = true } label: {
                    Label("Keluar dari akun", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.red))
                Text("Kasir Pribadi iOS 1.0").font(.system(size: 11)).foregroundColor(Theme.muted).padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle("Pengaturan")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { fill() }
        .sheet(isPresented: $showPassword) { ChangePasswordSheet() }
        .sheet(isPresented: $showExport) { if let u = exportURL { ShareSheet(items: [u]) } }
        .sheet(item: $importPreview) { r in importPreviewSheet(r) }
        .sheet(item: $importDone) { r in importDoneSheet(r) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .data, .item], allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert("Alamat server", isPresented: $showServerEdit) {
            TextField("https://alamat-server", text: $serverText)
            Button("Simpan") {
                app.applyServer(serverText)
                Task { await app.ping() }
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Alamat Tailscale Funnel server kasir.")
        }
        .confirmationDialog("Keluar dari akun?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Keluar", role: .destructive) { Task { await app.logout() } }
            Button("Batal", role: .cancel) {}
        }
    }

    private func fill() {
        if loaded { return }
        guard let s = app.settings else { return }
        name = s.name
        subtitle = s.subtitle ?? ""
        address = s.address ?? ""
        phone = s.phone ?? ""
        storeNo = s.storeNo ?? ""
        policy = ReceiptText.policy(s)
        footer = s.footer ?? ""
        loaded = true
    }

    private var storeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Identitas toko", subtitle: "Tercetak di bagian atas setiap nota")
            TextField("Nama toko", text: $name).fieldStyle()
            TextField("Nama tambahan / slogan", text: $subtitle).fieldStyle()
            TextField("Alamat toko", text: $address).fieldStyle()
            TextField("Nomor telepon", text: $phone).keyboardType(.phonePad).fieldStyle()
            TextField("Nomor toko (opsional)", text: $storeNo).fieldStyle()
        }
        .glassCard()
    }

    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Bagian bawah nota", subtitle: "Dicetak di bawah rincian transaksi")
            Text("CATATAN KEBIJAKAN").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.muted)
            TextField("Barang yang sudah dibeli tidak bisa ditukar / dikembalikan", text: $policy, axis: .vertical)
                .lineLimit(2...4)
                .fieldStyle()
            Text("PESAN PENUTUP").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.muted)
            TextField("Terimakasih atas kunjungan anda", text: $footer, axis: .vertical)
                .lineLimit(1...3)
                .fieldStyle()
            Button {
                saving = true
                let body = SettingsBody(name: name, subtitle: subtitle, address: address, phone: phone, storeNo: storeNo, footer: footer, policy: policy)
                Task { @MainActor in
                    _ = await app.saveSettings(body)
                    saving = false
                }
            } label: {
                HStack(spacing: 8) {
                    if saving { ProgressView().tint(.white) }
                    Text("Simpan pengaturan toko")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(saving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, 4)
        }
        .glassCard()
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Tampilan dan umpan balik")
            Toggle(isOn: Binding(get: { Fx.soundOn }, set: { Fx.soundOn = $0; if $0 { Fx.tap() } })) {
                Label("Suara", systemImage: "speaker.wave.2.fill")
            }
            .tint(Theme.blue)
            Toggle(isOn: Binding(get: { Fx.hapticsOn }, set: { Fx.hapticsOn = $0; if $0 { Fx.tap() } })) {
                Label("Getar (haptic)", systemImage: "iphone.radiowaves.left.and.right")
            }
            .tint(Theme.blue)
        }
        .foregroundColor(.white)
        .glassCard()
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Keamanan dan server")
            Toggle(isOn: $app.biometricLock) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Kunci dengan Face ID", systemImage: "faceid")
                    Text("Aplikasi meminta Face ID atau kode iPhone saat dibuka kembali.")
                        .font(.system(size: 11)).foregroundColor(Theme.muted)
                }
            }
            .tint(Theme.blue)
            Button { showPassword = true } label: {
                Label("Ganti password", systemImage: "lock.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle())
            Button {
                serverText = app.serverURL
                showServerEdit = true
            } label: {
                HStack {
                    Label("Alamat server", systemImage: "server.rack")
                    Spacer()
                    Text(app.serverURL).font(.system(size: 11)).foregroundColor(Theme.muted).lineLimit(1)
                }
            }
            .buttonStyle(SoftButtonStyle())
        }
        .foregroundColor(.white)
        .glassCard()
    }

    private var backupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Backup dan import data", subtitle: "Import hanya menggabungkan, data yang ada tidak dihapus")
            HStack(spacing: 10) {
                Button {
                    Task { @MainActor in
                        if let u = await app.exportBackup() {
                            exportURL = u
                            showExport = true
                        }
                    }
                } label: {
                    Label("Unduh backup", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue3))
                Button { showImporter = true } label: {
                    Label("Import backup", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue3))
            }
            Text("Sebelum import, server otomatis menyimpan salinan database. Terima file .json hasil unduhan atau file kasir.db.")
                .font(.system(size: 11)).foregroundColor(Theme.muted)
        }
        .glassCard()
    }

    // MARK: import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let e):
            app.show(e.localizedDescription, error: true)
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                app.show("File tidak bisa dibaca.", error: true)
                return
            }
            if data.count > 80 * 1024 * 1024 {
                app.show("File terlalu besar (maksimal 80 MB).", error: true)
                return
            }
            importData = data
            importName = url.lastPathComponent
            Task { @MainActor in
                if let r = await app.importBackup(data, dry: true) { importPreview = r }
            }
        }
    }

    private func importRow(_ title: String, _ p: ImportPart) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text("Di file: \(p.file)" + ((p.invalid ?? 0) > 0 ? " · tidak terbaca: \(p.invalid ?? 0)" : ""))
                    .font(.system(size: 12)).foregroundColor(Theme.muted)
            }
            Spacer()
            Pill(text: "+\(p.added) baru", tint: Theme.green)
            Pill(text: "\(p.skipped) sudah ada", tint: Theme.muted)
        }
    }

    private func importPreviewSheet(_ r: ImportResult) -> some View {
        let nothing = r.stats.customers.added == 0 && r.stats.products.added == 0 && r.stats.sales.added == 0
        return VStack(alignment: .leading, spacing: 14) {
            Text("Import backup").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            Text(importName).font(.system(size: 12)).foregroundColor(Theme.muted)
            importRow("Pelanggan", r.stats.customers)
            importRow("Produk", r.stats.products)
            importRow("Transaksi", r.stats.sales)
            Text(nothing ? "Semua data di file ini sudah ada di server, jadi tidak ada yang perlu ditambahkan."
                         : "Data baru akan digabungkan. Data yang sudah ada tidak diubah dan tidak dihapus. Salinan database disimpan otomatis sebelum import.")
                .font(.system(size: 13)).foregroundColor(Color(red: 0.75, green: 0.86, blue: 1))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.blue.opacity(0.12)))
            Spacer()
            if !nothing {
                Button {
                    guard let d = importData else { return }
                    importing = true
                    Task { @MainActor in
                        let done = await app.importBackup(d, dry: false)
                        importing = false
                        importPreview = nil
                        if let done = done {
                            importData = nil
                            await app.refreshAll()
                            Fx.success()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { importDone = done }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if importing { ProgressView().tint(.white) }
                        Text("Import sekarang")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(importing)
            }
            Button("Batal") { importPreview = nil }
                .buttonStyle(SoftButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(AppBackground())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func importDoneSheet(_ r: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import selesai").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            importRow("Pelanggan", r.stats.customers)
            importRow("Produk", r.stats.products)
            importRow("Transaksi", r.stats.sales)
            if let b = r.safetyBackup {
                Text("Salinan database sebelum import tersimpan di server: " + b)
                    .font(.system(size: 12)).foregroundColor(Theme.muted)
            }
            Spacer()
            Button("Selesai") { importDone = nil }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(22)
        .background(AppBackground())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

extension ImportResult: Identifiable {
    var id: String { return "\(stats.customers.added)-\(stats.products.added)-\(stats.sales.added)-\(dry)-\(safetyBackup ?? "")" }
}
