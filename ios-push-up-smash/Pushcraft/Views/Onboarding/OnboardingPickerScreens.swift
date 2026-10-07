import SwiftUI

// MARK: - 07 Age

struct AgeScreen: View {
    @Bindable var model: OnboardingModel

    @State private var position: Int?
    private let ages = Array(13...100)
    private let rowHeight: CGFloat = 68

    var body: some View {
        OnboardingScaffold(title: "How old are you?", scrolls: false) {
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.amberSoft.opacity(0.1))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Theme.amberSoft.opacity(0.7), lineWidth: 1.5)
                        }
                        .frame(height: rowHeight)
                        .allowsHitTesting(false)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(ages, id: \.self) { age in
                                Text("\(age)")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(age == model.ageYears ? Theme.amberSoft : Theme.ivory)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                        content
                                            .scaleEffect(1 - abs(phase.value) * 0.35)
                                            .opacity(1 - abs(phase.value) * 0.7)
                                    }
                                    .id(age)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $position, anchor: .center)
                    .safeAreaPadding(.vertical, max(0, (proxy.size.height - rowHeight) / 2))
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.3),
                                .init(color: .black, location: 0.7),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            }
            .overlay(alignment: .trailing) {
                Text("years")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.mist)
                    .padding(.trailing, 36)
                    .allowsHitTesting(false)
            }
            .accessibilityElement()
            .accessibilityLabel("Age")
            .accessibilityValue("\(model.ageYears) years")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: position = min(model.ageYears + 1, ages.last ?? 100)
                case .decrement: position = max(model.ageYears - 1, ages.first ?? 13)
                @unknown default: break
                }
            }
        }
        .onAppear { position = model.ageYears }
        .onChange(of: position) { _, newValue in
            guard let newValue, newValue != model.ageYears else { return }
            model.ageYears = newValue
            HapticService.ui.tick()
        }
    }
}

// MARK: - 08 Height

struct HeightScreen: View {
    @Bindable var model: OnboardingModel

    @State private var position: Int?
    @State private var isEditing = false
    @State private var draftPrimary = ""
    @State private var draftSecondary = ""

    private let tickHeight: CGFloat = 12
    private static let cmRange = 50...250
    private static let inchRange = 20...98

    private var values: [Int] {
        let range = model.heightUnit == .cm ? Self.cmRange : Self.inchRange
        return Array(range.reversed())
    }

    private func unitValue(forCm cm: Double) -> Int {
        model.heightUnit == .cm ? Int(cm.rounded()) : Int((cm / 2.54).rounded())
    }

    private var displayText: (String, String) {
        if model.heightUnit == .cm {
            return ("\(Int(model.heightCm.rounded()))", "cm")
        }
        let inches = Int((model.heightCm / 2.54).rounded())
        return ("\(inches / 12)′ \(inches % 12)″", "")
    }

    var body: some View {
        OnboardingScaffold(title: "How tall are you?", helper: "Choose your preferred units.", scrolls: false) {
            VStack(spacing: 18) {
                unitToggle

                Button {
                    HapticService.ui.tap()
                    startEditing()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(displayText.0)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ivory)
                            .contentTransition(.numericText())
                        Text(displayText.1)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.mist)
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.amberSoft)
                            .padding(.leading, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.snappy, value: model.heightCm)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Height \(displayText.0) \(displayText.1). Tap to type.")

                ruler
            }
        }
        .onAppear { position = unitValue(forCm: model.heightCm) }
        .onChange(of: position) { _, newValue in
            guard let newValue, newValue != unitValue(forCm: model.heightCm) else { return }
            model.heightCm = model.heightUnit == .cm ? Double(newValue) : Double(newValue) * 2.54
            HapticService.ui.tick()
        }
        .alert("Enter your height", isPresented: $isEditing) {
            if model.heightUnit == .cm {
                TextField("Centimeters", text: $draftPrimary)
                    .keyboardType(.decimalPad)
            } else {
                TextField("Feet", text: $draftPrimary)
                    .keyboardType(.numberPad)
                TextField("Inches", text: $draftSecondary)
                    .keyboardType(.numberPad)
            }
            Button("Cancel", role: .cancel) {}
            Button("Save") { commitEdit() }
        } message: {
            Text(model.heightUnit == .cm ? "Between 50 and 250 cm." : "Between 1′ 8″ and 8′ 2″.")
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 4) {
            ForEach(HeightUnit.allCases, id: \.self) { unit in
                let isSelected = model.heightUnit == unit
                Button {
                    guard !isSelected else { return }
                    HapticService.ui.selection()
                    model.heightUnit = unit
                    position = unitValue(forCm: model.heightCm)
                } label: {
                    Text(unit.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Theme.buttonInk : Theme.mist)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if isSelected {
                                Capsule().fill(Theme.amberSoft)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.obCard, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.obCardBorder, lineWidth: 1) }
        .frame(maxWidth: 240)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.heightUnit)
    }

    private var ruler: some View {
        GeometryReader { proxy in
            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(values, id: \.self) { value in
                            RulerTick(value: value, unit: model.heightUnit)
                                .frame(height: tickHeight)
                                .id(value)
                        }
                    }
                    .scrollTargetLayout()
                }
                .id(model.heightUnit)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $position, anchor: .center)
                .safeAreaPadding(.vertical, max(0, (proxy.size.height - tickHeight) / 2))
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.25),
                            .init(color: .black, location: 0.75),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                HStack(spacing: 0) {
                    Circle()
                        .fill(Theme.gold)
                        .frame(width: 12, height: 12)
                    Capsule()
                        .fill(Theme.gold)
                        .frame(height: 3)
                }
                .shadow(color: Theme.gold.opacity(0.8), radius: 6)
                .padding(.horizontal, 30)
                .allowsHitTesting(false)
            }
        }
        .background(Theme.obCard.opacity(0.6), in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.obCardBorder, lineWidth: 1)
        }
        .accessibilityElement()
        .accessibilityLabel("Height ruler")
        .accessibilityValue("\(displayText.0) \(displayText.1)")
        .accessibilityAdjustableAction { direction in
            let current = unitValue(forCm: model.heightCm)
            switch direction {
            case .increment: position = min(current + 1, values.first ?? current)
            case .decrement: position = max(current - 1, values.last ?? current)
            @unknown default: break
            }
        }
    }

    private func startEditing() {
        if model.heightUnit == .cm {
            draftPrimary = "\(Int(model.heightCm.rounded()))"
            draftSecondary = ""
        } else {
            let inches = Int((model.heightCm / 2.54).rounded())
            draftPrimary = "\(inches / 12)"
            draftSecondary = "\(inches % 12)"
        }
        isEditing = true
    }

    private func commitEdit() {
        let cm: Double?
        if model.heightUnit == .cm {
            cm = Double(draftPrimary.replacingOccurrences(of: ",", with: "."))
        } else {
            let feet = Double(draftPrimary) ?? 0
            let inches = Double(draftSecondary) ?? 0
            let total = feet * 12 + inches
            cm = total > 0 ? total * 2.54 : nil
        }
        guard let cm, cm >= Double(Self.cmRange.lowerBound), cm <= Double(Self.cmRange.upperBound) else {
            HapticService.ui.warning()
            return
        }
        model.heightCm = cm
        position = unitValue(forCm: cm)
        HapticService.ui.success()
    }
}

private struct RulerTick: View {
    let value: Int
    let unit: HeightUnit

    private var isMajor: Bool { unit == .cm ? value % 10 == 0 : value % 12 == 0 }
    private var isMid: Bool { unit == .cm ? value % 5 == 0 : value % 6 == 0 }

    private var label: String {
        unit == .cm ? "\(value)" : "\(value / 12)′"
    }

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(.white.opacity(isMajor ? 0.9 : (isMid ? 0.55 : 0.3)))
                .frame(width: isMajor ? 64 : (isMid ? 44 : 26), height: isMajor ? 2.5 : 1.5)
            if isMajor {
                Text(label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.mist)
                    .fixedSize()
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 48)
    }
}

// MARK: - 17 Reminder

struct ReminderScreen: View {
    @Bindable var model: OnboardingModel
    @Environment(\.openURL) private var openURL

    private var isAlreadyDenied: Bool { model.isNotificationDenied }

    private var timezoneText: String {
        let zone = TimeZone.current
        let name = zone.localizedName(for: .generic, locale: .current) ?? zone.identifier
        return "Times use your local time zone (\(name))."
    }

    var body: some View {
        OnboardingScaffold(title: "Daily build reminder", helper: "What is the best time for you to build?") {
            VStack(spacing: 16) {
                Toggle(isOn: $model.remindersRequested.animation(.spring(response: 0.4, dampingFraction: 0.85))) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.amberSoft)
                            .frame(width: 40, height: 40)
                            .background(Theme.amberSoft.opacity(0.12), in: .rect(cornerRadius: 12, style: .continuous))
                        Text("Remind me")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ivory)
                    }
                }
                .tint(Theme.amberDeep)
                .padding(.horizontal, 16)
                .frame(minHeight: 68)
                .background(Theme.obCard, in: .rect(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.obCardBorder, lineWidth: 1)
                }
                .onChange(of: model.remindersRequested) { _, _ in
                    HapticService.ui.selection()
                    model.showDeniedMessage = false
                }

                if model.remindersRequested {
                    VStack(spacing: 4) {
                        DatePicker("Reminder time", selection: $model.reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(maxWidth: .infinity)
                            .onChange(of: model.reminderTime) { _, _ in
                                HapticService.ui.tick()
                            }

                        VStack(spacing: 6) {
                            Label(model.selectedDaysText, systemImage: "calendar")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.ivory)
                            Text(timezoneText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.mist)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 14)
                    }
                    .background(Theme.obCard.opacity(0.7), in: .rect(cornerRadius: 20, style: .continuous))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if model.showDeniedMessage || (model.remindersRequested && isAlreadyDenied) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Reminders are off. You can turn them on in Settings later.", systemImage: "bell.slash.fill")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ivory)
                        if isAlreadyDenied {
                            Button {
                                HapticService.ui.tap()
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            } label: {
                                Text("Open Settings")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.amberSoft)
                                    .frame(minHeight: 44)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0x3A1E12, opacity: 0.6), in: .rect(cornerRadius: 16, style: .continuous))
                    .transition(.opacity)
                }
            }
        }
        .task {
            let current = await NotificationService.shared.authorizationStatus()
            model.currentNotificationStatus = OnboardingModel.statusString(current)
        }
    }
}
