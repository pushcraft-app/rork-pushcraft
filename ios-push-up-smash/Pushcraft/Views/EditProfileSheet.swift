import SwiftUI
import PhotosUI

/// Edit Profile bottom sheet: photo (private storage, visible to battle
/// opponents), display name, and Save Changes. Canceling leaves it unchanged.
struct EditProfileSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draftName = ""
    @State private var draftPhoto: Data?
    @State private var photoChanged = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 40 && !isSaving
    }

    var body: some View {
        VStack(spacing: 0) {
            handle
            titleRow

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    photoPreview

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text("Change Photo")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ivory)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(.white.opacity(0.08), in: .capsule)
                            .overlay { Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
                    }
                    .buttonStyle(PressScaleStyle())
                    .onChange(of: photoItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                draftPhoto = data
                                photoChanged = true
                            }
                        }
                    }

                    if draftPhoto != nil {
                        Button {
                            draftPhoto = nil
                            photoItem = nil
                            photoChanged = true
                        } label: {
                            Text("Remove Photo")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.mist)
                        }
                        .buttonStyle(PressScaleStyle())
                    }

                    field(title: "NAME", text: $draftName, placeholder: "Your name")

                    Text("Battle opponents can see your name and photo.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mist.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFF8A8A))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GoldButton(title: "Save Changes", isLoading: isSaving) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                    } action: {
                        save()
                    }
                    .opacity(canSave ? 1 : 0.5)
                    .disabled(!canSave)

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.mist)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(PressScaleStyle())
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.night.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            draftName = appState.progress.displayName
            draftPhoto = appState.progress.avatarData
        }
    }

    // MARK: - Actions

    private func save() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await appState.progress.updateProfile(name: trimmedName, photo: draftPhoto, photoChanged: photoChanged)
                dismiss()
            } catch {
                print("[Profile] Save failed: \(error.localizedDescription)")
                errorMessage = BackendFailure.isOffline(error)
                    ? "You're offline. Connect to save your changes."
                    : "Couldn't save your profile. Please try again."
            }
        }
    }

    // MARK: - Pieces

    private var handle: some View {
        Capsule()
            .fill(.white.opacity(0.25))
            .frame(width: 40, height: 5)
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
    }

    private var titleRow: some View {
        HStack {
            Text("Edit Profile")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ivory)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.mist)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08), in: .circle)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var photoPreview: some View {
        Group {
            if let data = draftPhoto, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(
                            .linearGradient(
                                colors: [Color(hex: 0x33456B), Color(hex: 0x1C2A47)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Image(systemName: "person.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Theme.mist)
                }
            }
        }
        .frame(width: 116, height: 116)
        .clipShape(.circle)
        .overlay {
            Circle().strokeBorder(Theme.amberSoft, lineWidth: 2.5)
        }
    }

    private func field(
        title: String,
        text: Binding<String>,
        placeholder: String,
        prefix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Theme.mist)
            HStack(spacing: 4) {
                if let prefix {
                    Text(prefix)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.mist)
                }
                TextField(placeholder, text: text)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ivory)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .recessedFieldStyle()
        }
    }
}

#Preview {
    EditProfileSheet()
        .environment(AppState())
}
