import SwiftUI

struct ProductCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct POSView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var showCart = false
    @State private var showManual = false
    @State private var receipt: Sale?

    private var filtered: [Product] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return app.products }
        return app.products.filter { $0.name.lowercased().contains(q) || ($0.sku ?? "").lowercased().contains(q) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScreenHeader(title: "Kasir", subtitle: "Ketuk produk untuk menambah ke keranjang") {
                    Button {
                        Fx.open()
                        showManual = true
                    } label: {
                        Label("Manual", systemImage: "plus")
                    }
                    .buttonStyle(SoftButtonStyle())
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.muted)
                    TextField("Cari produk", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .foregroundColor(Theme.text)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Theme.muted) }
                            .buttonStyle(.plain)
                    }
                }
                .fieldStyle()

                if filtered.isEmpty {
                    EmptyState(symbol: "shippingbox", text: app.products.isEmpty
                               ? "Belum ada produk. Tambahkan di Lainnya > Produk, atau pakai tombol Manual."
                               : "Produk tidak ditemukan.")
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(filtered) { p in
                            Button {
                                app.addToCart(p)
                            } label: {
                                productCard(p)
                            }
                            .buttonStyle(ProductCardStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await app.loadProducts() }
        .safeAreaInset(edge: .bottom) { cartBar }
        .sheet(isPresented: $showCart) {
            CartSheet(onDone: { sale in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { receipt = sale }
            })
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showManual) {
            ManualItemSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $receipt) { sale in ReceiptSheet(sale: sale) }
    }

    private func productCard(_ p: Product) -> some View {
        let inCart = app.cart.first(where: { $0.productId == p.id })?.qty ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.blue3)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.blue.opacity(0.15)))
                Spacer()
                if inCart > 0 {
                    Text("×" + Fmt.qty(inCart))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.primary))
                        .transition(.scale)
                }
            }
            Text(p.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 36, alignment: .topLeading)
            Text(Fmt.money(p.price)).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.blue3)
            Text("Stok " + Fmt.qty(p.stock ?? 0) + " " + (p.unit ?? "pcs"))
                .font(.system(size: 11)).foregroundColor((p.stock ?? 0) <= 0 ? Theme.red : Theme.muted)
        }
        .glassCard(padding: 12, radius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(inCart > 0 ? Theme.blue.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inCart)
    }

    @ViewBuilder
    private var cartBar: some View {
        if app.cartCount > 0 {
            Button {
                Fx.open()
                showCart = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .overlay(alignment: .topTrailing) {
                            Text("\(app.cartCount)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .frame(minWidth: 15, minHeight: 15)
                                .background(Capsule().fill(Theme.red))
                                .offset(x: 10, y: -8)
                        }
                    Text("Lihat keranjang").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(Fmt.money(app.cartTotal)).font(.system(size: 15, weight: .bold))
                    Image(systemName: "chevron.up").font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .frame(height: 54)
                .background(Capsule().fill(Theme.primary))
                .shadow(color: Theme.blue2.opacity(0.6), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: barang manual

struct ManualItemSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var price = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Barang manual").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            Text("Untuk barang yang belum ada di daftar produk.").font(.system(size: 13)).foregroundColor(Theme.muted)
            TextField("Nama barang", text: $name).fieldStyle()
            TextField("Harga (Rp)", text: $price).keyboardType(.numberPad).fieldStyle()
            Button {
                let p = digitsToDouble(price)
                let n = name.trimmingCharacters(in: .whitespaces)
                if n.isEmpty || p <= 0 {
                    app.show("Isi nama barang dan harga.", error: true)
                    return
                }
                app.addManual(name: n, price: p)
                dismiss()
            } label: {
                Text("Tambah ke keranjang")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 6)
            Spacer()
        }
        .padding(22)
        .background(AppBackground())
    }
}

// MARK: keranjang dan pembayaran

struct CartSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    var onDone: (Sale) -> Void
    @State private var discount = ""
    @State private var paid = ""
    @State private var note = ""
    @State private var customDate = false
    @State private var date = Date()
    @State private var saving = false

    private var discountValue: Double { return digitsToDouble(discount) }
    private var total: Double { return max(0, app.cartTotal - discountValue) }
    private var paidValue: Double { return digitsToDouble(paid) }
    private var canSave: Bool { return !app.cart.isEmpty && paidValue >= total && !saving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    itemsCard
                    customerCard
                    paymentCard
                    dateCard
                    TextField("Catatan transaksi (opsional)", text: $note).fieldStyle()
                }
                .padding(18)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Keranjang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Tutup") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Kosongkan") { Fx.tap(); app.clearCart(); dismiss() }.foregroundColor(Theme.red)
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
        }
        .onChange(of: app.cartCount) { c in
            if c == 0 && !saving { dismiss() }
        }
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Barang", subtitle: "\(app.cartCount) jenis barang")
            ForEach(app.cart) { line in
                VStack(spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            Text(Fmt.money(line.price) + " × " + Fmt.qty(line.qty) + " " + line.unit)
                                .font(.system(size: 12)).foregroundColor(Theme.muted)
                        }
                        Spacer()
                        Text(Fmt.money(line.total)).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                    HStack(spacing: 10) {
                        stepButton("minus") { app.changeQty(line, by: -1) }
                        Text(Fmt.qty(line.qty)).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(minWidth: 28)
                        stepButton("plus") { app.changeQty(line, by: 1) }
                        Spacer()
                        Button { app.removeLine(line) } label: {
                            Image(systemName: "trash").font(.system(size: 14)).foregroundColor(Theme.red)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Theme.red.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
                if line.id != app.cart.last?.id { Divider().overlay(Theme.line) }
            }
        }
        .glassCard()
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var customerCard: some View {
        HStack {
            Image(systemName: "person.crop.circle").foregroundColor(Theme.blue3)
            Text("Pelanggan").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Picker("Pelanggan", selection: $app.cartCustomerId) {
                Text("Pelanggan umum").tag(Int?.none)
                ForEach(app.customers) { c in
                    Text(c.name).tag(Int?.some(c.id))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.blue3)
        }
        .glassCard(padding: 14)
    }

    private var paymentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Pembayaran")
            TextField("Diskon (Rp)", text: $discount).keyboardType(.numberPad).fieldStyle()
            HStack { Text("Subtotal").foregroundColor(Theme.muted); Spacer(); Text(Fmt.money(app.cartTotal)).foregroundColor(.white) }
                .font(.system(size: 14))
            HStack { Text("Diskon").foregroundColor(Theme.muted); Spacer(); Text("- " + Fmt.money(discountValue)).foregroundColor(.white) }
                .font(.system(size: 14))
            Divider().overlay(Theme.line)
            HStack {
                Text("Total").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Text(Fmt.money(total)).font(.system(size: 22, weight: .bold)).foregroundColor(Theme.blue3)
            }
            TextField("Uang diterima (Rp)", text: $paid).keyboardType(.numberPad).fieldStyle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(quickAmounts().enumerated()), id: \.offset) { index, v in
                        Button {
                            Fx.tap()
                            paid = String(Int(v))
                        } label: {
                            Text(index == 0 ? "Uang pas" : Fmt.money(v))
                        }
                        .buttonStyle(SoftButtonStyle(tint: Theme.blue3))
                    }
                }
            }
            HStack {
                Text("Kembalian").foregroundColor(Theme.muted)
                Spacer()
                Text(Fmt.money(max(0, paidValue - total))).foregroundColor(Theme.green).fontWeight(.semibold)
            }
            .font(.system(size: 14))
        }
        .glassCard()
    }

    private func quickAmounts() -> [Double] {
        let t = total
        if t <= 0 { return [] }
        var out: [Double] = [t]
        for step in [10000.0, 50000.0, 100000.0] {
            let v = (t / step).rounded(.up) * step
            if !out.contains(v) { out.append(v) }
        }
        return out
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $customDate.animation()) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Atur tanggal dan jam").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Text(customDate ? "Transaksi dicatat pada waktu pilihan Anda." : "Otomatis memakai waktu saat disimpan.")
                        .font(.system(size: 12)).foregroundColor(Theme.muted)
                }
            }
            .tint(Theme.blue)
            if customDate {
                DatePicker("Waktu transaksi", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .tint(Theme.blue3)
                    .foregroundColor(.white)
            }
        }
        .glassCard(padding: 14)
    }

    private var saveBar: some View {
        VStack(spacing: 6) {
            if paidValue < total {
                Text("Uang diterima masih kurang dari total.").font(.system(size: 12)).foregroundColor(Theme.amber)
            }
            Button {
                save()
            } label: {
                HStack(spacing: 8) {
                    if saving { ProgressView().tint(.white) } else { Image(systemName: "checkmark") }
                    Text("Simpan transaksi · " + Fmt.money(total))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func save() {
        saving = true
        Task { @MainActor in
            let sale = await app.checkout(customerId: app.cartCustomerId, discount: discountValue, paid: paidValue, note: note, date: customDate ? date : nil)
            saving = false
            if let s = sale {
                dismiss()
                onDone(s)
            }
        }
    }
}
