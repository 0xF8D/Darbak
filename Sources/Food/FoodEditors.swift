// دربك — © 0xF8D

import SwiftUI

// MARK: - مكون جديد / تعديل

struct IngredientEditor: View {
    @EnvironmentObject var food: FoodStore
    @Environment(\.dismiss) var dismiss

    let original: Ingredient
    var onSaved: ((Ingredient) -> Void)? = nil

    @State var name: String
    @State var unit: FoodUnit
    @State var amountText: String
    @State var kcalText: String

    init(ingredient: Ingredient, onSaved: ((Ingredient) -> Void)? = nil) {
        original = ingredient
        self.onSaved = onSaved
        _name = State(initialValue: ingredient.name)
        _unit = State(initialValue: ingredient.unit)
        _amountText = State(initialValue: Num.string(ingredient.refAmount))
        _kcalText = State(initialValue: ingredient.refKcal > 0 ? Num.string(ingredient.refKcal) : "")
    }

    private var isNew: Bool { food.ingredient(original.id) == nil }
    private var amount: Double? { Num.parse(amountText).flatMap { $0 > 0 ? $0 : nil } }
    private var kcal: Double? { Num.parse(kcalText) }
    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount != nil && kcal != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        InputField(title: "اسم المكون", text: $name, placeholder: "مثلًا: كريمة طبخ")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("الوحدة")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.text2)
                            Picker("", selection: $unit) {
                                ForEach(FoodUnit.allCases) { u in
                                    Text(u.title).tag(u)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack(spacing: 12) {
                            InputField(title: "الكمية", text: $amountText, placeholder: "100",
                                       keyboard: .decimalPad, suffix: unit.title)
                            Text("=")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Palette.text2)
                                .padding(.top, 22)
                            InputField(title: "السعرات", text: $kcalText, placeholder: "200",
                                       keyboard: .decimalPad, suffix: "سعرة")
                        }

                        if let a = amount, let k = kcal {
                            let perOne = k / a
                            VStack(alignment: .leading, spacing: 6) {
                                Text("كل ١ \(unit.title) = \(Fmt.dec(perOne)) سعرة")
                                Text("يعني ١٠ \(unit.title) = \(Fmt.num(perOne * 10)) سعرة")
                            }
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.orange)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(radius: 16, tint: Palette.orange)
                        }
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isNew ? "مكون جديد" : "تعديل المكون")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("احفظ") { save() }
                        .fontWeight(.bold)
                        .disabled(!valid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") { hideKeyboard() }
                }
            }
        }
    }

    private func save() {
        guard let a = amount, let k = kcal else { return }
        var ing = original
        ing.name = name.trimmingCharacters(in: .whitespaces)
        ing.unit = unit
        ing.refAmount = a
        ing.refKcal = k
        food.upsert(ing)
        onSaved?(ing)
        dismiss()
    }
}

// MARK: - طبخة جديدة / تعديل

struct RecipeEditor: View {
    @EnvironmentObject var food: FoodStore
    @Environment(\.dismiss) var dismiss

    @State var recipe: Recipe
    @State var addingItem = false
    private let isNew: Bool

    init(recipe: Recipe) {
        _recipe = State(initialValue: recipe)
        isNew = recipe.name.isEmpty && recipe.items.isEmpty
    }

    private var valid: Bool {
        !recipe.name.trimmingCharacters(in: .whitespaces).isEmpty && !recipe.items.isEmpty
    }

    var body: some View {
        let total = food.total(recipe)

        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        InputField(title: "اسم الطبخة", text: $recipe.name, placeholder: "مثلًا: باستا بالكريمة")

                        Picker("", selection: $recipe.kind) {
                            ForEach(RecipeKind.allCases) { k in
                                Text(k.title).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)

                        if recipe.kind == .batch {
                            VStack(spacing: 12) {
                                Stepper(value: $recipe.days, in: 1...30) {
                                    stepperLabel("عدد الأيام", recipe.days)
                                }
                                Divider().overlay(Color.white.opacity(0.08))
                                Stepper(value: $recipe.meals, in: 1...90) {
                                    stepperLabel("عدد الوجبات", recipe.meals)
                                }
                            }
                            .padding(16)
                            .glassCard(tint: Palette.violet)
                        }

                        itemsCard

                        totalsCard(total)
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isNew ? "طبخة جديدة" : "تعديل الطبخة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("احفظ") { save() }
                        .fontWeight(.bold)
                        .disabled(!valid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") { hideKeyboard() }
                }
            }
        }
        .onChange(of: recipe.kind) { _, new in
            if new == .batch && recipe.meals == 1 && recipe.days == 1 {
                recipe.days = 3
                recipe.meals = 6
            }
        }
        .sheet(isPresented: $addingItem) {
            AddItemSheet { item in
                recipe.items.append(item)
            }
            .appEnvironment()
        }
    }

    private func stepperLabel(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Palette.text2)
            Spacer()
            Text(Fmt.num(value))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.trailing, 8)
        }
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("المكونات")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    hideKeyboard()
                    addingItem = true
                } label: {
                    Label("ضيف مكون", systemImage: "plus")
                }
                .buttonStyle(SoftButtonStyle(color: Palette.cyan))
            }
            .padding(.bottom, 10)

            if recipe.items.isEmpty {
                Text("ما فيه مكونات، اضغط «ضيف مكون».")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.text3)
            } else {
                ForEach(recipe.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(Num.string(item.amount)) \(item.unit.title)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Palette.text2)
                        }
                        Spacer()
                        Text("\(Fmt.num(food.kcal(of: item))) سعرة")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.orange)
                        Button {
                            recipe.items.removeAll { $0.id == item.id }
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

    private func totalsCard(_ total: Double) -> some View {
        VStack(spacing: 12) {
            row("مجموع الطبخة", total, Palette.orange, big: recipe.kind == .single)
            if recipe.kind == .batch {
                Divider().overlay(Color.white.opacity(0.1))
                row("الوجبة الوحدة (من \(Fmt.num(recipe.meals)))", total / Double(max(recipe.meals, 1)), Palette.green, big: true)
                row("اليوم الواحد (من \(Fmt.num(recipe.days)))", total / Double(max(recipe.days, 1)), Palette.cyan, big: false)
                let perDayMeals = Double(recipe.meals) / Double(max(recipe.days, 1))
                Text("يعني تقريبًا \(Fmt.dec(perDayMeals)) وجبة باليوم")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .glassCard(tint: Palette.orange)
    }

    private func row(_ title: String, _ value: Double, _ color: Color, big: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: big ? .bold : .regular, design: .rounded))
                .foregroundStyle(big ? Color.white : Palette.text2)
            Spacer()
            Text("\(Fmt.num(value)) سعرة")
                .font(.system(size: big ? 24 : 17, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func save() {
        recipe.name = recipe.name.trimmingCharacters(in: .whitespaces)
        if recipe.kind == .single {
            recipe.days = 1
            recipe.meals = 1
        }
        food.upsert(recipe)
        dismiss()
    }
}

// MARK: - إضافة مكون للطبخة

struct AddItemSheet: View {
    @EnvironmentObject var food: FoodStore
    @Environment(\.dismiss) var dismiss
    var onAdd: (RecipeItem) -> Void

    @State var search = ""
    @State var selectedID: UUID?
    @State var amountText = ""
    @State var newIngredient: Ingredient?

    private var selected: Ingredient? { selectedID.flatMap { food.ingredient($0) } }
    private var amount: Double? { Num.parse(amountText).flatMap { $0 > 0 ? $0 : nil } }

    private var filtered: [Ingredient] {
        let q = search.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return food.ingredients }
        return food.ingredients.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let ing = selected {
                            amountCard(ing)
                        }

                        HStack(spacing: 10) {
                            InputField(title: "دوّر", text: $search, placeholder: "اسم المكون")
                            Button {
                                newIngredient = Ingredient(name: search, unit: .ml, refAmount: 100, refKcal: 0)
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(SoftButtonStyle(color: Palette.cyan))
                            .padding(.top, 22)
                        }

                        if food.ingredients.isEmpty {
                            emptyHint("ما عندك مكونات محفوظة. اضغط + وسجّل أول مكون (مثلًا كريمة طبخ ١٠٠ مل = ٢٠٠ سعرة).")
                        }

                        ForEach(filtered) { ing in
                            Button {
                                Haptics.tap()
                                selectedID = ing.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ing.name)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("\(Num.string(ing.refAmount)) \(ing.unit.title) = \(Fmt.num(ing.refKcal)) سعرة")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(Palette.text2)
                                    }
                                    Spacer()
                                    Image(systemName: selectedID == ing.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedID == ing.id ? Palette.green : Palette.text3)
                                        .font(.system(size: 20))
                                }
                                .padding(14)
                                .glassCard(radius: 16, tint: selectedID == ing.id ? Palette.green : Palette.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("ضيف مكون")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") { hideKeyboard() }
                }
            }
        }
        .sheet(item: $newIngredient) { ing in
            IngredientEditor(ingredient: ing) { saved in
                selectedID = saved.id
            }
            .appEnvironment()
        }
    }

    private func amountCard(_ ing: Ingredient) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ing.name)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            InputField(title: "كم حطيت؟", text: $amountText, placeholder: "10",
                       keyboard: .decimalPad, suffix: ing.unit.title)
            if let a = amount {
                Text("\(Num.string(a)) \(ing.unit.title) = \(Fmt.num(ing.kcal(for: a))) سعرة")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.orange)
            }
            Button("ضيفه للطبخة") {
                guard let a = amount else { return }
                onAdd(RecipeItem(ingredientID: ing.id, name: ing.name, unit: ing.unit,
                                 amount: a, kcalSnapshot: ing.kcal(for: a)))
                Haptics.tap()
                dismiss()
            }
            .buttonStyle(NeonButtonStyle(colors: [Palette.green, Palette.cyan]))
            .disabled(amount == nil)
            .opacity(amount == nil ? 0.5 : 1)
        }
        .padding(16)
        .glassCard(tint: Palette.green)
    }
}

// MARK: - تسجيل سريع

struct QuickAddSheet: View {
    @EnvironmentObject var food: FoodStore
    @Environment(\.dismiss) var dismiss
    @State var name = ""
    @State var kcalText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 14) {
                    InputField(title: "وش أكلت؟ (اختياري)", text: $name, placeholder: "مثلًا: سناك")
                    InputField(title: "السعرات", text: $kcalText, placeholder: "250",
                               keyboard: .numberPad, suffix: "سعرة")
                    Button("سجّل") {
                        guard let k = Num.parse(kcalText), k > 0 else { return }
                        food.addLog(name: name.trimmingCharacters(in: .whitespaces), kcal: k)
                        Haptics.tap()
                        dismiss()
                    }
                    .buttonStyle(NeonButtonStyle(colors: [Palette.orange, Palette.pink]))
                    .disabled(Num.parse(kcalText) == nil)
                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("سجّل سعرات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
    }
}
