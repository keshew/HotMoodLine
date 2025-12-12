import SwiftUI

enum CasinoMood: String, CaseIterable {
    case chill = "chill", neutral = "neutral", hot = "hot"
    
    var displayName: String {
        switch self {
        case .chill: return "Chill ❄️"
        case .neutral: return "Neutral ⚪"
        case .hot: return "Hot 🔥"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .chill: return 1.0
        case .neutral: return 1.05
        case .hot: return 1.15
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .chill: return [.blue.opacity(0.8), .cyan]
        case .neutral: return [.purple.opacity(0.8), .blue]
        case .hot: return [.orange.opacity(0.9), .red]
        }
    }
    
    var description: String {
        switch self {
        case .chill: return "Casino is feeling relaxed today"
        case .neutral: return "Business as usual"
        case .hot: return "The casino is on fire today! 🔥"
        }
    }
}

@MainActor
class AppManager: ObservableObject {
    @Published var balance: Double = 1000
    @Published var currentMood: CasinoMood = .neutral
    @Published var sessionWins: Int = 0
    
    // MARK: - Daily bonus
    @Published var lastDailyBonusDate: Date? = nil
    @Published private(set) var hotBoosterUntil: Date? = nil
    
    private let moodWeights: [CasinoMood: Double] = [.chill: 0.4, .neutral: 0.4, .hot: 0.2]
    
    private let balanceKey = "balance"
    private let currentMoodKey = "currentMood"
    private let sessionWinsKey = "sessionWins"
    private let lastDailyBonusKey = "lastDailyBonusDate"
    
    init() {
        loadData()
        generateMood()
    }
    
    var effectiveMood: CasinoMood {
        if let until = hotBoosterUntil, Date() < until {
            return .hot
        }
        return currentMood
    }
    
    func activateHotMoodBooster(for duration: TimeInterval) {
        hotBoosterUntil = Date().addingTimeInterval(duration)
        saveData()
    }
    
    func generateMood() {
        let random = Double.random(in: 0...1)
        var cumulative = 0.0
        
        for mood in CasinoMood.allCases {
            cumulative += moodWeights[mood] ?? 0
            if random <= cumulative {
                currentMood = mood
                break
            }
        }
        saveData()
    }
    
    // MARK: - Balance
    
    func applyWin(amount: Double) {
        let moodToUse = effectiveMood
        let moodBonus = amount * (moodToUse.multiplier - 1)
        balance += amount + moodBonus
        sessionWins += 1
        saveData()
    }

    
    func applyBet(amount: Double) {
        balance -= amount
        saveData()
    }
    
    func addBalance(amount: Double) {
        balance += amount
        saveData()
    }
    
    // MARK: - Daily bonus logic
    
    var canTakeDailyBonus: Bool {
        guard balance < 100 else { return false }
        guard let lastDate = lastDailyBonusDate else { return true }
        // новый день относительно последнего бонуса
        return !Calendar.current.isDateInToday(lastDate)
    }
    
    func takeDailyBonus() {
        guard canTakeDailyBonus else { return }
        addBalance(amount: 500)
        lastDailyBonusDate = Date()
        saveData()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        let defaults = UserDefaults.standard
        defaults.set(balance, forKey: balanceKey)
        defaults.set(currentMood.rawValue, forKey: currentMoodKey)
        defaults.set(sessionWins, forKey: sessionWinsKey)
        if let lastDate = lastDailyBonusDate {
            defaults.set(lastDate.timeIntervalSince1970, forKey: lastDailyBonusKey)
        }
    }
    
    private func loadData() {
        let defaults = UserDefaults.standard
        
        let storedBalance = defaults.double(forKey: balanceKey)
        if storedBalance > 0 {
            balance = storedBalance
        }
        
        if let moodString = defaults.string(forKey: currentMoodKey),
           let mood = CasinoMood(rawValue: moodString) {
            currentMood = mood
        }
        
        sessionWins = defaults.integer(forKey: sessionWinsKey)
        
        let timestamp = defaults.double(forKey: lastDailyBonusKey)
        if timestamp > 0 {
            lastDailyBonusDate = Date(timeIntervalSince1970: timestamp)
        }
    }
}


import SwiftUI

struct MoodBackground: ViewModifier {
    let mood: CasinoMood
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: mood.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    func moodBackground(_ mood: CasinoMood) -> some View {
        modifier(MoodBackground(mood: mood))
    }
}

struct ContentView: View {
    @StateObject private var manager = AppManager()
    
    var body: some View {
        NavigationStack {
            TabView {
                HomeView(manager: manager)
                    .tabItem {
                        Label("Home", systemImage: "house")
                            .environment(\.symbolVariants, manager.currentMood == .hot ? .fill : .none)
                    }
                
                GamesView(manager: manager)
                    .tabItem {
                        Label("Games", systemImage: "gamecontroller")
                            .environment(\.symbolVariants, manager.currentMood == .hot ? .fill : .none)
                    }
                
                ShopView(manager: manager)
                    .tabItem {
                        Label("Shop", systemImage: "cart")
                            .environment(\.symbolVariants, manager.currentMood == .hot ? .fill : .none)
                    }
            }
            .tint(.gray)
            .onAppear {
                if !UserDefaults.standard.bool(forKey: "moodGeneratedToday") {
                    manager.generateMood()
                    UserDefaults.standard.set(true, forKey: "moodGeneratedToday")
                }
            }
        }
    }
}


#Preview {
    ContentView()
}

struct HomeView: View {
    @ObservedObject var manager: AppManager
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: manager.currentMood.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                header
                quickGames
                Spacer()
                stats
            }
            .padding()
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            Text("Balance")
                .font(.caption.uppercaseSmallCaps())
                .foregroundColor(.white.opacity(0.7))
            
            Text("\(manager.balance, specifier: "%.0f") coins")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
            
            MoodBannerView(mood: manager.currentMood)
        }
    }
    
    private var quickGames: some View {
        VStack(spacing: 16) {
            gameButtonNav(
                title: "Classic Slots",
                icon: "🎰",
                destination: ClassicSlotsView(manager: manager)
            )
            gameButtonNav(
                title: "Lucky Wheel",
                icon: "🎡",
                destination: LuckyWheelView(manager: manager)
            )
            gameButtonNav(
                title: "Aviator",
                icon: "✈️",
                destination: AviatorView(manager: manager)
            )
        }
    }
    
    @ViewBuilder
    private func gameButtonNav<Destination: View>(
        title: String,
        icon: String,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            gameButton(title: title, icon: icon)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var stats: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Wins")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("\(manager.sessionWins)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Mood Multiplier")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("x\(manager.currentMood.multiplier, specifier: "%.2f")")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.25))
        .cornerRadius(18)
    }
    
    @ViewBuilder
    private func gameButton(title: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text("Play now with mood bonus")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .foregroundColor(.white)
    }
}

struct MoodBannerView: View {
    let mood: CasinoMood
    
    var body: some View {
        VStack(spacing: 8) {
            Text(mood.displayName)
                .font(.title.bold())
                .scaleEffect(1.1)
            
            Text(mood.description)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

struct GamesView: View {
    @ObservedObject var manager: AppManager
    
    private var moodMultiplierText: String {
        String(format: "%.2f", manager.currentMood.multiplier)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: manager.currentMood.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            Text("All Games")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Play with \(moodMultiplierText) mood bonus")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        gameCardNavLink(
                            title: "Classic Slots",
                            subtitle: "3 reels, fruits & 7s",
                            icon: "🎰",
                            moodBonus: "x\(moodMultiplierText)",
                            destination: ClassicSlotsView(manager: manager)
                        )
                        
                        gameCardNavLink(
                            title: "Lucky Wheel",
                            subtitle: "8 sectors x0.5-x10",
                            icon: "🎡",
                            moodBonus: "x\(moodMultiplierText)",
                            destination: LuckyWheelView(manager: manager)
                        )
                        
                        gameCardNavLink(
                            title: "Aviator Crash",
                            subtitle: "Cash out before crash",
                            icon: "✈️",
                            moodBonus: "x\(moodMultiplierText)",
                            destination: AviatorView(manager: manager)
                        )
                        
                        gameCardNavLink(
                            title: "Plinko Drop",
                            subtitle: "Ball drops with multipliers",
                            icon: "🔵",
                            moodBonus: "x\(moodMultiplierText)",
                            destination: PlinkoView(manager: manager)
                        )
                        
                        gameCardNavLink(
                            title: "Number Match",
                            subtitle: "Poker hands from 1-9",
                            icon: "🔢",
                            moodBonus: "x\(moodMultiplierText)",
                            destination: NumberMatchView(manager: manager)
                        )
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                }
                .navigationTitle("Games")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    @ViewBuilder
    private func gameCardNavLink<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        moodBonus: String,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            gameCard(title: title, subtitle: subtitle, icon: icon, moodBonus: moodBonus)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func gameCard(title: String, subtitle: String, icon: String, moodBonus: String) -> some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 36, weight: .medium))
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.4))
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 2)
                        )
                )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Image(systemName: "star.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                
                Text(moodBonus)
                    .font(.caption.monospaced())
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct ShopView: View {
    @ObservedObject var manager: AppManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: manager.currentMood.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 25) {
                    header

                    if manager.balance < 100 {
                        shopItem(
                            title: "Daily Coins Bonus",
                            subtitle: "+500 coin once per day if balance < 100 coins",
                            priceText: "FREE",
                            icon: "gift.fill",
                            isAvailable: manager.canTakeDailyBonus,
                            action: {
                                manager.takeDailyBonus()
                            }
                        )
                    }

                    shopItem(
                        title: "Hot Mood Booster",
                        subtitle: "+25% Hot Mood for 30 min",
                        priceText: "100 coins",
                        icon: "flame.fill",
                        isAvailable: manager.balance >= 100,
                        action: {
                            if manager.balance >= 100 {
                                manager.applyBet(amount: 100)
                                manager.activateHotMoodBooster(for: 30 * 60)
                            }
                        }
                    )

                    soonItem(
                        title: "VIP Mood Pack",
                        subtitle: "Unique moods & x3 boosters",
                        icon: "crown.fill"
                    )

                    soonItem(
                        title: "Season Pass",
                        subtitle: "Weekly rewards and quests",
                        icon: "calendar.badge.plus"
                    )

                    soonItem(
                        title: "Game Skins",
                        subtitle: "Custom themes for slots & wheel",
                        icon: "paintpalette.fill"
                    )

                    Spacer(minLength: 100)
                }
                .padding()
            }
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func shopItem(
        title: String,
        subtitle: String,
        priceText: String,
        icon: String,
        isAvailable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            if isAvailable {
                action()
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white.opacity(isAvailable ? 1.0 : 0.4))
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.3))
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text(priceText)
                        .font(.title3.bold())
                        .foregroundColor(isAvailable ? .yellow.opacity(0.9) : .white.opacity(0.5))

                    Text(isAvailable ? "Buy" : "Unavailable")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.2))
                        )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial.opacity(isAvailable ? 0.4 : 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isAvailable ? 1.0 : 0.98)
            .opacity(isAvailable ? 1.0 : 0.7)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isAvailable)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func soonItem(
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.2))
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Text("Soon")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.12))
                )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.25))
        )
        .buttonStyle(.plain)
    }

    
    private var header: some View {
        VStack(spacing: 8) {
            Text("Shop")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)

            Text("Buy boosters & coins")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}


enum SlotSymbol: String, CaseIterable {
    case cherry = "cherry", lemon = "lemon", star = "star", seven = "seven", bar = "bar"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var imageName: String {
        switch self {
        case .cherry: return "flame.fill"
        case .lemon: return "leaf.fill"
        case .star: return "star.fill"
        case .seven: return "7.circle.fill"
        case .bar: return "square.fill"
        }
    }
    
    var payout: Int {
        switch self {
        case .cherry: return 2
        case .lemon: return 3
        case .star: return 5
        case .seven: return 10
        case .bar: return 15
        }
    }
}

@MainActor
class ClassicSlotsViewModel: ObservableObject {
    @Published var reels: [[SlotSymbol]] = Array(repeating: [.cherry, .lemon, .star], count: 3)  // 3 ряда x 3 символа
    @Published var isSpinning = false
    @Published var betAmount: Double = 10
    @Published var lastWin: Double = 0
    @Published var balance: Double = 1000
    
    weak var appManager: AppManager?
    
    var canSpin: Bool { !isSpinning && balance >= betAmount }
    
    func spin() {
        guard canSpin else { return }
        
        appManager?.applyBet(amount: betAmount)
        balance = appManager?.balance ?? balance
        isSpinning = true
        
        withAnimation(.easeInOut(duration: 2.5)) {
            reels = (0..<3).map { _ in  // 3 ряда
                (0..<3).map { _ in SlotSymbol.allCases.randomElement()! }  // 3 символа в ряду
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            self.checkWin()
            self.isSpinning = false
        }
    }
    
    private func checkWin() {
        // Проверяем горизонтальные линии (3 ряда)
        for row in 0..<3 {
            if reels[row][0] == reels[row][1] && reels[row][1] == reels[row][2] {
                let baseWin = Double(reels[row][0].payout) * betAmount
                appManager?.applyWin(amount: baseWin)
                lastWin = baseWin * (appManager?.effectiveMood.multiplier ?? 1.0) - betAmount
                balance = appManager?.balance ?? balance
                return  // первая найденная линия
            }
        }
    }
}


struct ClassicSlotsView: View {
    @ObservedObject var manager: AppManager
    @StateObject private var viewModel = ClassicSlotsViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: manager.currentMood.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                header
                reels
                controls
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Classic Slots")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.appManager = manager
            viewModel.balance = manager.balance
        }
        .onChange(of: manager.balance) { newBalance in
            viewModel.balance = newBalance
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.balance, specifier: "%.0f") coins")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Bet")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.betAmount, specifier: "%.0f") coins")
                        .font(.title2.bold())
                        .foregroundColor(.yellow)
                }
            }
            
            if viewModel.lastWin > 0 {
                Text("WIN! +\(viewModel.lastWin, specifier: "%.0f")Coins Mood Bonus")
                    .font(.headline.bold())
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var reels: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(0..<9, id: \.self) { index in  // 9 барабанов
                let row = index / 3
                let col = index % 3
                ReelView(
                    symbol: viewModel.reels[row][col],
                    isSpinning: viewModel.isSpinning
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 2)
                )
        )
    }
    
    private var controls: some View {
        VStack(spacing: 16) {
            Button("SPIN \(viewModel.betAmount, specifier: "%.0f") coins") {
                withAnimation(.spring()) {
                    viewModel.spin()
                }
            }
            .font(.title2.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(viewModel.canSpin ? .yellow.opacity(0.9) : .gray.opacity(0.5))
            )
            .disabled(!viewModel.canSpin)
            .scaleEffect(viewModel.isSpinning ? 0.95 : 1.0)
            .animation(.spring(), value: viewModel.isSpinning)
        }
        .padding(.horizontal, 40)
    }
}

struct ReelView: View {
    let symbol: SlotSymbol
    let isSpinning: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial.opacity(0.6))
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
            
            Image(systemName: symbol.imageName)
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(symbolColor)
                .rotationEffect(isSpinning ? .degrees(360) : .degrees(0))
                .animation(isSpinning ? .linear(duration: 0.5).repeatForever(autoreverses: false) : .default, value: isSpinning)
        }
    }
    
    private var symbolColor: Color {
        switch symbol {
        case .cherry: return .red
        case .lemon: return .yellow
        case .star: return .yellow
        case .seven: return .orange
        case .bar: return .purple
        }
    }
}

import SwiftUI

struct WheelSegment {
    let multiplier: Double
    let color: Color
    var title: String {
        let value = String(format: "%.1f", multiplier)
        return "x\(value)"
    }
}

@MainActor
class LuckyWheelViewModel: ObservableObject {
    @Published var segments: [WheelSegment] = []
    @Published var rotationAngle: Angle = .degrees(0)
    @Published var isSpinning = false
    @Published var betAmount: Double = 25
    @Published var lastWin: Double = 0
    @Published var balance: Double = 1000
    
    weak var appManager: AppManager?
    
    var canSpin: Bool { !isSpinning && balance >= betAmount }
    
    init() {
        setupSegments()
    }
    
    private func setupSegments() {
        segments = [
            WheelSegment(multiplier: 0.5, color: .gray),
            WheelSegment(multiplier: 1.0, color: .blue),
            WheelSegment(multiplier: 2.0, color: .green),
            WheelSegment(multiplier: 0.8, color: .orange),
            WheelSegment(multiplier: 5.0, color: .yellow),
            WheelSegment(multiplier: 1.5, color: .purple),
            WheelSegment(multiplier: 10.0, color: .red),
            WheelSegment(multiplier: 3.0, color: .pink)
        ]
    }
    
    func spin() {
        guard canSpin else { return }
        
        appManager?.applyBet(amount: betAmount)
        balance = appManager?.balance ?? balance
        isSpinning = true
        
        let randomRotation = Double.random(in: 1440...2880)
        let spinDuration: Double = 3.0 + randomRotation.truncatingRemainder(dividingBy: 360) / 120
        
        withAnimation(.easeOut(duration: spinDuration)) {
            rotationAngle = .degrees(rotationAngle.degrees + randomRotation)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            self.checkWin()
            self.isSpinning = false
        }
    }
    
    private func checkWin() {
        let normalizedAngle = (-rotationAngle.degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let segmentIndex = Int((normalizedAngle / 45).truncatingRemainder(dividingBy: 8))
        let winningSegment = segments[segmentIndex]
        let baseWin = betAmount * winningSegment.multiplier
        
        appManager?.applyWin(amount: baseWin)
        lastWin = baseWin * (appManager?.currentMood.multiplier ?? 1.0) - baseWin
        balance = appManager?.balance ?? balance
    }
}

struct LuckyWheelView: View {
    @ObservedObject var manager: AppManager
    @StateObject private var viewModel = LuckyWheelViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: manager.currentMood.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                header
                wheel
                controls
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Lucky Wheel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.appManager = manager
            viewModel.balance = manager.balance
        }
        .onChange(of: manager.balance) { newBalance in
            viewModel.balance = newBalance
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(String(format: "%.0f", viewModel.balance)) coins")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Bet")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(String(format: "%.0f", viewModel.betAmount)) coins")
                        .font(.title2.bold())
                        .foregroundColor(.yellow)
                }
            }
            
            if viewModel.lastWin > 0 {
                Text("WIN! x\(String(format: "%.1f", viewModel.segments[0].multiplier)) + \(String(format: "%.0f", viewModel.lastWin))Coins Mood Bonus")
                    .font(.headline.bold())
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
            }
        }
    }
    
    private var wheel: some View {
        ZStack {
            ForEach(0..<viewModel.segments.count, id: \.self) { index in
                WheelSegmentView(
                    segment: viewModel.segments[index],
                    angle: Angle(degrees: Double(index) * 45),
                    rotation: viewModel.rotationAngle
                )
            }
            
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 3))
                .overlay(
                    Image(systemName: "triangle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(180))
                )
        }
        .frame(width: 280, height: 280)
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
    }

    
    private var controls: some View {
        VStack(spacing: 16) {
            Button("SPIN \(String(format: "%.0f", viewModel.betAmount)) coins") {
                withAnimation(.spring()) {
                    viewModel.spin()
                }
            }
            .font(.title2.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .padding(50)
            .background(
                Circle()
                    .fill(viewModel.canSpin ? .yellow.opacity(0.9) : .gray.opacity(0.5))
                    .shadow(color: .yellow.opacity(0.4), radius: 15, x: 0, y: 5)
            )
            .disabled(!viewModel.canSpin)
            .scaleEffect(viewModel.isSpinning ? 0.95 : 1.0)
            .animation(.spring(), value: viewModel.isSpinning)
        }
        .padding(.horizontal, 40)
    }
}

struct WheelSegmentView: View {
    let segment: WheelSegment
    let angle: Angle
    let rotation: Angle
    
    var body: some View {
        ZStack {
            Path { path in
                let center = CGPoint(x: 140, y: 140)
                let radius: CGFloat = 140
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: angle, endAngle: angle + .degrees(45), clockwise: false)
            }
            .fill(segment.color.opacity(0.5))
            .overlay(
                Path { path in
                    let center = CGPoint(x: 140, y: 140)
                    let radius: CGFloat = 140
                    path.move(to: center)
                    path.addArc(center: center, radius: radius, startAngle: angle, endAngle: angle + .degrees(45), clockwise: false)
                }
                .stroke(.white.opacity(0.3), lineWidth: 2)
            )
            
            Text(segment.title)
                .font(.caption.bold())
                .fontWeight(.heavy)
                .padding(8)
                .offset(y: -90)
                .rotationEffect(angle + .degrees(22.5))
                .zIndex(10)
        }
        .rotationEffect(rotation)
        .frame(width: 280, height: 280, alignment: .center)
    }
}

import SwiftUI
import Combine

@MainActor
class AviatorViewModel: ObservableObject {
    @Published var multiplier: Double = 1.0
    @Published var isRunning = false
    @Published var isCrashed = false
    @Published var betAmount: Double = 20
    @Published var lastWin: Double = 0
    @Published var balance: Double = 1000
    @Published var crashPoint: Double = 0

    weak var appManager: AppManager?

    private var timer: AnyCancellable?

    var canStart: Bool { !isRunning && balance >= betAmount }
    var canCashOut: Bool { isRunning && !isCrashed }

    func start() {
        guard canStart else { return }

        isRunning = true
        isCrashed = false
        lastWin = 0
        multiplier = 1.0

        appManager?.applyBet(amount: betAmount)
        balance = appManager?.balance ?? balance

        crashPoint = Double.random(in: 1.2...8.0)

        timer?.cancel()
        timer = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard isRunning else { return }

        let step = 0.01 + multiplier * 0.01
        multiplier += step

        if multiplier >= crashPoint {
            crash()
        }
    }

    func cashOut() {
        guard canCashOut else { return }

        isRunning = false
        timer?.cancel()

        let baseWin = betAmount * multiplier
        appManager?.applyWin(amount: baseWin)
        let moodMult = appManager?.currentMood.multiplier ?? 1.0
        lastWin = baseWin * moodMult - betAmount
        balance = appManager?.balance ?? balance
    }

    private func crash() {
        isRunning = false
        isCrashed = true
        timer?.cancel()
        balance = appManager?.balance ?? balance
    }

    func stop() {
        isRunning = false
        timer?.cancel()
    }
}

struct AviatorView: View {
    @ObservedObject var manager: AppManager
    @StateObject private var viewModel = AviatorViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: manager.currentMood.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                flightArea
                controls
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Aviator Crash")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.appManager = manager
            viewModel.balance = manager.balance
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: manager.balance) { newValue in
            viewModel.balance = newValue
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(viewModel.balance)) coins")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Bet")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(viewModel.betAmount)) coins")
                        .font(.title2.bold())
                        .foregroundColor(.yellow)
                }
            }

            if viewModel.lastWin > 0 {
                Text("Last win +\(Int(viewModel.lastWin)) coins")
                    .font(.headline.bold())
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
            }
        }
    }

    private var flightArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.2), lineWidth: 1.5)
                )

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let progress = min(viewModel.multiplier / 8.0, 1.0)

                Path { path in
                    path.move(to: CGPoint(x: 16, y: height - 24))
                    let endX = 16 + (width - 32) * progress
                    let endY = height - 24 - (height - 60) * progress
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(Color.green.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                let endX = 16 + (width - 32) * progress
                let endY = height - 24 - (height - 60) * progress

                Image(systemName: "airplane")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .position(x: endX, y: endY)
                    .rotationEffect(.degrees(-25))

                Text(String(format: "x%.2f", viewModel.multiplier))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.isCrashed ? .red : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.5))
                    )
                    .position(x: endX, y: endY - 40)
            }
            .padding(16)
        }
        .frame(height: 260)
    }

    private var controls: some View {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Button(viewModel.isRunning ? "Cash Out" : "Start") {
                        if viewModel.isRunning {
                            viewModel.cashOut()
                        } else {
                            viewModel.start()
                        }
                    }
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(viewModel.isRunning ? Color.green : Color.yellow)
                    )
                    .disabled(!viewModel.canStart && !viewModel.isRunning)

                    Button("-10") {
                        viewModel.betAmount = max(5, viewModel.betAmount - 10)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.2))
                    )

                    Button("+10") {
                        viewModel.betAmount = min(500, viewModel.betAmount + 10)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.2))
                    )
                }

                if viewModel.isCrashed {
                    Text(String(format: "Crashed at x%.2f", viewModel.crashPoint))
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                }
            }
    }
}

import SwiftUI

struct PlinkoSlot: Identifiable {
    let id = UUID()
    let multiplier: Double
}

@MainActor
class PlinkoViewModel: ObservableObject {
    @Published var slots: [PlinkoSlot] = []
    @Published var currentRow: Int? = nil
    @Published var currentCol: Int? = nil
    @Published var isDropping = false
    @Published var betAmount: Double = 10
    @Published var lastWin: Double = 0
    @Published var balance: Double = 1000
    
    weak var appManager: AppManager?
    
    let rows = 6
    let cols = 9
    
    func setup() {
        slots = [
            PlinkoSlot(multiplier: 0.5),
            PlinkoSlot(multiplier: 0.8),
            PlinkoSlot(multiplier: 1.0),
            PlinkoSlot(multiplier: 1.5),
            PlinkoSlot(multiplier: 3.0),
            PlinkoSlot(multiplier: 1.5),
            PlinkoSlot(multiplier: 1.0),
            PlinkoSlot(multiplier: 0.8)
        ]
    }
    
    var canDrop: Bool { !isDropping && balance >= betAmount }
    
    func drop() {
        guard canDrop else { return }
        isDropping = true
        lastWin = 0
        
        appManager?.applyBet(amount: betAmount)
        balance = appManager?.balance ?? balance
        
        currentRow = 0
        currentCol = cols / 2
        
        step()
    }
    
    private func step() {
        guard let row = currentRow, let col = currentCol else { return }
        
        if row >= rows {
            finishDrop()
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            // случайный шаг влево/вправо/прямо
            let move = Int.random(in: -1...1)
            let newCol = min(max(col + move, 0), self.cols - 1)
            
            self.currentRow = row + 1
            self.currentCol = newCol
            
            self.step()
        }
    }
    
    private func finishDrop() {
        isDropping = false
        
        guard let col = currentCol, col < slots.count else { return }
        let slot = slots[col]
        
        let baseWin = betAmount * slot.multiplier
        appManager?.applyWin(amount: baseWin)
        let moodMult = appManager?.currentMood.multiplier ?? 1.0
        lastWin = baseWin * moodMult - betAmount
        balance = appManager?.balance ?? balance
    }
}

struct PlinkoView: View {
    @ObservedObject var manager: AppManager
    @StateObject private var viewModel = PlinkoViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: manager.currentMood.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                header
                board
                controls
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Plinko Drop")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.appManager = manager
            viewModel.balance = manager.balance
            viewModel.setup()
        }
        .onChange(of: manager.balance) { newValue in
            viewModel.balance = newValue
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(viewModel.balance)) coins")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Bet")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(viewModel.betAmount)) coins")
                        .font(.title2.bold())
                        .foregroundColor(.yellow)
                }
            }
            
            if viewModel.lastWin > 0 {
                Text("Last win +\(Int(viewModel.lastWin)) coins")
                    .font(.headline.bold())
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
            }
        }
    }
    
    private var board: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            let colSpacing = width / CGFloat(viewModel.cols + 1)
            let rowSpacing = height / CGFloat(viewModel.rows + 2)
            
            ZStack {
                ForEach(0..<viewModel.rows, id: \.self) { row in
                    ForEach(0..<viewModel.cols, id: \.self) { col in
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 10, height: 10)
                            .position(
                                x: colSpacing * CGFloat(col + 1),
                                y: rowSpacing * CGFloat(row + 1)
                            )
                    }
                }
                
                if let row = viewModel.currentRow, let col = viewModel.currentCol {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 18, height: 18)
                        .shadow(color: .yellow.opacity(0.7), radius: 8)
                        .position(
                            x: colSpacing * CGFloat(col + 1),
                            y: rowSpacing * CGFloat(row + 1)
                        )
                        .animation(.easeInOut(duration: 0.1), value: row)
                        .animation(.easeInOut(duration: 0.1), value: col)
                }
                
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.slots.enumerated()), id: \.offset) { index, slot in
                        VStack {
                            Text(String(format: "x%.1f", slot.multiplier))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.6))
                                )
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 20)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal)
            }
        }
        .frame(height: 280)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.25), lineWidth: 1.5)
                )
        )
    }
    
    private var controls: some View {
        VStack(spacing: 12) {
            Button(viewModel.isDropping ? "Dropping..." : "Drop Ball") {
                viewModel.drop()
            }
            .font(.title3.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(viewModel.canDrop ? Color.green : Color.gray.opacity(0.5))
            )
            .disabled(!viewModel.canDrop)
        }
        .padding(.horizontal, 20)
    }
}

enum NumberHandType: String {
    case highCard = "High Card"
    case onePair = "One Pair"
    case twoPair = "Two Pairs"
    case threeKind = "Three of a Kind"
    case straight = "Straight"
    case fullHouse = "Full House"
    case fourKind = "Four of a Kind"
    case fiveKind = "Five of a Kind"
    
    var multiplier: Double {
        switch self {
        case .highCard: return 0.2
        case .onePair: return 1.0
        case .twoPair: return 2.0
        case .threeKind: return 3.0
        case .straight: return 4.0
        case .fullHouse: return 5.0
        case .fourKind: return 8.0
        case .fiveKind: return 12.0
        }
    }
}

@MainActor
class NumberMatchViewModel: ObservableObject {
    @Published var numbers: [Int] = []
    @Published var handType: NumberHandType? = nil
    @Published var betAmount: Double = 10
    @Published var lastWin: Double = 0
    @Published var balance: Double = 1000
    @Published var isDealing = false
    
    weak var appManager: AppManager?
    
    var canDeal: Bool { !isDealing && balance >= betAmount }
    
    func deal() {
        guard canDeal else { return }
        isDealing = true
        lastWin = 0
        handType = nil
        
        appManager?.applyBet(amount: betAmount)
        balance = appManager?.balance ?? balance
        
        withAnimation(.spring()) {
            numbers = (0..<5).map { _ in Int.random(in: 1...9) }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.evaluate()
            self.isDealing = false
        }
    }
    
    private func evaluate() {
        guard numbers.count == 5 else { return }
        
        let sorted = numbers.sorted()
        var counts: [Int: Int] = [:]
        sorted.forEach { counts[$0, default: 0] += 1 }
        let freq = counts.values.sorted(by: >) // например [3,2] или [2,2,1]
        
        let isStraight: Bool = {
            let unique = Array(Set(sorted)).sorted()
            guard unique.count == 5 else { return false }
            return unique.last! - unique.first! == 4
        }()
        
        let type: NumberHandType
        
        if freq == [5] {
            type = .fiveKind
        } else if freq == [4,1] {
            type = .fourKind
        } else if freq == [3,2] {
            type = .fullHouse
        } else if isStraight {
            type = .straight
        } else if freq == [3,1,1] {
            type = .threeKind
        } else if freq == [2,2,1] {
            type = .twoPair
        } else if freq == [2,1,1,1] {
            type = .onePair
        } else {
            type = .highCard
        }
        
        handType = type
        
        let baseWin = betAmount * type.multiplier
        appManager?.applyWin(amount: baseWin)
        let moodMult = appManager?.currentMood.multiplier ?? 1.0
        lastWin = baseWin * moodMult - betAmount
        balance = appManager?.balance ?? balance
    }
}

struct NumberMatchView: View {
    @ObservedObject var manager: AppManager
    @StateObject private var viewModel = NumberMatchViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: manager.currentMood.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                header
                numbersRow
                handInfo
                controls
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Number Match")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.appManager = manager
            viewModel.balance = manager.balance
        }
        .onChange(of: manager.balance) { newValue in
            viewModel.balance = newValue
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(viewModel.balance)) coins")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Bet")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(viewModel.betAmount)) coins")
                        .font(.title2.bold())
                        .foregroundColor(.yellow)
                }
            }
            
            if viewModel.lastWin > 0 {
                Text("Last win +\(Int(viewModel.lastWin)) coins")
                    .font(.headline.bold())
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
            }
        }
    }
    
    private var numbersRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { index in
                let value = index < viewModel.numbers.count ? viewModel.numbers[index] : 0
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        )
                    Text(value == 0 ? "-" : "\(value)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 56, height: 72)
            }
        }
    }
    
    private var handInfo: some View {
        VStack(spacing: 4) {
            if let hand = viewModel.handType {
                Text(hand.rawValue)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text(String(format: "Payout x%.1f", hand.multiplier))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("Press DEAL to draw numbers")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("-5") {
                    viewModel.betAmount = max(5, viewModel.betAmount - 5)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.2))
                )
                
                Button(viewModel.isDealing ? "Dealing..." : "Deal") {
                    viewModel.deal()
                }
                .font(.title3.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(viewModel.canDeal ? Color.green : Color.gray.opacity(0.5))
                )
                .disabled(!viewModel.canDeal)
                
                Button("+5") {
                    viewModel.betAmount = min(500, viewModel.betAmount + 5)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.2))
                )
            }
        }
        .padding(.horizontal, 4)
    }
}
