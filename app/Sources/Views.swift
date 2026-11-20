// The launcher's screens: home (list or grid), a game's settings with Back, the launcher's options panel. The controller focus is drawn as an accent outline
import SwiftUI

struct RootView: View {
    @ObservedObject var nav: Nav
    @ObservedObject var pad: Pad
    @ObservedObject var st = Settings.shared
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()   // follows light / dark mode
            switch nav.screen {
            case .home: HomeView(nav: nav)
            case .game(let g, let m): GameView(nav: nav, g: g, m: m)
            }
            if nav.options { OptionsPanel(nav: nav) }
        }
        .id(st.language)   // a language change redraws every screen in it
        .overlay(alignment: .bottom) {
            if let msg = nav.message { Text(msg).font(.callout).padding(12).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 24).onTapGesture { nav.message = nil } }
        }
    }
}

struct GameIcon: View {
    let g: Game; let size: CGFloat
    var body: some View {
        Group {
            if let i = g.icon { Image(uiImage: i).resizable().aspectRatio(1, contentMode: .fit) }
            else { RoundedRectangle(cornerRadius: size * 0.22).fill(.gray.opacity(0.3)).overlay(Image(systemName: "gamecontroller").font(.system(size: size * 0.35))) }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct HomeView: View {
    @ObservedObject var nav: Nav
    @ObservedObject var st = Settings.shared
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NX Games").font((UIDevice.current.userInterfaceIdiom == .pad ? Font.largeTitle : Font.title2).weight(.bold))   // an iPhone in landscape is short: a smaller title leaves the games more room
                Spacer()
                Button { st.view = st.view == "grid" ? "list" : "grid" } label: { Image(systemName: st.view == "grid" ? "list.bullet" : "square.grid.2x2").font(.title2).frame(width: 44, height: 44) }
                Button { nav.options = true; nav.optionFocus = 0 } label: { Image(systemName: "gearshape").font(.title2).frame(width: 44, height: 44) }
            }
            .padding(.horizontal, 20).padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 8 : 0)
            if nav.games.isEmpty { Spacer(); Text(L("No games in Frameworks.", "Frameworks에 게임이 없습니다.")).foregroundStyle(.secondary); Spacer() }
            else if st.view == "grid" { grid } else { list }
            if nav.pad.connected { HintBar(items: [("A", L("Open", "선택")), ("X", L("List / grid", "보기 전환")), ("+", L("Options", "설정"))]) }
        }
    }
    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(nav.games.enumerated()), id: \.1.id) { i, g in
                        Button { nav.homeFocus = i; nav.open(g) } label: {
                            HStack(spacing: 16) {
                                GameIcon(g: g, size: 64)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(g.name).font(.title3.weight(.semibold)).foregroundStyle(g.hasData ? .primary : .secondary)
                                    Text(g.hasData ? L("Version ", "버전 ") + g.version : L("Data not installed", "게임 데이터가 설치되지 않았습니다")).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor, lineWidth: nav.pad.connected && nav.homeFocus == i ? 3 : 0))
                        }
                        .buttonStyle(.plain).id(i)
                    }
                }
                .padding(20)
            }
            .onChange(of: nav.homeFocus) { _, f in withAnimation { proxy.scrollTo(f) } }
        }
    }
    private var grid: some View {
        GeometryReader { geo in
            // columns from the width: about 150 pt per game on an iPhone, 190 on an iPad; the icon fills its column
            let minW: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 190 : 150, gap: CGFloat = 20
            let cols = max(1, Int((geo.size.width - 40 + gap) / (minW + gap)))
            let w = (geo.size.width - 40 - gap * CGFloat(cols - 1)) / CGFloat(cols)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(w), spacing: gap), count: cols), spacing: 24) {
                        ForEach(Array(nav.games.enumerated()), id: \.1.id) { i, g in
                            Button { nav.homeFocus = i; nav.open(g) } label: {
                                VStack(spacing: 6) {
                                    GameIcon(g: g, size: w * 0.82)
                                        .overlay(RoundedRectangle(cornerRadius: w * 0.82 * 0.22, style: .continuous).stroke(Color.accentColor, lineWidth: nav.pad.connected && nav.homeFocus == i ? 4 : 0))
                                        .scaleEffect(nav.pad.connected && nav.homeFocus == i ? 1.05 : 1).opacity(g.hasData ? 1 : 0.45)
                                    Text(g.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2).frame(maxWidth: w)
                                    Text(g.hasData ? L("Version ", "버전 ") + g.version : L("Data not installed", "데이터 없음")).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain).id(i)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: nav.homeFocus) { _, f in withAnimation { proxy.scrollTo(f) } }
            }
            .onAppear { nav.cols = cols }.onChange(of: cols) { _, c in nav.cols = c }
        }
    }
}

struct GameView: View {
    @ObservedObject var nav: Nav
    let g: Game
    @ObservedObject var m: LauncherModel
    private func focused(_ it: GameItem) -> Bool { nav.pad.connected && nav.gameFocus == it }
    // The list's own card background everywhere (a custom row background replaces the inset card with plain rectangles: no rounded corners, cut off on the right);
    // only the controller's row gets a rounded tint over it
    private func focusBackground(_ it: GameItem) -> AnyView? {
        guard focused(it) else { return nil }
        return AnyView(ZStack { Color(.secondarySystemGroupedBackground); RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.25)).padding(3) })
    }
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(spacing: 16) {
                    GameIcon(g: g, size: min(120, geo.size.width / 3 * 0.5))
                    Text(g.name).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                    Text(L("Version ", "버전 ") + g.version).font(.callout).foregroundStyle(.secondary)
                    Button { nav.play(g, model: m) } label: { Text(L("Play", "시작")).font(.title3.weight(.semibold)).frame(maxWidth: 220) }
                        .buttonStyle(.borderedProminent).controlSize(.large).opacity(g.hasData ? 1 : 0.5)
                        .overlay(Capsule().stroke(Color.primary, lineWidth: focused(.play) ? 3 : 0).padding(-4))
                }
                .padding(16).frame(width: geo.size.width / 3, height: geo.size.height)
                ScrollViewReader { proxy in
                    List {
                        ForEach(m.sections, id: \.self) { section in
                            let rows = m.rows(in: section)
                            if !rows.isEmpty {
                                Section(section) {
                                    ForEach(rows) { s in
                                        SettingRow(s: s, m: m).id(GameItem.row(s.env))
                                            .listRowBackground(focusBackground(.row(s.env)))
                                    }
                                }
                            }
                        }
                        Section {
                            Button(L("Reset to tested defaults", "테스트된 기본값으로 되돌리기")) { m.reset() }.disabled(!m.changed).id(GameItem.reset)
                                .listRowBackground(focusBackground(.reset))
                        }
                        Section {
                            Toggle(isOn: Binding(get: { UserDefaults.standard.bool(forKey: nav.diagKey(g)) },
                                                 set: { UserDefaults.standard.set($0, forKey: nav.diagKey(g)); nav.objectWillChange.send() })) {
                                Text(L("GPU diagnosis (next start only)", "GPU 진단 (다음 실행 1회)"))
                            }
                            .id(GameItem.diag).listRowBackground(focusBackground(.diag))
                        } footer: {
                            Text(L("For one run, times every render pass of one frame in every five seconds. The game plays about as usual; it turns itself off once the game starts.",
                                   "한 번의 실행 동안 5초마다 한 프레임씩 렌더 패스별 GPU 시간을 기록합니다. 속도는 평소와 거의 같고, 게임이 시작되면 자동으로 꺼집니다."))
                        }
                    }
                    .listStyle(.insetGrouped).contentMargins(.horizontal, 12, for: .scrollContent)
                    .scrollContentBackground(.hidden)   // the screen's one background, not the list's own (which ran past the right edge into the safe area)
                    .onChange(of: nav.gameFocus) { _, f in withAnimation { proxy.scrollTo(f == .play ? GameItem.row(m.settings.first?.env ?? "") : f) } }
                }
                .frame(width: geo.size.width * 2 / 3)
            }
        }
        .overlay(alignment: .topLeading) {   // Back: to the game list (nothing of the game is loaded yet)
            Button { nav.back() } label: {
                Image(systemName: "chevron.left").font(.title2.weight(.semibold)).frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading, 12).padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if nav.pad.connected { HintBar(items: [("A", L("Select / change", "선택 · 변경")), ("←→", L("Adjust", "조절")), ("B", L("Back", "뒤로")), ("+", L("Play", "시작"))]) }
        }
    }
}

struct OptionsPanel: View {
    @ObservedObject var nav: Nav
    @ObservedObject var st = Settings.shared
    private let layouts = [("nintendo", L("Nintendo", "닌텐도")), ("xbox", "Xbox")]
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { nav.options = false }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L("Options", "설정")).font(.title2.weight(.bold))
                    Spacer()
                    Button { nav.options = false } label: { Image(systemName: "xmark").font(.title3).frame(width: 36, height: 36) }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(st.rows.enumerated()), id: \.1) { i, r in row(i, r) }
                    }
                }
            }
            .padding(24).frame(maxWidth: 540).background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray6))).padding(16)
        }
    }
    @ViewBuilder private func row(_ i: Int, _ r: Settings.Row) -> some View {
        Group {
            switch r {
            case .view: choice(L("Game list", "게임 목록"), $st.view, [("grid", L("Grid", "그리드")), ("list", L("List", "리스트"))])
            case .unified: Toggle(isOn: $st.unified) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Same layout for touch and controller", "터치·컨트롤러 배열 통합")).font(.headline)
                        Text(L("Off: set each on its own", "끄면 터치와 컨트롤러를 따로 설정")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onChange(of: st.unified) { _, on in if !on { st.touchAbxy = st.abxy; st.padAbxy = st.abxy } }
            case .abxy: choice(L("Button layout", "버튼 배열"), $st.abxy, layouts)
            case .touch: choice(L("Touch controls", "터치 컨트롤"), $st.touchAbxy, layouts)
            case .pad: choice(L("Controller", "패드 컨트롤"), $st.padAbxy, layouts)
            case .language: choice(L("Language", "언어"), $st.language, [("ko", "한국어"), ("en", "English")])
            }
        }
        .padding(10).background(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor, lineWidth: nav.pad.connected && nav.optionFocus == i ? 3 : 0))
    }
    // Every layout choice is the same two-segment control, unified or not
    private func choice(_ title: String, _ v: Binding<String>, _ opts: [(String, String)]) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer(minLength: 16)
            Picker(title, selection: v) { ForEach(opts, id: \.0) { Text($0.1).tag($0.0) } }.pickerStyle(.segmented).frame(maxWidth: 240)
        }
    }
}

struct HintBar: View {
    let items: [(String, String)]
    var body: some View {
        HStack(spacing: 18) {
            ForEach(items, id: \.0) { k, v in
                HStack(spacing: 6) { Text(k).font(.caption.weight(.bold)).padding(.horizontal, 7).padding(.vertical, 3).background(Color.primary.opacity(0.15), in: Capsule()); Text(v).font(.caption) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 10)
    }
}
