import SwiftUI

// MARK: - 03 Name

struct NameScreen: View {
    @Bindable var model: OnboardingModel

    @FocusState private var isFocused: Bool

    var body: some View {
        OnboardingScaffold(title: "What should we call you?") {
            TextField("", text: $model.name, prompt: Text("Your name").foregroundStyle(Theme.mist.opacity(0.6)))
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ivory)
                .tint(Theme.amberSoft)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($isFocused)
                .onSubmit { model.advance(to: .mainGoal) }
                .padding(.horizontal, 20)
                .frame(height: 64)
                .background(Theme.obCard, in: .rect(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isFocused ? Theme.amberSoft : Theme.obCardBorder, lineWidth: isFocused ? 2 : 1)
                }
                .animation(.easeOut(duration: 0.2), value: isFocused)
                .onChange(of: model.name) { _, newValue in
                    if newValue.count > 30 {
                        model.name = String(newValue.prefix(30))
                    }
                }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            isFocused = true
        }
    }
}

// MARK: - Single choice

struct SingleChoiceScreen<Choice: OnboardingChoice>: View {
    let title: String
    var helper: String?
    @Binding var selection: Choice?

    var body: some View {
        OnboardingScaffold(title: title, helper: helper) {
            OptionList(selection: $selection)
        }
    }
}

/// Staggered list of answer rows.
private struct OptionList<Choice: OnboardingChoice>: View {
    @Binding var selection: Choice?
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(Array(Choice.allCases).enumerated()), id: \.element) { index, choice in
                OnboardingOptionRow(title: choice.title, symbol: choice.symbol, isSelected: selection == choice) {
                    selection = choice
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 14)
                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.05), value: hasAppeared)
            }
        }
        .onAppear { hasAppeared = true }
    }
}

// MARK: - 10–12 Statements

struct StatementScreen: View {
    let title: String
    let statement: String
    @Binding var selection: Agreement?

    var body: some View {
        OnboardingScaffold(title: title) {
            VStack(spacing: 22) {
                StatementCard(text: statement)
                OptionList(selection: $selection)
            }
        }
    }
}

// MARK: - 16 Workout days

struct WorkoutDaysScreen: View {
    @Bindable var model: OnboardingModel

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var countText: String {
        let count = model.workoutDays.count
        return count == 1 ? "1 day each week" : "\(count) days each week"
    }

    var body: some View {
        OnboardingScaffold(
            title: "Which days would you like to build?",
            helper: "Choose a routine that works for you. You can change it later."
        ) {
            VStack(spacing: 18) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Weekday.allCases) { day in
                        DayChip(day: day, isSelected: model.workoutDays.contains(day.rawValue)) {
                            if model.workoutDays.contains(day.rawValue) {
                                model.workoutDays.remove(day.rawValue)
                            } else {
                                model.workoutDays.insert(day.rawValue)
                            }
                        }
                    }
                }

                Text(model.workoutDays.isEmpty ? "Pick at least one day" : countText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(model.workoutDays.isEmpty ? Theme.mist : Theme.amberSoft)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.workoutDays.count)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct DayChip: View {
    let day: Weekday
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.ui.selection()
            action()
        } label: {
            HStack(spacing: 10) {
                Text(day.short.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(isSelected ? Theme.buttonInk : Theme.amberSoft)
                    .frame(width: 44, height: 32)
                    .background(
                        isSelected ? AnyShapeStyle(Theme.amberSoft) : AnyShapeStyle(Theme.amberSoft.opacity(0.12)),
                        in: .rect(cornerRadius: 10, style: .continuous)
                    )
                Text(day.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 60)
            .background(
                isSelected ? Theme.amberSoft.opacity(0.12) : Theme.obCard.opacity(0.85),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Theme.amberSoft : Theme.obCardBorder, lineWidth: isSelected ? 2 : 1)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(day.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
