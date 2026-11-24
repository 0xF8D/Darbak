// دربك — © 0xF8D
//
// السعرات: حاسبة + مكوناتي (سعرات كل منتج) + طبخاتي (وجبة وحدة أو مجموعة تنقسم على أيام/وجبات) + سجل اليوم.
// كل شي يتخزن على الجوال (ملف JSON) وما يحتاج نت.

import Foundation

enum FoodUnit: String, Codable, CaseIterable, Identifiable {
    case ml, g, piece
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ml: return "مل"
        case .g: return "جرام"
        case .piece: return "حبة"
        }
    }
}

struct Ingredient: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var unit: FoodUnit
    var refAmount: Double   // مثلًا 100
    var refKcal: Double     // مثلًا 200

    func kcal(for amount: Double) -> Double {
        refAmount > 0 ? amount / refAmount * refKcal : 0
    }
}

struct RecipeItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var ingredientID: UUID
    var name: String
    var unit: FoodUnit
    var amount: Double
    var kcalSnapshot: Double  // احتياط لو انحذف المكون
}

enum RecipeKind: String, Codable, CaseIterable, Identifiable {
    case single, batch
    var id: String { rawValue }
    var title: String {
        switch self {
        case .single: return "وجبة وحدة"
        case .batch: return "مجموعة (تقسيم)"
        }
    }
}

struct Recipe: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var kind: RecipeKind
    var days: Int
    var meals: Int
    var items: [RecipeItem]
    var created = Date()
}

struct FoodLogEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var name: String
    var kcal: Double
}

enum Plan: String, Codable, CaseIterable, Identifiable {
    case cut, maintain, bulk
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cut: return "تنشيف −٥٠٠"
        case .maintain: return "ثبات"
        case .bulk: return "تضخيم +٥٠٠"
        }
    }
    var shortTitle: String {
        switch self {
        case .cut: return "تنشيف"
        case .maintain: return "ثبات"
        case .bulk: return "تضخيم"
        }
    }
    var delta: Double {
        switch self {
        case .cut: return -500
        case .maintain: return 0
        case .bulk: return 500
        }
    }
}

enum ActivityLevel: Int, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, high, extreme
    var id: Int { rawValue }
    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .high: return 1.725
        case .extreme: return 1.9
        }
    }
    var title: String {
        switch self {
        case .sedentary: return "قليل الحركة (دوام مكتبي)"
        case .light: return "خفيف (رياضة ١-٣ أيام)"
        case .moderate: return "متوسط (رياضة ٣-٥ أيام)"
        case .high: return "عالي (رياضة ٦-٧ أيام)"
        case .extreme: return "عالي جدًا (شغل بدني + رياضة)"
        }
    }
}

struct Profile: Codable, Equatable {
    var weight: Double
    var height: Double
    var age: Int
    var male: Bool
    var activity: ActivityLevel
    var plan: Plan

    /// معادلة Mifflin-St Jeor
    var bmr: Double {
        10 * weight + 6.25 * height - 5 * Double(age) + (male ? 5 : -161)
    }
    var tdee: Double { bmr * activity.factor }
    var target: Double { max(1_200, tdee + plan.delta) }
}

final class FoodStore: ObservableObject {
    static let shared = FoodStore()

    @Published var ingredients: [Ingredient] = [] { didSet { save() } }
    @Published var recipes: [Recipe] = [] { didSet { save() } }
    @Published var log: [FoodLogEntry] = [] { didSet { save() } }
    @Published var profile: Profile? = nil { didSet { save() } }

    private struct Payload: Codable {
        var ingredients: [Ingredient]
        var recipes: [Recipe]
        var log: [FoodLogEntry]
        var profile: Profile?
    }

    private let url: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("food.json")

    init() {
        guard let data = try? Data(contentsOf: url),
              let p = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-90 * 24 * 3600)
        ingredients = p.ingredients
        recipes = p.recipes
        log = p.log.filter { $0.date > cutoff }
        profile = p.profile
    }

    private func save() {
        let p = Payload(ingredients: ingredients, recipes: recipes, log: log, profile: profile)
        guard let data = try? JSONEncoder().encode(p) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Ingredients

    func upsert(_ ing: Ingredient) {
        if let i = ingredients.firstIndex(where: { $0.id == ing.id }) {
            ingredients[i] = ing
        } else {
            ingredients.append(ing)
        }
    }

    func delete(_ ing: Ingredient) {
        ingredients.removeAll { $0.id == ing.id }
    }

    func ingredient(_ id: UUID) -> Ingredient? {
        ingredients.first { $0.id == id }
    }

    // MARK: - Recipes

    func upsert(_ recipe: Recipe) {
        if let i = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[i] = recipe
        } else {
            recipes.insert(recipe, at: 0)
        }
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
    }

    func kcal(of item: RecipeItem) -> Double {
        if let ing = ingredient(item.ingredientID) { return ing.kcal(for: item.amount) }
        return item.kcalSnapshot
    }

    func total(_ r: Recipe) -> Double {
        r.items.reduce(0) { $0 + kcal(of: $1) }
    }

    func perMeal(_ r: Recipe) -> Double {
        r.kind == .single ? total(r) : total(r) / Double(max(r.meals, 1))
    }

    func perDay(_ r: Recipe) -> Double {
        r.kind == .single ? total(r) : total(r) / Double(max(r.days, 1))
    }

    // MARK: - Log

    func logMeal(_ r: Recipe) {
        log.append(FoodLogEntry(date: Date(), name: r.name, kcal: perMeal(r)))
    }

    func addLog(name: String, kcal: Double) {
        log.append(FoodLogEntry(date: Date(), name: name, kcal: kcal))
    }

    func deleteLog(_ e: FoodLogEntry) {
        log.removeAll { $0.id == e.id }
    }

    var todayLog: [FoodLogEntry] {
        let cal = AppCalendar.riyadh
        let t = AppCalendar.startOfToday()
        return log.filter { cal.startOfDay(for: $0.date) == t }.sorted { $0.date > $1.date }
    }

    var todayEaten: Double { todayLog.reduce(0) { $0 + $1.kcal } }
}
