import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            AppBackground()
            if app.booting {
                ProgressView().tint(Theme.blue3).scaleEffect(1.3)
            } else if let me = app.me {
                if me.isAdmin { AdminShell() } else { CustomerShell() }
            } else {
                LoginView().transition(.opacity)
            }
            ToastHost()
            if app.isLocked && app.me != nil {
                LockView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: app.me?.username)
        .animation(.easeInOut(duration: 0.25), value: app.isLocked)
        .task { await app.bootstrap() }
        .onChange(of: phase) { p in app.scenePhaseChanged(p) }
    }
}

// MARK: kerangka admin: layar + bilah menu melayang

struct AdminShell: View {
    @EnvironmentObject var app: AppState
    @State private var showPassword = false

    var body: some View {
        ZStack {
            switch app.tab {
            case .dashboard: DashboardView()
            case .kasir: POSView()
            case .riwayat: NavigationStack { SalesView() }
            case .pelanggan: NavigationStack { CustomersView() }
            case .lainnya: NavigationStack { MoreView() }
            }
        }
        .id(app.tab)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.22), value: app.tab)
        .safeAreaInset(edge: .bottom) { FloatingTabBar() }
        .sheet(isPresented: $showPassword) { ChangePasswordSheet(forced: true) }
        .task {
            if app.me?.mustChange == true {
                try? await Task.sleep(nanoseconds: 700_000_000)
                showPassword = true
            }
        }
    }
}

// MARK: layar kunci Face ID

struct LockView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Theme.bg0.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "faceid")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.white)
                    .frame(width: 92, height: 92)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.brand))
                    .shadow(color: Theme.blue2.opacity(0.6), radius: 20, x: 0, y: 10)
                Text("Aplikasi terkunci").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                Text("Buka dengan Face ID atau kode iPhone Anda.").font(.system(size: 14)).foregroundColor(Theme.muted)
                Button {
                    Task { @MainActor in await app.unlock() }
                } label: {
                    Label("Buka kunci", systemImage: "lock.open.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 50)
                .padding(.top, 8)
            }
        }
        .task { await app.unlock() }
    }
}

// MARK: layar login

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var username = ""
    @State private var password = ""
    @State private var server = ""
    @State private var showServer = false
    @State private var loading = false
    @State private var errorText: String?
    @State private var shakes: CGFloat = 0
    @State private var drift = false
    @FocusState private var focus: Field?

    enum Field { case user, pass, server }

    var body: some View {
        ZStack {
            orbs
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    card
                    Text("Sesi login berakhir otomatis setelah 12 jam.")
                        .font(.system(size: 12)).foregroundColor(Theme.muted).padding(.top, 16)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            server = app.serverURL
            drift = true
        }
    }

    private var orbs: some View {
        ZStack {
            Circle().fill(Color(red: 0.114, green: 0.306, blue: 0.847)).frame(width: 320, height: 320).blur(radius: 70)
                .offset(x: drift ? -90 : -150, y: drift ? -230 : -280)
            Circle().fill(Color(red: 0.03, green: 0.57, blue: 0.70)).frame(width: 280, height: 280).blur(radius: 70)
                .offset(x: drift ? 130 : 90, y: drift ? 300 : 340)
            Circle().fill(Theme.indigo).frame(width: 220, height: 220).blur(radius: 70)
                .offset(x: drift ? -40 : 20, y: drift ? 120 : 60)
        }
        .opacity(0.5)
        .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: drift)
        .allowsHitTesting(false)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "cart.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Theme.brand))
                .shadow(color: Theme.blue2.opacity(0.6), radius: 14, x: 0, y: 8)
            Text("Selamat datang").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding(.top, 4)
            Text("Masuk dengan akun Anda untuk melanjutkan.").font(.system(size: 14)).foregroundColor(Theme.muted)

            VStack(alignment: .leading, spacing: 6) {
                Text("USERNAME").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.muted)
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focus, equals: .user)
                    .submitLabel(.next)
                    .onSubmit { focus = .pass }
                    .fieldStyle()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("PASSWORD").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.muted)
                SecureField("Masukkan password", text: $password)
                    .focused($focus, equals: .pass)
                    .submitLabel(.go)
                    .onSubmit { submit() }
                    .fieldStyle()
            }

            if let e = errorText {
                Text(e)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 1, green: 0.8, blue: 0.84))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.red.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.red.opacity(0.35), lineWidth: 1))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button { submit() } label: {
                HStack(spacing: 8) {
                    if loading { ProgressView().tint(.white) }
                    Text(loading ? "Masuk..." : "Masuk ke aplikasi")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(loading)
            .padding(.top, 4)

            Button {
                Fx.tap()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showServer.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack").font(.system(size: 12))
                    Text("Alamat server").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: showServer ? "chevron.up" : "chevron.down").font(.system(size: 11))
                }
                .foregroundColor(Theme.muted)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            if showServer {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("https://alamat-server-anda", text: $server)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .focused($focus, equals: .server)
                        .fieldStyle()
                    Text("Isi dengan alamat Tailscale Funnel server kasir Anda.")
                        .font(.system(size: 11)).foregroundColor(Theme.muted)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard(padding: 24, radius: 26)
        .modifier(ShakeEffect(animatableData: shakes))
    }

    private func submit() {
        let u = username.trimmingCharacters(in: .whitespaces)
        if u.isEmpty || password.isEmpty {
            fail("Isi username dan password.")
            return
        }
        focus = nil
        loading = true
        withAnimation { errorText = nil }
        Task { @MainActor in
            do {
                try await app.login(username: u, password: password, server: server)
            } catch {
                fail(app.message(for: error))
            }
            loading = false
        }
    }

    private func fail(_ message: String) {
        withAnimation { errorText = message }
        Fx.error()
        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
    }
}
