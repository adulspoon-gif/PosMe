import Foundation

// Model data. Nama properti mengikuti JSON server (snake_case diubah otomatis ke camelCase).
// Semua angka memakai Double supaya aman terhadap angka desimal dari server.

struct Me: Decodable {
    var v: Int?
    var username: String
    var role: String
    var name: String
    var customerId: Int?
    var mustChange: Bool?
    var isAdmin: Bool { return role == "admin" }
}

struct LoginResponse: Decodable {
    var v: Int?
    var token: String
    var username: String
    var role: String
    var name: String
    var customerId: Int?
    var mustChange: Bool?
}

struct CountOmzet: Decodable {
    var count: Double
    var omzet: Double
}

struct RecentSale: Decodable, Identifiable {
    var id: Int
    var invoice: String
    var customerName: String?
    var date: String
    var total: Double
}

struct PeriodInfo: Decodable {
    var days: Int
    var count: Double
    var omzet: Double
    var discount: Double
    var avg: Double
}

struct DayPoint: Decodable, Identifiable {
    var day: String
    var count: Double
    var omzet: Double
    var id: String { return day }
}

struct TopProduct: Decodable, Identifiable {
    var name: String
    var qty: Double
    var omzet: Double
    var id: String { return name }
}

struct TopCustomer: Decodable, Identifiable {
    var name: String
    var count: Double
    var omzet: Double
    var id: String { return name }
}

struct Summary: Decodable {
    var today: CountOmzet
    var all: CountOmzet
    var customers: Int
    var products: Int
    var recent: [RecentSale]
    var period: PeriodInfo
    var daily: [DayPoint]
    var top: [TopProduct]
    var topCustomers: [TopCustomer]
}

struct Customer: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String
    var phone: String?
    var address: String?
    var notes: String?
    var createdAt: String?
    var transactions: Double?
    var totalSpent: Double?
    var accountId: Int?
    var accountUsername: String?
    var accountActive: Int?
    var hasAccount: Bool { return accountId != nil }
    var accountIsActive: Bool { return (accountActive ?? 0) != 0 }
}

struct Product: Decodable, Identifiable, Hashable {
    var id: Int
    var name: String
    var price: Double
    var sku: String?
    var stock: Double?
    var unit: String?
    var createdAt: String?
    var updatedAt: String?
}

struct SaleItem: Codable, Identifiable, Hashable {
    var productId: Int?
    var name: String
    var price: Double
    var qty: Double
    var unit: String?
    var id: String { return name + "|" + String(price) + "|" + String(qty) + "|" + String(productId ?? 0) }
    var lineTotal: Double { return price * qty }
}

struct Sale: Decodable, Identifiable, Hashable {
    var id: Int
    var invoice: String
    var customerId: Int?
    var customerName: String?
    var date: String
    var subtotal: Double
    var discount: Double
    var total: Double
    var paid: Double
    var changeDue: Double
    var note: String?
    var items: [SaleItem]
}

struct StoreSettings: Decodable {
    var name: String
    var subtitle: String?
    var address: String?
    var phone: String?
    var storeNo: String?
    var footer: String?
    var policy: String?
}

struct UserAccount: Decodable, Identifiable, Hashable {
    var id: Int
    var username: String
    var role: String
    var customerId: Int?
    var active: Int
    var lastLogin: String?
    var createdAt: String?
    var customerName: String?
    var customerPhone: String?
    var isActive: Bool { return active != 0 }
}

struct ImportPart: Decodable {
    var file: Int
    var added: Int
    var skipped: Int
    var invalid: Int?
}

struct ImportStats: Decodable {
    var customers: ImportPart
    var products: ImportPart
    var sales: ImportPart
}

struct ImportResult: Decodable {
    var dry: Bool
    var stats: ImportStats
    var safetyBackup: String?
}

struct CreatedSale: Decodable {
    var id: Int
    var invoice: String
}

struct OkResponse: Decodable {
    var ok: Bool?
}

struct CreatedUser: Decodable {
    var id: Int
    var username: String
}

// ===== Isi permintaan (dikirim ke server) =====

struct LoginBody: Encodable {
    var username: String
    var password: String
}

struct PasswordBody: Encodable {
    var current: String
    var next: String
}

struct SaleBody: Encodable {
    var customerId: Int?
    var items: [SaleItem]
    var discount: Double
    var paid: Double
    var note: String
    var date: String?
}

struct CustomerBody: Encodable {
    var name: String
    var phone: String
    var address: String
    var notes: String
}

struct ProductBody: Encodable {
    var name: String
    var price: Double
    var sku: String
    var stock: Double
    var unit: String
}

struct SettingsBody: Encodable {
    var name: String
    var subtitle: String
    var address: String
    var phone: String
    var storeNo: String
    var footer: String
    var policy: String

    enum CodingKeys: String, CodingKey {
        case name, subtitle, address, phone, footer, policy
        case storeNo = "store_no"
    }
}

struct NewUserBody: Encodable {
    var customerId: Int
    var username: String
    var password: String
}

struct UserPatchBody: Encodable {
    var password: String?
    var active: Int?
}

extension Sale {
    var customerLabel: String {
        let n = customerName ?? ""
        return n.isEmpty ? "Pelanggan umum" : n
    }
}

extension RecentSale {
    var customerLabel: String {
        let n = customerName ?? ""
        return n.isEmpty ? "Pelanggan umum" : n
    }
}
