import SwiftUI
import LocalAuthentication

enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard, kasir, riwayat, pelanggan, lainnya
    var id: Int { return rawValue }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var isError: Bool
}

struct CartLine: Identifiable, Equatable {
    var id = UUID()
    var productId: Int?
    var name: String
    var price: Double
    var qty: Double
    var unit: String
    var total: Double { return price * qty }
}

@MainActor
final class AppState: ObservableObject {
    @Published var booting = true
    @Published var me: Me?
    @Published var serverURL: String = UserDefaults.standard.string(forKey: "serverURL") ?? "https://neo.tail5bf676.ts.net"
    @Published var tab: AppTab = .dashboard
    @Published var toast: Toast?
    @Published var isLocked = false
    @Published var online = true
    @Published var customers: [Customer] = []
    @Published var products: [Product] = []
    @Published var sales: [Sale] = []
    @Published var settings: StoreSettings?
    @Published var cart: [CartLine] = []
    @Published var cartCustomerId: Int? = nil
    @Published var biometricLock: Bool = UserDefaults.standard.bool(forKey: "biometricLock") {
        didSet { UserDefaults.standard.set(biometricLock, forKey: "biometricLock") }
    }

    let api = APIClient.shared
    private var heartbeat: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    var isAdmin: Bool { return me?.isAdmin ?? false }
    var cartCount: Int { return cart.count }
    var cartTotal: Double { return cart.reduce(0) { $0 + $1.total } }

    // MARK: pesan singkat (toast)

    func show(_ message: String, error: Bool = false, quiet: Bool = false) {
        toast = Toast(message: message, isError: error)
        if !quiet { if error { Fx.error() } else { Fx.success() } }
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: error ? 4_200_000_000 : 2_800_000_000)
            if Task.isCancelled { return }
            await MainActor.run { self?.toast = nil }
        }
    }

    func message(for error: Error) -> String {
        if let e = error as? APIFailure { return e.message }
        return error.localizedDescription
    }

    func report(_ error: Error) {
        if let e = error as? APIFailure, e.unauthorized { return }
        show(message(for: error), error: true)
    }

    // MARK: alamat server & sesi

    func applyServer(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") { s = "https://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        serverURL = s
        UserDefaults.standard.set(s, forKey: "serverURL")
        api.baseURL = URL(string: s)
    }

    func bootstrap() async {
        applyServer(serverURL)
        api.onUnauthorized = { [weak self] in
            Task { @MainActor in self?.sessionEnded() }
        }
        if let t = Keychain.get("token") {
            api.token = t
            do {
                let m: Me = try await api.get("/me")
                if (m.v ?? 0) < 3 { throw APIFailure(message: "Server masih versi lama.") }
                me = m
                if biometricLock { isLocked = true }
                startHeartbeat()
                await refreshAll()
            } catch {
                api.token = nil
                Keychain.remove("token")
            }
        }
        booting = false
    }

    func login(username: String, password: String, server: String) async throws {
        applyServer(server)
        let r: LoginResponse = try await api.send("POST", "/login", body: LoginBody(username: username, password: password))
        if (r.v ?? 0) < 3 {
            throw APIFailure(message: "Server masih versi lama. Perbarui server ke versi terbaru dan nyalakan ulang, lalu coba lagi.")
        }
        api.token = r.token
        Keychain.set(r.token, for: "token")
        me = Me(v: r.v, username: r.username, role: r.role, name: r.name, customerId: r.customerId, mustChange: r.mustChange)
        tab = .dashboard
        Fx.login()
        startHeartbeat()
        await refreshAll()
    }

    func logout() async {
        try? await api.post("/logout")
        clearSession()
    }

    private func clearSession() {
        api.token = nil
        Keychain.remove("token")
        heartbeat?.cancel()
        me = nil
        customers = []
        products = []
        sales = []
        settings = nil
        cart = []
        cartCustomerId = nil
        isLocked = false
        tab = .dashboard
    }

    func sessionEnded() {
        if me != nil {
            clearSession()
            show("Sesi berakhir. Silakan login kembali.", error: true)
        }
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        if phase == .background && me != nil && biometricLock { isLocked = true }
        if phase == .active && me != nil { Task { await ping() } }
    }

    func unlock() async {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            isLocked = false
            return
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Buka aplikasi kasir")
            if ok { isLocked = false; Fx.tap() }
        } catch {
            // dibatalkan pengguna: tetap terkunci
        }
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if Task.isCancelled { break }
                await self?.ping()
            }
        }
    }

    func ping() async {
        do {
            let _: Me = try await api.get("/me")
            online = true
        } catch let e as APIFailure {
            if !e.unauthorized { online = false }
        } catch {
            online = false
        }
    }

    // MARK: memuat data

    func refreshAll() async {
        if isAdmin {
            await loadSettings()
            await loadCustomers()
            await loadProducts()
        } else {
            await loadSettings()
        }
        await loadSales()
    }

    func loadSettings() async {
        do { settings = try await api.get("/settings") } catch { report(error) }
    }

    func loadCustomers() async {
        guard isAdmin else { return }
        do { customers = try await api.get("/customers") } catch { report(error) }
    }

    func loadProducts() async {
        guard isAdmin else { return }
        do { products = try await api.get("/products") } catch { report(error) }
    }

    func loadSales() async {
        do {
            if isAdmin { sales = try await api.get("/sales") } else { sales = try await api.get("/my/sales") }
        } catch { report(error) }
    }

    func summary(days: Int) async -> Summary? {
        do { return try await api.get("/summary", query: [URLQueryItem(name: "days", value: String(days))]) }
        catch { report(error); return nil }
    }

    func fetchSale(id: Int) async -> Sale? {
        do { return try await api.get(isAdmin ? "/sales/\(id)" : "/my/sales/\(id)") }
        catch { report(error); return nil }
    }

    // MARK: keranjang

    func addToCart(_ p: Product) {
        if let i = cart.firstIndex(where: { $0.productId == p.id }) {
            cart[i].qty += 1
        } else {
            cart.append(CartLine(productId: p.id, name: p.name, price: p.price, qty: 1, unit: p.unit ?? "pcs"))
        }
        Fx.pop()
    }

    func addManual(name: String, price: Double) {
        cart.append(CartLine(productId: nil, name: name, price: price, qty: 1, unit: "pcs"))
        Fx.pop()
    }

    func changeQty(_ line: CartLine, by delta: Double) {
        guard let i = cart.firstIndex(where: { $0.id == line.id }) else { return }
        let q = cart[i].qty + delta
        if q <= 0 { cart.remove(at: i) } else { cart[i].qty = q }
        Fx.tap()
    }

    func removeLine(_ line: CartLine) {
        cart.removeAll { $0.id == line.id }
        Fx.tap()
    }

    func clearCart() {
        cart = []
        cartCustomerId = nil
    }

    func checkout(customerId: Int?, discount: Double, paid: Double, note: String, date: Date?) async -> Sale? {
        let items = cart.map { SaleItem(productId: $0.productId, name: $0.name, price: $0.price, qty: $0.qty, unit: $0.unit) }
        let body = SaleBody(customerId: customerId, items: items, discount: discount, paid: paid, note: note, date: date.map { Fmt.iso($0) })
        do {
            let created: CreatedSale = try await api.send("POST", "/sales", body: body)
            let sale: Sale = try await api.get("/sales/\(created.id)")
            clearCart()
            Fx.cash()
            show("Transaksi tersimpan: \(created.invoice)", quiet: true)
            await loadSales()
            await loadProducts()
            return sale
        } catch {
            report(error)
            return nil
        }
    }

    func updateSale(id: Int, body: SaleBody) async -> Bool {
        do {
            try await api.sendIgnoringResult("PUT", "/sales/\(id)", body: body)
            await loadSales()
            await loadProducts()
            show("Perubahan transaksi tersimpan.")
            return true
        } catch { report(error); return false }
    }

    func deleteSale(id: Int) async -> Bool {
        do {
            try await api.delete("/sales/\(id)")
            await loadSales()
            await loadProducts()
            show("Transaksi dihapus.")
            return true
        } catch { report(error); return false }
    }

    // MARK: pelanggan, produk, akun

    func saveCustomer(id: Int?, name: String, phone: String, address: String, notes: String) async -> Bool {
        let body = CustomerBody(name: name, phone: phone, address: address, notes: notes)
        do {
            if let id = id { try await api.sendIgnoringResult("PUT", "/customers/\(id)", body: body) }
            else { try await api.sendIgnoringResult("POST", "/customers", body: body) }
            await loadCustomers()
            show(id == nil ? "Pelanggan ditambahkan." : "Pelanggan diperbarui.")
            return true
        } catch { report(error); return false }
    }

    func deleteCustomer(id: Int) async -> Bool {
        do {
            try await api.delete("/customers/\(id)")
            await loadCustomers()
            await loadSales()
            show("Pelanggan dihapus.")
            return true
        } catch { report(error); return false }
    }

    func saveProduct(id: Int?, name: String, price: Double, sku: String, stock: Double, unit: String) async -> Bool {
        let body = ProductBody(name: name, price: price, sku: sku, stock: stock, unit: unit)
        do {
            if let id = id { try await api.sendIgnoringResult("PUT", "/products/\(id)", body: body) }
            else { try await api.sendIgnoringResult("POST", "/products", body: body) }
            await loadProducts()
            show(id == nil ? "Produk ditambahkan." : "Produk diperbarui.")
            return true
        } catch { report(error); return false }
    }

    func deleteProduct(id: Int) async -> Bool {
        do {
            try await api.delete("/products/\(id)")
            await loadProducts()
            show("Produk dihapus.")
            return true
        } catch { report(error); return false }
    }

    func loadUsers() async -> [UserAccount] {
        do { return try await api.get("/users") } catch { report(error); return [] }
    }

    func createAccount(customerId: Int, username: String, password: String) async -> Bool {
        do {
            let _: CreatedUser = try await api.send("POST", "/users", body: NewUserBody(customerId: customerId, username: username, password: password))
            await loadCustomers()
            return true
        } catch { report(error); return false }
    }

    func patchAccount(id: Int, password: String?, active: Int?) async -> Bool {
        do {
            try await api.sendIgnoringResult("PUT", "/users/\(id)", body: UserPatchBody(password: password, active: active))
            await loadCustomers()
            return true
        } catch { report(error); return false }
    }

    func deleteAccount(id: Int) async -> Bool {
        do {
            try await api.delete("/users/\(id)")
            await loadCustomers()
            return true
        } catch { report(error); return false }
    }

    func saveSettings(_ body: SettingsBody) async -> Bool {
        do {
            try await api.sendIgnoringResult("PUT", "/settings", body: body)
            await loadSettings()
            show("Pengaturan tersimpan.")
            return true
        } catch { report(error); return false }
    }

    func changePassword(current: String, next: String) async -> Bool {
        do {
            try await api.sendIgnoringResult("POST", "/password", body: PasswordBody(current: current, next: next))
            if var m = me { m.mustChange = false; me = m }
            show("Password berhasil diganti.")
            return true
        } catch { report(error); return false }
    }

    // MARK: backup

    func exportBackup() async -> URL? {
        do {
            let data = try await api.data("GET", "/export")
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("kasir-backup-\(f.string(from: Date())).json")
            try data.write(to: url, options: .atomic)
            return url
        } catch { report(error); return nil }
    }

    func importBackup(_ data: Data, dry: Bool) async -> ImportResult? {
        do { return try await api.importBackup(data, dry: dry) }
        catch { report(error); return nil }
    }
}
