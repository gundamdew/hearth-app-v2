# Hearth.

A calm household manager for two residents — **budget, pantry, meals and a shared cleaning rota** — built with Flutter, Riverpod, GoRouter and Cloud Firestore.

This repository is a refined continuation of [`gundamdew/hearth-app`](https://github.com/gundamdew/hearth-app). The original repository is untouched.

## What changed compared with the original

### Functional
- **Monthly budget.** Totals and category bars now cover a single month, with a month switcher. The overview shows "left to spend" against the sum of category limits, plus a per-day allowance.
- **Category management.** Add categories, edit limits and delete categories from the Budget tab. Bars follow the design rules: moss → amber (≥80%) → red (over limit).
- **Delete transactions**, with a confirmation step. Expenses and income share one timeline.
- **Safe "Mark cooked".** Ingredients are deducted inside a Firestore transaction. Quantities never go below zero, and a meal can't be deducted twice. You get a warning when ingredients are short, and **Undo** returns the stock.
- **Recipe deletion**, which also clears the recipe from upcoming planner days.
- **Faster planner seeding.** One query replaces 14 sequential reads at startup. Seeding errors no longer stop the app from launching.
- **Shopping list.** Generated automatically from low-stock items, with "Bought", "Mark all as bought" and "Copy list" (in the same format the paste importer understands).
- **Inventory.** Added Freezer and Laundry locations, location filters, item editing, undo after delete, and English keywords for auto-categorising pasted lists.
- **Fairer "Balance load".** Already-completed chores are counted. "Swap & new week" asks for confirmation first. Chores can be filtered by resident, and deleted chores can be restored.
- **Remembered sign-in.** The last resident stays signed in on the device (`shared_preferences`). PIN entry works from a physical keyboard and shakes on a wrong PIN.
- **Resident management.** Pick a personal colour, get a duplicate-name check, and rename someone without breaking their history (their chores and transactions are updated in the same batch). You can't delete yourself.
- Error handling for every Firestore write (`runSafely` shows a snackbar), plus loading and error states on every screen.

### Visual
- A shared component layer (`lib/widgets/common.dart`): `HearthCard`, `SectionLabel`, `PageHeader`, `ProgressLine` (animated), `UserAvatar`, `UserTag`, `EmptyState`.
- A cream gradient background. Libre Baskerville for headings, Instrument Sans for body text and DM Mono for every number, applied through `ThemeData`.
- Adaptive navigation: pill navigation on desktop, Material 3 `NavigationBar` on phones. Settings and "Switch resident" live in the account menu.
- Content width is capped at 1280 px. Every screen scrolls, so the layout no longer breaks on short windows.
- A redesigned welcome, resident picker and PIN pad; a planner with "Today" highlighting, cooked state and missing-ingredient warnings; and resident colours throughout.

## Getting started

```bash
flutter create . --project-name hearth   # regenerates android/ ios/ web icons/ windows/ (not stored in this repo)
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure                     # creates lib/firebase_options.dart (git-ignored)
flutter run -d chrome
```

See `lib/firebase_options.example.dart` if you prefer to fill the config in by hand.

## Firestore collections

| Collection | Fields |
|---|---|
| `users` | `name`, `pinCode`, `color` |
| `budget_categories` | `name`, `limit` |
| `budget_transactions` | `type` (`expense`/`income`), `title`, `amount`, `category`, `date`, `assignee` |
| `inventory` | `name`, `location`, `quantity`, `unit`, `lowStockThreshold` |
| `recipes` | `name`, `prepTime`, `ingredients[{inventoryId, name, quantity}]` |
| `meal_plans` | doc id `yyyy-MM-dd`, `date`, `recipeId`, `isCooked` |
| `chores` | `name`, `category`, `assignee`, `isDone` |

## Project structure

```
lib/
  main.dart            app shell, router, adaptive navigation
  theme.dart           palette, typography, budget colour logic
  widgets/common.dart  shared UI components and helpers
  models/              plain data classes with Firestore mapping
  providers/           Riverpod streams + controllers (all Firestore writes)
  screens/             overview, budget, inventory, meals, cleaning, settings, login
test/logic_test.dart   unit tests for settlement, budget colours, stock, user mapping
```
