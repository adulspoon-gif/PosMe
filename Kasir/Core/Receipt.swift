import UIKit

/// Teks nota (untuk dibagikan/dicetak) dan pencetakan AirPrint.
enum ReceiptText {
    static let defaultPolicy = "Barang yang sudah dibeli tidak bisa ditukar / dikembalikan"
    static let defaultThanks = "Terimakasih atas kunjungan anda"

    static func policy(_ s: StoreSettings?) -> String {
        guard let s = s else { return defaultPolicy }
        return s.policy ?? ""
    }

    static func thanks(_ s: StoreSettings?) -> String {
        let t = s?.footer ?? ""
        return t.isEmpty ? defaultThanks : t
    }

    static func build(_ sale: Sale, store: StoreSettings?) -> String {
        let line = "--------------------------------"
        var L: [String] = []
        L.append(store?.name ?? "Kasir Pribadi")
        if let t = store?.subtitle, !t.isEmpty { L.append(t) }
        if let t = store?.address, !t.isEmpty { L.append(t) }
        if let t = store?.phone, !t.isEmpty { L.append("Telp: " + t) }
        L.append(line)
        L.append("No. Nota: " + sale.invoice)
        L.append("Tanggal: " + Fmt.dateTime(sale.date))
        L.append("Pelanggan: " + sale.customerLabel)
        L.append(line)
        for i in sale.items {
            L.append(i.name)
            L.append("\(Fmt.qty(i.qty)) x \(Fmt.money(i.price)) = \(Fmt.money(i.lineTotal))")
        }
        L.append(line)
        L.append("Subtotal: " + Fmt.money(sale.subtotal))
        if sale.discount > 0 { L.append("Diskon: " + Fmt.money(sale.discount)) }
        L.append("TOTAL: " + Fmt.money(sale.total))
        L.append("Dibayar: " + Fmt.money(sale.paid))
        L.append("Kembalian: " + Fmt.money(sale.changeDue))
        L.append(line)
        let p = policy(store)
        if !p.isEmpty { L.append(p) }
        L.append(thanks(store))
        return L.joined(separator: "\n")
    }
}

enum PrintHelper {
    /// Membuka menu cetak iOS (AirPrint) untuk teks nota.
    static func printText(_ text: String, jobName: String) {
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        let formatter = UISimpleTextPrintFormatter(text: text)
        formatter.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        formatter.perPageContentInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
        controller.printFormatter = formatter
        controller.present(animated: true, completionHandler: nil)
    }
}
