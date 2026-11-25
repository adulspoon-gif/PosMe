import SwiftUI

struct ProductEdit: Identifiable {
    var product: Product?
    var id: String { return product.map { String($0.id) } ?? "baru" }
}

struct ProductsView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var editing: ProductEdit?
    @State private var deleting: Product?
    @State private var showDelete = false

    private var filtered: [Product] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return app.products }
        return app.products.filter { $0.name.lowercased().contains(q) || ($0.sku ?? "").lowercased().contains(q) }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                EmptyState(symbol: "shippingbox", text: query.isEmpty ? "Belum ada produk. Ketuk + untuk menambah." : "Produk tidak ditemukan.")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(filtered) { p in
                Button {
                    Fx.open()
                    editing = ProductEdit(product: p)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.violet)
                            .frame(width: 38, height: 38)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.violet.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            Text((p.sku ?? "").isEmpty ? "Tanpa SKU" : "SKU " + (p.sku ?? ""))
                                .font(.system(size: 12)).foregroundColor(Theme.muted)
                        }
                        Spacer(minLength: 6)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(Fmt.money(p.price)).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            Text("Stok " + Fmt.qty(p.stock ?? 0) + " " + (p.unit ?? "pcs"))
                                .font(.system(size: 11)).foregroundColor((p.stock ?? 0) <= 0 ? Theme.red : Theme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Theme.card.opacity(0.85))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleting = p
                        showDelete = true
                    } label: { Label("Hapus", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Produk")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(text: $query, prompt: "Cari nama atau SKU")
        .refreshable { await app.loadProducts() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Fx.open()
                    editing = ProductEdit(product: nil)
                } label: { Image(systemName: "plus.circle.fill").font(.system(size: 20)) }
            }
        }
        .sheet(item: $editing) { e in ProductForm(product: e.product) }
        .confirmationDialog("Hapus produk?", isPresented: $showDelete, titleVisibility: .visible, presenting: deleting) { p in
            Button("Hapus " + p.name, role: .destructive) {
                Task { @MainActor in _ = await app.deleteProduct(id: p.id) }
            }
            Button("Batal", role: .cancel) {}
        } message: { p in
            Text("Transaksi lama yang memuat produk ini tetap tersimpan.")
        }
    }
}

struct ProductForm: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    var product: Product?
    @State private var name = ""
    @State private var price = ""
    @State private var sku = ""
    @State private var stock = ""
    @State private var unit = "pcs"
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Data produk") {
                    TextField("Nama produk", text: $name)
                    TextField("Harga (Rp)", text: $price).keyboardType(.numberPad)
                    TextField("SKU (opsional)", text: $sku)
                }
                .listRowBackground(Theme.card.opacity(0.85))
                Section("Stok") {
                    TextField("Jumlah stok", text: $stock).keyboardType(.decimalPad)
                    TextField("Satuan (pcs, kg, m, dll)", text: $unit)
                }
                .listRowBackground(Theme.card.opacity(0.85))
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle(product == nil ? "Produk baru" : "Edit produk")
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
            if let p = product {
                name = p.name
                price = String(Int(p.price.rounded()))
                sku = p.sku ?? ""
                stock = Fmt.qty(p.stock ?? 0).replacingOccurrences(of: ",", with: ".")
                unit = p.unit ?? "pcs"
            }
        }
    }

    private func save() {
        saving = true
        let st = Double(stock.replacingOccurrences(of: ",", with: ".")) ?? 0
        Task { @MainActor in
            let ok = await app.saveProduct(id: product?.id, name: name.trimmingCharacters(in: .whitespaces), price: digitsToDouble(price), sku: sku, stock: st, unit: unit.isEmpty ? "pcs" : unit)
            saving = false
            if ok { dismiss() }
        }
    }
}
