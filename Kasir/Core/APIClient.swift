import Foundation

struct APIFailure: LocalizedError {
    var message: String
    var unauthorized: Bool = false
    var errorDescription: String? { return message }
}

private struct ServerError: Decodable {
    var error: String?
}

/// Klien REST untuk server kasir (alamat yang sama dengan versi web).
final class APIClient {
    static let shared = APIClient()

    var baseURL: URL?
    var token: String?
    var onUnauthorized: (() -> Void)?

    private let session: URLSession
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder = JSONEncoder()

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.timeoutIntervalForResource = 120
        session = URLSession(configuration: cfg)
    }

    // MARK: inti permintaan

    func data(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil, contentType: String = "application/json") async throws -> Data {
        guard let base = baseURL, var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIFailure(message: "Alamat server belum diisi.")
        }
        let basePath = comps.path.hasSuffix("/") ? String(comps.path.dropLast()) : comps.path
        comps.path = basePath + "/api" + path
        comps.queryItems = query.isEmpty ? nil : query
        guard let url = comps.url else { throw APIFailure(message: "Alamat server tidak valid.") }

        var req = URLRequest(url: url)
        req.httpMethod = method
        if let t = token { req.setValue(t, forHTTPHeaderField: "x-kasir-session") }
        if let b = body {
            req.httpBody = b
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: req)
        } catch let e as URLError {
            switch e.code {
            case .timedOut: throw APIFailure(message: "Server tidak menjawab. Coba lagi sebentar.")
            case .notConnectedToInternet: throw APIFailure(message: "Tidak ada koneksi internet.")
            default: throw APIFailure(message: "Tidak bisa terhubung ke server. Periksa alamat server dan koneksi Anda.")
            }
        } catch {
            throw APIFailure(message: error.localizedDescription)
        }

        guard let http = result.1 as? HTTPURLResponse else { throw APIFailure(message: "Jawaban server tidak dikenali.") }
        if http.statusCode >= 400 {
            let msg = (try? decoder.decode(ServerError.self, from: result.0))?.error
            if http.statusCode == 401 && path != "/login" {
                onUnauthorized?()
                throw APIFailure(message: msg ?? "Sesi berakhir. Silakan login kembali.", unauthorized: true)
            }
            if http.statusCode == 404 && msg == nil {
                throw APIFailure(message: "Server belum mendukung fitur ini. Perbarui server ke versi terbaru.")
            }
            throw APIFailure(message: msg ?? "Permintaan gagal (kode \(http.statusCode)).")
        }
        return result.0
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch let DecodingError.keyNotFound(key, ctx) {
            throw APIFailure(message: "Data dari server tidak lengkap (kolom \(key.stringValue) hilang di \(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))).")
        } catch let DecodingError.typeMismatch(_, ctx) {
            throw APIFailure(message: "Format data dari server berbeda (\(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))).")
        } catch {
            throw APIFailure(message: "Format data dari server tidak dikenali.")
        }
    }

    // MARK: pembungkus praktis

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let d = try await data("GET", path, query: query)
        return try decode(d)
    }

    func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, body: B) async throws -> T {
        let payload = try encoder.encode(body)
        let d = try await data(method, path, body: payload)
        return try decode(d)
    }

    func sendIgnoringResult<B: Encodable>(_ method: String, _ path: String, body: B) async throws {
        let payload = try encoder.encode(body)
        _ = try await data(method, path, body: payload)
    }

    func delete(_ path: String) async throws {
        _ = try await data("DELETE", path)
    }

    func post(_ path: String) async throws {
        _ = try await data("POST", path)
    }

    /// Unggah berkas backup (JSON atau kasir.db). dry = true hanya pratinjau.
    func importBackup(_ file: Data, dry: Bool) async throws -> ImportResult {
        let d = try await data("POST", "/import", query: dry ? [URLQueryItem(name: "dry", value: "1")] : [], body: file, contentType: "application/octet-stream")
        return try decode(d)
    }
}
