import SwiftUI
import CoreData

struct ProfileEditorView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settingsManager: SettingsManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \UserProfile.id, ascending: true)]) private var userProfile: FetchedResults<UserProfile>

    @State private var heightString: String = ""
    @State private var gender: UserProfile.Gender = .male
    @State private var age: Int = 30
    @State private var goalWeightString: String = ""
    @State private var goalBodyFatString: String = ""
    @State private var goalWaistCircumferenceString: String = ""
    @State private var goalHipCircumferenceString: String = ""
    @State private var goalChestCircumferenceString: String = ""
    @State private var goalThighCircumferenceString: String = ""
    @State private var showingValidationAlert = false
    @State private var validationErrorMessage = ""

    private var existingProfile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }
    private var heightUnit: HeightUnit { settingsManager.heightUnit }
    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.height", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        HStack {
                            NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $heightString)
                            
                            Text(heightUnit.displayName)
                                .foregroundColor(.secondaryText)
                        }
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                        .background(inputBackgroundColor)
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.gender", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Picker(NSLocalizedString("settings.gender", comment: ""), selection: $gender) {
                            Text(NSLocalizedString("settings.male", comment: "")).tag(UserProfile.Gender.male)
                            Text(NSLocalizedString("settings.female", comment: "")).tag(UserProfile.Gender.female)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.age", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        HStack {
                            Text("\(age)")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                            
                            Stepper("", value: $age, in: 1...120)
                        }
                        .padding()
                        .background(inputBackgroundColor)
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.goal.weight", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        HStack {
                            NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalWeightString)
                            
                            Text(unit.shortName)
                                .foregroundColor(.secondaryText)
                        }
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                        .background(inputBackgroundColor)
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.goal.body.fat", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        HStack {
                            NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalBodyFatString)
                            
                            Text("%")
                                .foregroundColor(.secondaryText)
                        }
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                        .background(inputBackgroundColor)
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("settings.goal.measurements", comment: ""))
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text(NSLocalizedString("settings.goal.waist", comment: ""))
                                    .foregroundColor(.secondaryText)
                                Spacer()
                                NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalWaistCircumferenceString)
                                    .multilineTextAlignment(.trailing)
                                Text(NSLocalizedString("settings.cm", comment: ""))
                                    .foregroundColor(.secondaryText)
                            }
                            .frame(height: 50)
                            .padding(.horizontal, 16)
                            .background(inputBackgroundColor)
                            .cornerRadius(12)
                            
                            HStack {
                                Text(NSLocalizedString("settings.goal.hip", comment: ""))
                                    .foregroundColor(.secondaryText)
                                Spacer()
                                NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalHipCircumferenceString)
                                    .multilineTextAlignment(.trailing)
                                Text(NSLocalizedString("settings.cm", comment: ""))
                                    .foregroundColor(.secondaryText)
                            }
                            .frame(height: 50)
                            .padding(.horizontal, 16)
                            .background(inputBackgroundColor)
                            .cornerRadius(12)
                            
                            HStack {
                                Text(NSLocalizedString("settings.goal.chest", comment: ""))
                                    .foregroundColor(.secondaryText)
                                Spacer()
                                NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalChestCircumferenceString)
                                    .multilineTextAlignment(.trailing)
                                Text(NSLocalizedString("settings.cm", comment: ""))
                                    .foregroundColor(.secondaryText)
                            }
                            .frame(height: 50)
                            .padding(.horizontal, 16)
                            .background(inputBackgroundColor)
                            .cornerRadius(12)
                            
                            HStack {
                                Text(NSLocalizedString("settings.goal.thigh", comment: ""))
                                    .foregroundColor(.secondaryText)
                                Spacer()
                                NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalThighCircumferenceString)
                                    .multilineTextAlignment(.trailing)
                                Text(NSLocalizedString("settings.cm", comment: ""))
                                    .foregroundColor(.secondaryText)
                            }
                            .frame(height: 50)
                            .padding(.horizontal, 16)
                            .background(inputBackgroundColor)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: saveProfile) {
                        Text(NSLocalizedString("action.save", comment: ""))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.primaryBlue)
                            .cornerRadius(25)
                            .padding(.vertical, 20)
                    }
                }
                .padding()
            }
            .background(
                Color(.systemGroupedBackground)
                    .onTapGesture {
                        hideKeyboard()
                    }
            )
            .navigationTitle(NSLocalizedString("settings.profile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: backButton)
            .tabBarHidden(true)
            .alert(NSLocalizedString("settings.error", comment: ""), isPresented: $showingValidationAlert) {
                Button(NSLocalizedString("action.confirm", comment: ""), role: .cancel) {}
            } message: {
                Text(validationErrorMessage)
            }
            .onAppear {
                loadExistingProfile()
            }
    }

    private func loadExistingProfile() {
        if let profile = existingProfile {
            heightString = heightUnit.convertFromCm(profile.height).smartFormatted
            gender = profile.genderEnum
            age = Int(profile.age)
            goalWeightString = unit.convertFromKg(profile.goalWeight).smartFormatted
            goalBodyFatString = profile.goalBodyFatPercentage?.smartFormatted ?? ""
            goalWaistCircumferenceString = profile.goalWaistCircumferenceValue?.smartFormatted ?? ""
            goalHipCircumferenceString = profile.goalHipCircumferenceValue?.smartFormatted ?? ""
            goalChestCircumferenceString = profile.goalChestCircumferenceValue?.smartFormatted ?? ""
            goalThighCircumferenceString = profile.goalThighCircumferenceValue?.smartFormatted ?? ""
        }
    }

    private func saveProfile() {
        hideKeyboard()
        var errors: [String] = []
        
        if heightString.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(NSLocalizedString("settings.height.required", comment: ""))
        } else if let heightValue = Double(heightString), heightValue <= 0 {
            errors.append(NSLocalizedString("settings.height.invalid", comment: ""))
        }
        
        if goalWeightString.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(NSLocalizedString("settings.goal.weight.required", comment: ""))
        } else if let goalWeightValue = Double(goalWeightString), goalWeightValue <= 0 {
            errors.append(NSLocalizedString("settings.goal.weight.invalid", comment: ""))
        }
        
        if !goalBodyFatString.isEmpty {
            if let bodyFatValue = Double(goalBodyFatString), (bodyFatValue <= 0 || bodyFatValue >= 100) {
                errors.append(NSLocalizedString("settings.goal.body.fat.invalid", comment: ""))
            }
        }
        
        if !goalWaistCircumferenceString.isEmpty {
            if let waistValue = Double(goalWaistCircumferenceString), waistValue <= 0 {
                errors.append(NSLocalizedString("settings.goal.waist.circumference.invalid", comment: ""))
            }
        }
        
        if !goalHipCircumferenceString.isEmpty {
            if let hipValue = Double(goalHipCircumferenceString), hipValue <= 0 {
                errors.append(NSLocalizedString("settings.goal.hip.circumference.invalid", comment: ""))
            }
        }
        
        if !goalChestCircumferenceString.isEmpty {
            if let chestValue = Double(goalChestCircumferenceString), chestValue <= 0 {
                errors.append(NSLocalizedString("settings.goal.chest.circumference.invalid", comment: ""))
            }
        }
        
        if !goalThighCircumferenceString.isEmpty {
            if let thighValue = Double(goalThighCircumferenceString), thighValue <= 0 {
                errors.append(NSLocalizedString("settings.goal.thigh.circumference.invalid", comment: ""))
            }
        }
        
        if !errors.isEmpty {
            validationErrorMessage = errors.joined(separator: "\n")
            showingValidationAlert = true
            return
        }

        guard let heightValue = Double(heightString),
              let goalWeightValue = Double(goalWeightString) else {
            return
        }

        let heightInCm = heightUnit.convertToCm(heightValue)
        let goalWeightInKg = unit.convertToKg(goalWeightValue)
        let goalBodyFat = Double(goalBodyFatString)
        let goalWaistCircumference = Double(goalWaistCircumferenceString)
        let goalHipCircumference = Double(goalHipCircumferenceString)
        let goalChestCircumference = Double(goalChestCircumferenceString)
        let goalThighCircumference = Double(goalThighCircumferenceString)

        if let existing = existingProfile {
            existing.height = heightInCm
            existing.genderEnum = gender
            existing.age = Int16(age)
            existing.goalWeight = goalWeightInKg
            existing.goalBodyFat = goalBodyFat ?? 0
            existing.goalWaistCircumference = goalWaistCircumference ?? 0
            existing.goalHipCircumference = goalHipCircumference ?? 0
            existing.goalChestCircumference = goalChestCircumference ?? 0
            existing.goalThighCircumference = goalThighCircumference ?? 0
            existing.updatedAt = Date()
            existing.syncStatusEnum = .pending
        } else {
            let newProfile = UserProfile.create(in: context)
            newProfile.height = heightInCm
            newProfile.genderEnum = gender
            newProfile.age = Int16(age)
            newProfile.goalWeight = goalWeightInKg
            newProfile.goalBodyFat = goalBodyFat ?? 0
            newProfile.goalWaistCircumference = goalWaistCircumference ?? 0
            newProfile.goalHipCircumference = goalHipCircumference ?? 0
            newProfile.goalChestCircumference = goalChestCircumference ?? 0
            newProfile.goalThighCircumference = goalThighCircumference ?? 0
        }
        
        do {
            try context.save()
            DataSyncManager.shared.triggerProfileSync(context: context)
        } catch {
            print("保存个人资料失败: \(error)")
        }

        dismiss()
    }
    
    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }
}
