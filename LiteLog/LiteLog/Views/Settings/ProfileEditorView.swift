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
    @State private var showingSuccessToast = false
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case height, goalWeight, goalBodyFat, waist, hip, chest, thigh
    }

    private var existingProfile: UserProfile? { userProfile.first }
    private var unit: WeightUnit { settingsManager.weightUnit }
    private var heightUnit: HeightUnit { settingsManager.heightUnit }
    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        focusedField = nil
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    basicInfoCard
                    
                    goalsCard
                    
                    saveButton
                }
                .padding()
            }
            
            if showingSuccessToast {
                successToast
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
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
    
    private var successToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
                Text(NSLocalizedString("action.save.success", comment: ""))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.primaryBlue)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: showingSuccessToast)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
        .onTapGesture {
            showingSuccessToast = false
        }
    }
    
    
    
    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("settings.basic.info", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)
            
            genderPicker
            
            ageStepper
            
            heightInput
        }
        .padding()
        .background(inputBackgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var genderPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("settings.gender", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Picker(NSLocalizedString("settings.gender", comment: ""), selection: $gender) {
                Text(NSLocalizedString("settings.male", comment: "")).tag(UserProfile.Gender.male)
                Text(NSLocalizedString("settings.female", comment: "")).tag(UserProfile.Gender.female)
            }
            .pickerStyle(.segmented)
            .colorScheme(.light)
        }
    }
    
    private var ageStepper: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("settings.age", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            Button(action: { age = max(1, age - 1) }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.primaryBlue)
                    .frame(width: 40, height: 40)
            }
            
            Text("\(age)")
                .font(Font(UIFont.systemFont(ofSize: 22, weight: .semibold)))
                .foregroundColor(.primaryText)
                .frame(width: 60, alignment: .center)
            
            Button(action: { age = min(120, age + 1) }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.primaryBlue)
                    .frame(width: 40, height: 40)
            }
            
            Text(NSLocalizedString("settings.years", comment: ""))
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var heightInput: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                Text(NSLocalizedString("settings.height", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                Text("*")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $heightString)
                .font(Font(UIFont.systemFont(ofSize: 22, weight: .semibold)))
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: .height)
            
            Text(heightUnit.displayName)
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == .height ? Color.primaryBlue : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.2), value: focusedField)
        )
        .shadow(color: focusedField == .height ? Color.primaryBlue.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
    }
    
    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("settings.goals", comment: ""))
                .font(.headline)
                .foregroundColor(.primaryText)
            
            goalWeightInput
            
            goalBodyFatInput
            
            Divider()
            
            Text(NSLocalizedString("settings.goal.measurements", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            VStack(spacing: 10) {
                circumferenceInput(label: NSLocalizedString("settings.goal.waist", comment: ""), text: $goalWaistCircumferenceString, field: .waist)
                circumferenceInput(label: NSLocalizedString("settings.goal.hip", comment: ""), text: $goalHipCircumferenceString, field: .hip)
                circumferenceInput(label: NSLocalizedString("settings.goal.chest", comment: ""), text: $goalChestCircumferenceString, field: .chest)
                circumferenceInput(label: NSLocalizedString("settings.goal.thigh", comment: ""), text: $goalThighCircumferenceString, field: .thigh)
            }
        }
        .padding()
        .background(inputBackgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var goalWeightInput: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                Text(NSLocalizedString("settings.goal.weight", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                Text("*")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalWeightString)
                .font(Font(UIFont.systemFont(ofSize: 22, weight: .semibold)))
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: .goalWeight)
            
            Text(unit.shortName)
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == .goalWeight ? Color.primaryBlue : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.2), value: focusedField)
        )
        .shadow(color: focusedField == .goalWeight ? Color.primaryBlue.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
    }
    
    private var goalBodyFatInput: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("settings.goal.body.fat", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: $goalBodyFatString)
                .font(Font(UIFont.systemFont(ofSize: 22, weight: .semibold)))
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: .goalBodyFat)
            
            Text("%")
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == .goalBodyFat ? Color.primaryBlue : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.2), value: focusedField)
        )
        .shadow(color: focusedField == .goalBodyFat ? Color.primaryBlue.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
    }
    
    private func circumferenceInput(label: String, text: Binding<String>, field: FocusedField) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            NumericTextField(NSLocalizedString("settings.prompt.enter", comment: ""), text: text)
                .font(Font(UIFont.systemFont(ofSize: 22, weight: .semibold)))
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: field)
            
            Text(NSLocalizedString("settings.cm", comment: ""))
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == field ? Color.primaryBlue : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.2), value: focusedField)
        )
        .shadow(color: focusedField == field ? Color.primaryBlue.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
    }
    
    private var saveButton: some View {
        Button(action: saveProfile) {
            Text(NSLocalizedString("action.save", comment: ""))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.primaryBlue)
                .cornerRadius(12)
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
            
            showingSuccessToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showingSuccessToast = false
                dismiss()
            }
        } catch {
            print("保存个人资料失败: \(error)")
        }
    }
    
    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }
}