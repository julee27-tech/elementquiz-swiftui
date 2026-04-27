// ============================================================
//  ElementQuiz — SwiftUI Rebuild
//  Philbert.io · iOS Modernisation Sprint
//
//  HOW TO USE:
//  1. Create a new SwiftUI project in Xcode
//  2. Replace ContentView.swift with this file
//     (or paste each marked section into its own file)
//  3. Add element images (Carbon, Gold, Chlorine, Sodium)
//     to your Asset Catalog
// ============================================================


import SwiftUI


// ============================================================
// MARK: - 1. MODEL
// ============================================================
// A plain Swift struct — no UIKit, no SwiftUI.
// Structs are value types: safe, predictable, and easy to test.
// Keeping the model free of framework imports means you can
// reuse it anywhere — a widget, a watchOS app, a unit test.

struct Element: Identifiable {
    let id   = UUID()    // Identifiable lets SwiftUI track items in ForEach
    let name: String

    /// Derived property — the image asset name matches the element name.
    /// "Derived" data is never stored, it's computed on demand.
    var imageName: String { name }
}


// ============================================================
// MARK: - 2. VIEW MODEL
// ============================================================
// In the original Storyboard app, ViewController mixed UI outlets,
// data, and logic all in one class. Here we separate concerns:
//
//   ViewModel  → owns data and quiz logic
//   View       → reads state, sends user actions back
//
// ObservableObject tells SwiftUI "this object can broadcast changes".
// Any view that holds a reference to it will automatically re-render
// when a @Published property changes — no updateElement() calls needed.

class QuizViewModel: ObservableObject {

    // MARK: Published State
    //
    // @Published is SwiftUI's reactive property wrapper.
    // Changing currentIndex triggers every view reading it to refresh.
    // This replaces the pattern of:
    //   currentElementIndex += 1
    //   updateElement()

    @Published var currentIndex: Int  = 0
    @Published var isRevealed:   Bool = false

    // MARK: Data
    // Kept in the ViewModel (not the View) so we can swap the data
    // source later (e.g. load from JSON) without touching any UI code.

    let elements: [Element] = [
        Element(name: "Carbon"),
        Element(name: "Gold"),
        Element(name: "Chlorine"),
        Element(name: "Sodium")
    ]

    // MARK: Computed Properties
    // Views read these — they never touch the array directly.
    // This is the "single source of truth" pattern.

    var currentElement: Element {
        elements[currentIndex]
    }

    var progressText: String {
        "\(currentIndex + 1) of \(elements.count)"
    }

    // MARK: Actions
    // User interactions become plain functions.
    // The View calls these; it doesn't contain any logic itself.
    // This makes the ViewModel easy to unit-test in isolation.

    func revealAnswer() {
        isRevealed = true
    }

    func nextElement() {
        // Modulo wraps the index back to 0 at the end of the list.
        // This replaces the if/else guard in the original:
        //   if currentElementIndex >= elementList.count {
        //       currentElementIndex = 0
        //   }
        currentIndex = (currentIndex + 1) % elements.count

        // Reset revealed state for the new element.
        // Co-located here so it's impossible to forget — no separate
        // updateElement() call required.
        isRevealed = false
    }
}


// ============================================================
// MARK: - 3. ROOT VIEW (ContentView)
// ============================================================
// @StateObject means ContentView OWNS this ViewModel instance.
// SwiftUI creates it once and keeps it alive for the view's lifetime.
//
// Rule of thumb:
//   @StateObject  → the view that CREATES the object
//   @ObservedObject → views that RECEIVE the object from a parent

struct ContentView: View {

    @StateObject private var viewModel = QuizViewModel()

    var body: some View {
        // VStack is the vertical equivalent of a UIStackView.
        // Unlike Storyboard, you never set explicit frames —
        // SwiftUI calculates layout from your modifiers.

        VStack(spacing: 24) {

            // Progress label — reads directly from the ViewModel.
            Text(viewModel.progressText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Element image card — a child view defined below.
            // Plain `let` parameter: ElementCardView only reads, not writes.
            ElementCardView(element: viewModel.currentElement)

            // Answer badge — uses @Binding so it can reveal the answer.
            // The $ prefix converts @Published var → Binding<Bool>.
            // Think of $ as "a live reference, not a copy".
            AnswerBadge(
                elementName: viewModel.currentElement.name,
                isRevealed:  $viewModel.isRevealed
            )

            // Button row — receives closures for each action.
            // This is the SwiftUI replacement for @IBAction.
            QuizButtonRow(
                onShowAnswer:    viewModel.revealAnswer,
                onNext:          viewModel.nextElement,
                isAnswerRevealed: viewModel.isRevealed
            )
        }
        .padding()
        // Animate the entire view when the current element changes.
        // SwiftUI handles the transition — no UIView.animate needed.
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
    }
}


// ============================================================
// MARK: - 4. ELEMENT CARD VIEW (Leaf Component)
// ============================================================
// A small, focused view for displaying the element image.
// It receives an Element and displays it — nothing more.
//
// Equivalent of:
//   let image = UIImage(named: elementName)
//   imageView.image = image
//
// But declarative: SwiftUI shows the right image automatically
// whenever `element` changes because the parent's @Published state
// changed — we never set imageView.image manually.

struct ElementCardView: View {

    let element: Element   // plain `let` — this view only reads

    var body: some View {
        Image(element.imageName)
            .resizable()                         // allow scaling
            .scaledToFit()                       // keep aspect ratio (like .scaleAspectFit)
            .frame(maxWidth: .infinity, maxHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .transition(.opacity)                // fade when element changes
    }
}


// ============================================================
// MARK: - 5. ANSWER BADGE (Binding Example)
// ============================================================
// Demonstrates @Binding — the two-way connection between parent and child.
//
// The parent (ContentView) owns isRevealed via the ViewModel.
// This view receives a Binding<Bool> and can both READ and WRITE it.
//
// This replaces the pair:
//   @IBOutlet weak var answerLabel: UILabel!
//   @IBAction func showAnswer(_ sender: Any) { ... }
//
// No wiring in Interface Builder — the connection is expressed in code.

struct AnswerBadge: View {

    let elementName: String

    // @Binding = "I don't own this value, but I can change it"
    // The parent passes $viewModel.isAnswerRevealed (note the $)
    @Binding var isRevealed: Bool

    var body: some View {
        // Ternary operator maps state → display inline.
        // This is the declarative style: describe what to show
        // for each state, let SwiftUI handle the transition.
        Text(isRevealed ? elementName : "?")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(isRevealed ? .primary : .secondary)
            .frame(height: 60)
            .animation(.spring(response: 0.3), value: isRevealed)
    }
}


// ============================================================
// MARK: - 6. QUIZ BUTTON ROW (Action Closures)
// ============================================================
// Receives action closures from the parent.
// This is the SwiftUI equivalent of @IBAction, but composable:
// the button row has no knowledge of the ViewModel at all —
// it just fires whichever closure it was given.
//
// () -> Void is a Swift function type meaning:
//   "a function that takes no arguments and returns nothing"

struct QuizButtonRow: View {

    let onShowAnswer:      () -> Void
    let onNext:            () -> Void
    let isAnswerRevealed:  Bool

    var body: some View {
        HStack(spacing: 16) {

            // .disabled() is the declarative equivalent of:
            //   button.isEnabled = false
            // SwiftUI evaluates it on every render — always in sync.
            Button("Show Answer", action: onShowAnswer)
                .buttonStyle(.bordered)
                .disabled(isAnswerRevealed)

            Button("Next →", action: onNext)
                .buttonStyle(.borderedProminent)
        }
    }
}


// ============================================================
// MARK: - 7. APP ENTRY POINT
// ============================================================
// @main replaces AppDelegate for simple apps.
// WindowGroup creates the correct window for each platform
// (iPhone, iPad, Mac Catalyst) automatically.
//
// Equivalent of application(_:didFinishLaunchingWithOptions:)
// setting the rootViewController.

@main
struct ElementQuizApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


// ============================================================
// MARK: - PREVIEW
// ============================================================
// Previews let you see your UI in Xcode's canvas without
// running the simulator. You can preview any view in isolation.

#Preview {
    ContentView()
}
