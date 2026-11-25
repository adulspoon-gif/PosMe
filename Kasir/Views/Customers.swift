import SwiftUI
import UIKit

struct CustomerEdit: Identifiable {
    var customer: Customer?
    var id: String { return customer.map { String($0.id) } ?? "baru" }
}

struct CustomersView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var editing: CustomerEdit?
    @State private var accessFor: Customer?
    @State private var deleting: Customer?
    @State private var showDelete = false

    private var filtered: [Customer] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return app.customers }
        return app.customers.filter { $0.name.lowercased().contains(q) || ($0.phone ?? "").contains(q) || ($0.accountUsername ?? "").lowercased().contains(q) }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                EmptyState(symbol: "person.2", text: query.isEmpty ? "Belum ada pelanggan. Ketuk + untuk menambah." : "Pelanggan tidak ditemukan.")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(filtered) { c in
                Button {
                    Fx.open()
                    editing = CustomerEdit(customer: c)
                } label: {
                    row(c)
                }
                .listRowBackground(Theme.card.opacity(0.85))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleting = c
                        showDelete = true
                    } label: { Label("Hapus", systemImage: "trash") }
                    Button {
                        accessFor = c
                    } label: { Label("Akses", systemImage: "key.fill") }
                    .tint(Theme.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Pelanggan")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(text: $query, prompt: "Cari nama, telepon, atau username")
        .refreshable { await app.loadCustomers() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Fx.open()
                    editing = CustomerEdit(customer: nil)
                } label: { Image(systemName: "plus.circle.fill").font(.system(size: 20)) }
            }
        }
        .sheet(item: $editing) { e in
            CustomerForm(customer: e.customer, onAccess: { c in
                editing = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { accessFor = c }
            })
        }
        .sheet(item: $accessFor) { c in AccessSheet(customerId: c.id) }
        .confirmationDialog("Hapus pelanggan?", isPresented: $showDelete, titleVisibility: .visible, presenting: deleting) { c in
            Button("Hapus " + c.name, role: .destructive) {
                Task { @MainActor in _ = await app.deleteCustomer(id: c.id) }
            }
            Button("Batal", role: .cancel) {}
        } message: { c in
            Text("Transaksi lama tetap tersimpan. Akun login pelanggan ini (jika ada) ikut terhapus.")
        }
    }

    private func row(_ c: Customer) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(text: c.name, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(c.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(((c.phone ?? "").isEmpty ? "Tanpa nomor telepon" : (c.phone ?? "")))
                    .font(.system(size: 12)).foregroundColor(Theme.muted)
                if let u = c.accountUsername {
                    Pill(text: "Akses: " + u + (c.accountIsActive ? "" : " (nonaktif)"), tint: c.accountIsActive ? Theme.green : Theme.muted)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.money(c.totalSpent ?? 0)).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                Text("\(Int(c.transactions ?? 0)) transaksi").font(.system(size: 11)).foregroundColor(Theme.muted)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: form pelanggan

struct CustomerForm: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    var customer: Customer?
    var onAccess: (Customer) -> Void
    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Data pelanggan") {
                    TextField("Nama pelanggan", text: $name)
                    TextField("Nomor telepon", text: $phone).keyboardType(.phonePad)
                    TextField("Alamat", text: $address)
                    TextField("Catatan", text: $notes)
                }
                .listRowBackground(Theme.card.opacity(0.85))

                if let c = customer {
                    Section("Akses login pelanggan") {
                        Button {
                            Fx.open()
                            onAccess(c)
                        } label: {
                            Label(c.hasAccount ? "Kelola akses (\(c.accountUsername ?? ""))" : "Buat akses login", systemImage: "key.fill")
                        }
                    }
                    .listRowBackground(Theme.card.opacity(0.85))
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle(customer == nil ? "Pelanggan baru" : "Edit pelanggan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
        .onAppear {
            if let c = customer {
                name = c.name
                phone = c.phone ?? ""
                address = c.address ?? ""
                notes = c.notes ?? ""
            }
        }
    }

    private func save() {
        saving = true
        Task { @MainActor in
            let ok = await app.saveCustomer(id: customer?.id, name: name.trimmingCharacters(in: .whitespaces), phone: phone, address: address, notes: notes)
            saving = false
            if ok { dismiss() }
        }
    }
}

// MARK: akses login pelanggan (dibuat oleh admin)

struct AccessSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    var customerId: Int
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var created: [String]? = nil   // [username, password]
    @State private var resetting = false
    @State private var confirmDelete = false

    private var customer: Customer? { return app.customers.first(where: { $0.id == customerId }) }

    private static func randomPassword() -> String {
        let chars = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }

    private func slug(_ name: String) -> String {
        let lower = name.lowercased()
        var out = ""
        var lastDot = false
        for ch in lower {
            if ch.isLetter || ch.isNumber, ch.isASCII {
                out.append(ch)
                lastDot = false
            } else if !lastDot && !out.isEmpty {
                out.append(".")
                lastDot = true
            }
        }
        while out.hasSuffix(".") { out.removeLast() }
        return out.isEmpty ? "pelanggan" : String(out.prefix(24))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let c = customer {
                        HStack(spacing: 12) {
                            AvatarCircle(text: c.name, size: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                Text("Akses login untuk melihat transaksi dan nota").font(.system(size: 12)).foregroundColor(Theme.muted)
                            }
                            Spacer()
                        }
                        if let cr = created {
                            credentialsCard(username: cr[0], password: cr[1])
                        } else if c.hasAccount {
                            manageCard(c)
                        } else {
                            createCard(c)
                        }
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Akses login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Selesai") { dismiss() } } }
            .onAppear {
                if let c = customer, !c.hasAccount {
                    username = slug(c.name)
                    password = AccessSheet.randomPassword()
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func createCard(_ c: Customer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Buat akun pelanggan", subtitle: "Satu pelanggan satu akun login.")
            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .fieldStyle()
            HStack(spacing: 8) {
                TextField("Password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .fieldStyle()
                Button {
                    Fx.tap()
                    password = AccessSheet.randomPassword()
                } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(SoftButtonStyle())
            }
            Text("Username 3 sampai 32 karakter: huruf, angka, titik, strip, atau underscore. Password minimal 6 karakter.")
                .font(.system(size: 11)).foregroundColor(Theme.muted)
            Button {
                busy = true
                Task { @MainActor in
                    let u = username.trimmingCharacters(in: .whitespaces)
                    let ok = await app.createAccount(customerId: c.id, username: u, password: password)
                    busy = false
                    if ok {
                        Fx.success()
                        created = [u, password]
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if busy { ProgressView().tint(.white) }
                    Text("Buat akun")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy || username.count < 3 || password.count < 6)
            .opacity(busy || username.count < 3 || password.count < 6 ? 0.5 : 1)
        }
        .glassCard()
    }

    private func manageCard(_ c: Customer) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "Username", subtitle: "Dipakai pelanggan untuk login")
                Spacer()
                Text(c.accountUsername ?? "").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            }
            HStack {
                SectionTitle(title: "Status", subtitle: "Akun nonaktif tidak bisa login")
                Spacer()
                Pill(text: c.accountIsActive ? "Aktif" : "Nonaktif", tint: c.accountIsActive ? Theme.green : Theme.muted)
            }
            Text("Password tidak bisa dilihat, hanya bisa direset.").font(.system(size: 12)).foregroundColor(Theme.muted)

            if resetting {
                HStack(spacing: 8) {
                    TextField("Password baru", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .fieldStyle()
                    Button {
                        Fx.tap()
                        password = AccessSheet.randomPassword()
                    } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(SoftButtonStyle())
                }
                Button {
                    guard let aid = c.accountId else { return }
                    busy = true
                    Task { @MainActor in
                        let ok = await app.patchAccount(id: aid, password: password, active: nil)
                        busy = false
                        if ok {
                            Fx.success()
                            created = [c.accountUsername ?? "", password]
                            resetting = false
                        }
                    }
                } label: { Text("Simpan password baru") }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy || password.count < 6)
            } else {
                Button {
                    Fx.open()
                    password = AccessSheet.randomPassword()
                    withAnimation { resetting = true }
                } label: { Label("Reset password", systemImage: "key.fill").frame(maxWidth: .infinity) }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue3))
            }

            HStack(spacing: 10) {
                Button {
                    guard let aid = c.accountId else { return }
                    Task { @MainActor in
                        let ok = await app.patchAccount(id: aid, password: nil, active: c.accountIsActive ? 0 : 1)
                        if ok { app.show(c.accountIsActive ? "Akun dinonaktifkan." : "Akun diaktifkan.") }
                    }
                } label: {
                    Label(c.accountIsActive ? "Nonaktifkan" : "Aktifkan", systemImage: c.accountIsActive ? "pause.circle" : "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
                Button { confirmDelete = true } label: {
                    Label("Hapus akun", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.red))
            }
        }
        .glassCard()
        .confirmationDialog("Hapus akun login?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Hapus akun", role: .destructive) {
                guard let aid = c.accountId else { return }
                Task { @MainActor in
                    if await app.deleteAccount(id: aid) {
                        app.show("Akun login dihapus.")
                        dismiss()
                    }
                }
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Data pelanggan dan transaksinya tetap tersimpan.")
        }
    }

    private func credentialsCard(username: String, password: String) -> some View {
        let store = app.settings?.name ?? "Kasir"
        let text = "Akses riwayat transaksi dan nota - \(store)\nAlamat: \(app.serverURL)\nUsername: \(username)\nPassword: \(password)"
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Kirim info ini ke pelanggan", subtitle: "Password tidak akan ditampilkan lagi (hanya bisa direset).")
            VStack(spacing: 8) {
                credRow("Alamat", app.serverURL)
                credRow("Username", username)
                credRow("Password", password)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.25)))
            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = text
                    app.show("Info login disalin.")
                } label: { Label("Salin", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue3))
                ShareLink(item: text) {
                    Label("Bagikan", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue3))
            }
        }
        .glassCard()
    }

    private func credRow(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).font(.system(size: 13)).foregroundColor(Theme.muted)
            Spacer()
            Text(v).font(.system(size: 14, weight: .semibold)).foregroundColor(.white).textSelection(.enabled)
        }
    }
}
