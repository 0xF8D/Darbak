// دربك — © 0xF8D

import SwiftUI

enum FoodSection: String, CaseIterable, Identifiable {
    case today = "اليوم"
    case water = "مويتي"
    case recipes = "طبخاتي"
    case ingredients = "مكوناتي"
    case calculator = "حاسبتي"
    var id: String { rawValue }
}

struct CaloriesView: View {
    @EnvironmentObject var food: FoodStore
    @State var section: FoodSection = .today
    @State var editingIngredient: Ingredient?
    @State var editingRecipe: Recipe?
    @State var showQuickAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenTitle(title: "السعرات")

                        Picker("", selection: $section) {
                            ForEach(FoodSection.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch section {
                        case .today:
                            TodayFoodSection(section: $section, showQuickAdd: $showQuickAdd)
                        case .water:
                            WaterSection()
                        case .recipes:
                            RecipesSection(editingRecipe: $editingRecipe)
                        case .ingredients:
                            IngredientsSection(editingIngredient: $editingIngredient)
                        case .calculator:
                            CalculatorSection()
                        }
                    }
                    .padding(.horizontal, 18)
                    .screenWidth()
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") { hideKeyboard() }
                }
            }
        }
        .sheet(item: $editingIngredient) { ing in
            IngredientEditor(ingredient: ing)
                .appEnvironment()
        }
        .sheet(item: $editingRecipe) { r in
            RecipeEditor(recipe: r)
                .appEnvironment()
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
                .appEnvironment()
                .presentationDetents([.medium])
        }
    }
}

// MARK: - اليوم

struct TodayFoodSection: View {
    @EnvironmentObject var food: FoodStore
    @Binding var section: FoodSection
    @Binding var showQuickAdd: Bool

    var body: some View {
        let eaten = food.todayEaten
        VStack(alignment: .leading, spacing: 16) {
            if let profile = food.profile {
                targetCard(profile: profile, eaten: eaten)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("احسب سعراتك أول")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("حط وزنك وطولك ونشاطك، ونطلع لك هدفك اليومي (تنشيف أو ثبات أو تضخيم).")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.text2)
                    Button("افتح الحاسبة") { section = .calculator }
                        .buttonStyle(NeonButtonStyle())
                }
                .padding(16)
                .glassCard()
                if eaten > 0 {
                    Text("أكلت اليوم: \(Fmt.num(eaten)) سعرة")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.orange)
                }
            }

            Button {
                showQuickAdd = true
            } label: {
                Label("سجل سعرات", systemImage: "plus")
            }
            .buttonStyle(NeonButtonStyle(colors: [Palette.orange, Palette.pink]))

            if !food.recipes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("أكلت من طبخاتي")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(food.recipes) { r in
                                Button {
                                    Haptics.tap()
                                    food.logMeal(r)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(r.name)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text("+ \(Fmt.num(food.perMeal(r))) سعرة")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(Palette.orange)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .glassCard(radius: 14, tint: Palette.orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("سجل اليوم")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 10)
                if food.todayLog.isEmpty {
                    Text("ما سجلت شي اليوم.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.text3)
                } else {
                    ForEach(food.todayLog) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name.isEmpty ? "سعرات" : e.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(Fmt.time(e.date))
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Palette.text3)
                            }
                            Spacer()
                            Text("\(Fmt.num(e.kcal)) سعرة")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.orange)
                            Button {
                                food.deleteLog(e)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Palette.text3)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 6)
                        }
                        .padding(.vertical, 9)
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    private func targetCard(profile: Profile, eaten: Double) -> some View {
        let target = profile.target
        let remaining = target - eaten
        let p = min(eaten / max(target, 1), 1)
        let over = remaining < 0
        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("هدفك اليومي · \(profile.plan.shortTitle)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.text2)
                    Text("\(Fmt.num(target)) سعرة")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(over ? "زيادة" : "باقي لك")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.text2)
                    Text(Fmt.num(abs(remaining)))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(over ? Palette.pink : Palette.green)
                        .shadow(color: (over ? Palette.pink : Palette.green).opacity(0.6), radius: 8)
                        .contentTransition(.numericText())
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: over ? [Palette.orange, Palette.pink] : [Palette.green, Palette.cyan],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(g.size.width * p, 6))
                }
            }
            .frame(height: 12)
            HStack {
                Text("أكلت \(Fmt.num(eaten))")
                Spacer()
                Text("\(Fmt.num(p * 100))٪")
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Palette.text2)
        }
        .padding(16)
        .glassCard(tint: over ? Palette.pink : Palette.green)
    }
}

// MARK: - طبخاتي

struct RecipesSection: View {
    @EnvironmentObject var food: FoodStore
    @Binding var editingRecipe: Recipe?
    @State var toDelete: Recipe?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                editingRecipe = Recipe(name: "", kind: .single, days: 1, meals: 1, items: [])
            } label: {
                Label("طبخة جديدة", systemImage: "plus")
            }
            .buttonStyle(NeonButtonStyle())

            if food.recipes.isEmpty {
                emptyHint("سو طبخة وحط مكوناتها بالكمية، ونحسب لك السعرات. لو طبخت كمية لأكثر من يوم اختر «مجموعة» ونقسمها لك على الأيام والوجبات.")
            }

            ForEach(food.recipes) { r in
                recipeCard(r)
            }
        }
        .confirmationDialog("تحذف الطبخة؟", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                            titleVisibility: .visible) {
            Button("حذف", role: .destructive) {
                if let r = toDelete { food.delete(r) }
                toDelete = nil
            }
            Button("إلغاء", role: .cancel) { toDelete = nil }
        }
    }

    private func recipeCard(_ r: Recipe) -> some View {
        let total = food.total(r)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(r.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(r.kind == .single ? "وجبة" : "مجموعة")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(r.kind == .single ? Palette.cyan : Palette.violet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((r.kind == .single ? Palette.cyan : Palette.violet).opacity(0.15), in: Capsule())
            }

            HStack(spacing: 10) {
                miniStat("المجموع", Fmt.num(total), Palette.orange)
                if r.kind == .batch {
                    miniStat("الوجبة (\(Fmt.num(r.meals)))", Fmt.num(food.perMeal(r)), Palette.green)
                    miniStat("اليوم (\(Fmt.num(r.days)))", Fmt.num(food.perDay(r)), Palette.cyan)
                }
            }

            Text(r.items.map { "\($0.name) \(Num.string($0.amount)) \($0.unit.title)" }.joined(separator: " · "))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.text3)
                .lineLimit(3)

            HStack(spacing: 8) {
                Button("أكلت وجبة") {
                    Haptics.tap()
                    food.logMeal(r)
                }
                .buttonStyle(SoftButtonStyle(color: Palette.green))
                Button("تعديل") { editingRecipe = r }
                    .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                Spacer()
                Button {
                    toDelete = r
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(SoftButtonStyle(color: Palette.pink))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func miniStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - مكوناتي

struct IngredientsSection: View {
    @EnvironmentObject var food: FoodStore
    @Binding var editingIngredient: Ingredient?
    @State var toDelete: Ingredient?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                editingIngredient = Ingredient(name: "", unit: .ml, refAmount: 100, refKcal: 0)
            } label: {
                Label("مكون جديد", systemImage: "plus")
            }
            .buttonStyle(NeonButtonStyle())

            if food.ingredients.isEmpty {
                emptyHint("سجل المنتجات اللي تطبخ فيها مرة وحدة. مثال: كريمة طبخ — ١٠٠ مل = ٢٠٠ سعرة. بعدين لما تحطها في طبخة بـ ١٠ مل يحسبها لك ٢٠ سعرة.")
            }

            ForEach(food.ingredients) { ing in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ing.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(Num.string(ing.refAmount)) \(ing.unit.title) = \(Fmt.num(ing.refKcal)) سعرة")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Palette.orange)
                    }
                    Spacer()
                    Button {
                        editingIngredient = ing
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                    Button {
                        toDelete = ing
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(SoftButtonStyle(color: Palette.pink))
                }
                .padding(14)
                .glassCard(radius: 18)
            }
        }
        .confirmationDialog("تحذف المكون؟", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                            titleVisibility: .visible) {
            Button("حذف", role: .destructive) {
                if let i = toDelete { food.delete(i) }
                toDelete = nil
            }
            Button("إلغاء", role: .cancel) { toDelete = nil }
        } message: {
            Text("الطبخات اللي فيها هذا المكون بتحتفظ بسعراته القديمة.")
        }
    }
}

// MARK: - حاسبتي

struct CalculatorSection: View {
    @EnvironmentObject var food: FoodStore
    @State var weight = ""
    @State var height = ""
    @State var age = ""
    @State var male = true
    @State var activity: ActivityLevel = .moderate
    @State var plan: Plan = .maintain
    @State var loaded = false
    @State var saved = false

    private var current: Profile? {
        guard let w = Num.parse(weight), let h = Num.parse(height), let a = Num.parse(age),
              w >= 25, w <= 350, h >= 100, h <= 250, a >= 10, a <= 100 else { return nil }
        return Profile(weight: w, height: h, age: Int(a), male: male, activity: activity, plan: plan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    InputField(title: "الوزن", text: $weight, placeholder: "75", keyboard: .decimalPad, suffix: "كجم")
                    InputField(title: "الطول", text: $height, placeholder: "172", keyboard: .numberPad, suffix: "سم")
                }
                HStack(alignment: .bottom, spacing: 12) {
                    InputField(title: "العمر", text: $age, placeholder: "25", keyboard: .numberPad, suffix: "سنة")
                    Picker("", selection: $male) {
                        Text("ذكر").tag(true)
                        Text("أنثى").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("نشاطك")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.text2)
                    Picker("", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { a in
                            Text(a.title).tag(a)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("لا تحسب المشي اليومي رياضة. لو دوامك مكتبي وتتمرن ٣ أيام، اختر «خفيف».")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.text3)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("هدفك")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.text2)
                    Picker("", selection: $plan) {
                        ForEach(Plan.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(16)
            .glassCard()

            if let p = current {
                VStack(spacing: 12) {
                    resultRow("سعرات الثبات", p.tdee, Palette.cyan)
                    Divider().overlay(Color.white.opacity(0.1))
                    HStack {
                        Text("هدفك اليومي (\(p.plan.shortTitle))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Fmt.num(p.target)) سعرة")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.green)
                            .shadow(color: Palette.green.opacity(0.6), radius: 8)
                    }
                }
                .padding(16)
                .glassCard(tint: Palette.green)

                Button(saved ? "انحفظ ✓" : "احفظه كهدفي") {
                    food.profile = p
                    saved = true
                    Haptics.tap()
                    hideKeyboard()
                }
                .buttonStyle(NeonButtonStyle(colors: [Palette.green, Palette.cyan]))
            } else {
                emptyHint("اكتب وزنك وطولك وعمرك عشان نحسب لك.")
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let p = food.profile {
                weight = Num.string(p.weight)
                height = Num.string(p.height)
                age = String(p.age)
                male = p.male
                activity = p.activity
                plan = p.plan
            }
        }
        .onChange(of: current) { _ in saved = false }
    }

    private func resultRow(_ title: String, _ value: Double, _ color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Palette.text2)
            Spacer()
            Text("\(Fmt.num(value)) سعرة")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

func emptyHint(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 13, design: .rounded))
        .foregroundStyle(Palette.text2)
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
}
