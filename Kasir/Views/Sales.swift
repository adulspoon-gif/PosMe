import SwiftUI

struct DayGroup: Identifiable {
    var key: String
    var sales: [Sale]
    var id: String { return key }
}

struct SalesView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var detail: Sale?
    @State private var editing: Sale?
    @State private var deleting: Sale?
    @State private var showDelete = false

    private var groups: [DayGroup] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        let list = q.isEmpty ? app.sales : app.sales.filter {
            $0.invoice.lowercased().contains(q) || ($0.customerName ?? "").lowercased().contains(q)
        }
        var order: [String] = []
        var dict: [String: [Sale]] = [:]
        for s in list {
            let k = Fmt.dayKey(s.date)
            if dict[k] == nil { order.append(k); dict[k] = [] }
            dict[k]?.append(s)
        }
        return order.map { DayGroup(key: $0, sales: dict[$0] ?? []) }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                EmptyState(symbol: "doc.text", text: query.isEmpty ? "Belum ada transaksi." : "Transaksi tidak ditemukan.")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(groups) { g in
                Section {
                    ForEach(g.sales) { s in
                        Button {
                            Fx.open()
                            detail = s
                        } label: {
                            SaleRow(sale: s)
                        }
                        .listRowBackground(Theme.card.opacity(0.85))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if app.isAdmin {
                                Button(role: .destructive) {
                                    deleting = s
                                    showDelete = true
                                } label: { Label("Hapus", systemImage: "trash") }
                                Button {
                                    editing = s
                                } label: { Label("Edit", systemImage: "pencil") }
                                .tint(Theme.blue)
                            }
                        }
                    }
                } header: {
                    Text(Fmt.dayTitle(g.sales.first?.date ?? ""))
                        .foregroundColor(Theme.muted)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Riwayat")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(text: $query, prompt: "Cari nomor nota atau pelanggan")
        .refreshable { await app.loadSales() }
        .sheet(item: $detail) { sale in ReceiptSheet(sale: sale) }
        .sheet(item: $editing) { sale in EditSaleSheet(sale: sale, onSaved: { _ in }) }
        .confirmationDialog("Hapus transaksi?", isPresented: $showDelete, titleVisibility: .visible, presenting: deleting) { s in
            Button("Hapus nota " + s.invoice, role: .destructive) {
                Task { @MainActor in _ = await app.deleteSale(id: s.id) }
            }
            Button("Batal", role: .cancel) {}
        } message: { s in
            Text("Stok barang pada nota ini akan dikembalikan. Tindakan ini tidak bisa dibatalkan.")
        }
    }
}

// MARK: nota (kertas putih seperti struk)

struct ReceiptCard: View {
    var sale: Sale
    var store: StoreSettings?

    private func dashed() -> some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .foregroundColor(Color(red: 0.58, green: 0.64, blue: 0.72))
            .frame(height: 1)
    }

    private func row(_ l: String, _ r: String, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(l)
            Spacer(minLength: 10)
            Text(r).fontWeight(bold ? .bold : .regular).multilineTextAlignment(.trailing)
        }
        .font(.system(size: 13))
    }

    var body: some View {
        let ink = Color(red: 0.07, green: 0.09, blue: 0.15)
        let soft = Color(red: 0.2, green: 0.25, blue: 0.33)
        let policy = ReceiptText.policy(store)
        return VStack(spacing: 8) {
            Text(store?.name ?? "Kasir Pribadi").font(.system(size: 18, weight: .bold)).foregroundColor(ink)
            if let t = store?.subtitle, !t.isEmpty { Text(t).font(.system(size: 12)).foregroundColor(soft) }
            if let t = store?.address, !t.isEmpty { Text(t).font(.system(size: 12)).foregroundColor(soft).multilineTextAlignment(.center) }
            if let t = store?.phone, !t.isEmpty { Text("Telp: " + t).font(.system(size: 12)).foregroundColor(soft) }
            dashed()
            VStack(spacing: 3) {
                row("No. Nota", sale.invoice, bold: true)
                row("Tanggal", Fmt.dateTime(sale.date))
                row("Pelanggan", sale.customerLabel)
            }
            dashed()
            VStack(spacing: 6) {
                ForEach(sale.items) { i in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(i.name).font(.system(size: 13))
                        row(Fmt.qty(i.qty) + " × " + Fmt.money(i.price), Fmt.money(i.lineTotal), bold: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            dashed()
            VStack(spacing: 3) {
                row("Subtotal", Fmt.money(sale.subtotal), bold: true)
                row("Diskon", Fmt.money(sale.discount), bold: true)
            }
            VStack(spacing: 0) {
                Rectangle().fill(ink).frame(height: 1)
                HStack {
                    Text("TOTAL").font(.system(size: 16, weight: .heavy))
                    Spacer()
                    Text(Fmt.money(sale.total)).font(.system(size: 17, weight: .heavy))
                }
                .padding(.vertical, 6)
                Rectangle().fill(ink).frame(height: 1)
            }
            VStack(spacing: 3) {
                row("Dibayar", Fmt.money(sale.paid))
                row("Kembalian", Fmt.money(sale.changeDue))
            }
            if let n = sale.note, !n.isEmpty {
                dashed()
                Text("Catatan: " + n).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
            }
            dashed()
            if !policy.isEmpty {
                Text(policy).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.center).padding(.top, 2)
            }
            Text(ReceiptText.thanks(store)).font(.system(size: 12, weight: .bold)).multilineTextAlignment(.center)
        }
        .foregroundColor(ink)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 10)
    }
}

struct ReceiptSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var sale: Sale
    @State private var editing: Sale?
    @State private var showDelete = false

    init(sale: Sale) {
        _sale = State(initialValue: sale)
    }

    private var text: String { return ReceiptText.build(sale, store: app.settings) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ReceiptCard(sale: sale, store: app.settings)
                        .frame(maxWidth: 380)
                    actions
                }
                .padding(18)
                .frame(maxWidth: .infinity)
            }
            .background(AppBackground())
            .navigationTitle("Detail transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Selesai") { dismiss() } }
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(item: $editing) { s in
            EditSaleSheet(sale: s, onSaved: { updated in sale = updated })
        }
        .confirmationDialog("Hapus transaksi ini?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Hapus nota " + sale.invoice, role: .destructive) {
                Task { @MainActor in
                    if await app.deleteSale(id: sale.id) { dismiss() }
                }
            }
            Button("Batal", role: .cancel) {}
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ShareLink(item: text, subject: Text("Nota " + sale.invoice)) {
                    Label("Bagikan", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue3))
                Button {
                    Fx.tap()
                    PrintHelper.printText(text, jobName: "Nota " + sale.invoice)
                } label: {
                    Label("Cetak", systemImage: "printer").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.blue3))
            }
            if app.isAdmin {
                HStack(spacing: 10) {
                    Button {
                        Fx.open()
                        editing = sale
                    } label: {
                        Label("Edit transaksi", systemImage: "pencil").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle())
                    Button {
                        showDelete = true
                    } label: {
                        Label("Hapus", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.red))
                }
            }
        }
        .frame(maxWidth: 380)
    }
}

// MARK: edit transaksi (tanggal, jam, barang, pembayaran)

struct EditItem: Identifiable {
    var id = UUID()
    var productId: Int?
    var name: String
    var price: String
    var qty: String
    var unit: String
}

struct EditSaleSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    var sale: Sale
    var onSaved: (Sale) -> Void
    @State private var date: Date
    @State private var customerId: Int?
    @State private var items: [EditItem]
    @State private var discount: String
    @State private var paid: String
    @State private var note: String
    @State private var saving = false

    init(sale: Sale, onSaved: @escaping (Sale) -> Void) {
        self.sale = sale
        self.onSaved = onSaved
        _date = State(initialValue: Fmt.parse(sale.date) ?? Date())
        _customerId = State(initialValue: sale.customerId)
        _items = State(initialValue: sale.items.map {
            EditItem(productId: $0.productId, name: $0.name, price: String(Int($0.price.rounded())), qty: Fmt.qty($0.qty).replacingOccurrences(of: ",", with: "."), unit: $0.unit ?? "pcs")
        })
        _discount = State(initialValue: String(Int(sale.discount.rounded())))
        _paid = State(initialValue: String(Int(sale.paid.rounded())))
        _note = State(initialValue: sale.note ?? "")
    }

    private func qtyValue(_ s: String) -> Double {
        return Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var subtotal: Double {
        return items.reduce(0) { $0 + digitsToDouble($1.price) * qtyValue($1.qty) }
    }
    private var total: Double { return max(0, subtotal - digitsToDouble(discount)) }
    private var canSave: Bool {
        return !items.isEmpty && !saving && digitsToDouble(paid) >= total
            && items.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && qtyValue($0.qty) > 0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Waktu transaksi") {
                    DatePicker("Tanggal dan jam", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .tint(Theme.blue3)
                }
                .listRowBackground(Theme.card.opacity(0.85))

                Section("Pelanggan") {
                    Picker("Pelanggan", selection: $customerId) {
                        Text("Pelanggan umum").tag(Int?.none)
                        ForEach(app.customers) { c in Text(c.name).tag(Int?.some(c.id)) }
                    }
                    .tint(Theme.blue3)
                }
                .listRowBackground(Theme.card.opacity(0.85))

                Section("Barang") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Nama barang", text: $item.name)
                            HStack {
                                TextField("Harga", text: $item.price).keyboardType(.numberPad)
                                TextField("Jumlah", text: $item.qty).keyboardType(.decimalPad)
                                TextField("Satuan", text: $item.unit)
                            }
                            .font(.system(size: 14))
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in items.remove(atOffsets: offsets) }
                    Button {
                        items.append(EditItem(productId: nil, name: "", price: "", qty: "1", unit: "pcs"))
                    } label: {
                        Label("Tambah barang", systemImage: "plus.circle.fill")
                    }
                }
                .listRowBackground(Theme.card.opacity(0.85))

                Section("Pembayaran") {
                    TextField("Diskon (Rp)", text: $discount).keyboardType(.numberPad)
                    TextField("Dibayar (Rp)", text: $paid).keyboardType(.numberPad)
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(Fmt.money(total)).fontWeight(.bold).foregroundColor(Theme.blue3)
                    }
                    TextField("Catatan", text: $note)
                }
                .listRowBackground(Theme.card.opacity(0.85))
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Edit " + sale.invoice)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { saving ? AnyView(ProgressView()) : AnyView(Text("Simpan").fontWeight(.bold)) }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        saving = true
        let lines = items.map {
            SaleItem(productId: $0.productId, name: $0.name.trimmingCharacters(in: .whitespaces), price: digitsToDouble($0.price), qty: qtyValue($0.qty), unit: $0.unit)
        }
        let body = SaleBody(customerId: customerId, items: lines, discount: digitsToDouble(discount), paid: digitsToDouble(paid), note: note, date: Fmt.iso(date))
        Task { @MainActor in
            let ok = await app.updateSale(id: sale.id, body: body)
            saving = false
            if ok {
                if let fresh = await app.fetchSale(id: sale.id) { onSaved(fresh) }
                dismiss()
            }
        }
    }
}
