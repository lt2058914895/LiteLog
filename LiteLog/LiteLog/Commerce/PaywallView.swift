import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var proStore: ProEntitlementStore

    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    VStack(spacing: 8) {
                        featureList

                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.purple)

                            Text(NSLocalizedString("pro.future.note", comment: ""))
                                .font(.footnote)
                                .foregroundColor(.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    purchaseSection
                        .padding(.top, 12)
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primaryBlue)
                            .frame(width: 30, height: 30)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(NSLocalizedString("action.close", comment: ""))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        restore()
                    } label: {
                        HStack(spacing: 4) {
                            if proStore.isRestoring {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(NSLocalizedString("pro.restore", comment: ""))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.primaryBlue)
                    }
                    .disabled(proStore.isRestoring || proStore.isPurchasing)
                    .accessibilityLabel(NSLocalizedString("pro.restore", comment: ""))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await proStore.prepare()
        }
        .onChange(of: proStore.isPro) { isPro in
            guard isPro else { return }
            HapticManager.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                dismiss()
            }
        }
        .alert(NSLocalizedString("pro.error.title", comment: ""), isPresented: $showingError) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient.profileHeader)
                    .frame(width: 50, height: 50)
                Image(systemName: "sparkles")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(NSLocalizedString("pro.title", comment: ""))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient.profileHeader)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 10)
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            featureRow(
                titleKey: "pro.feature.pdf.title",
                descriptionKey: "pro.feature.pdf.desc"
            )
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func featureRow(
        titleKey: String,
        descriptionKey: String
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 22, height: 22)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString(titleKey, comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)

                Text(NSLocalizedString(descriptionKey, comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button {
                if proStore.product == nil {
                    Task { await proStore.prepare() }
                } else {
                    purchase()
                }
            } label: {
                HStack(spacing: 8) {
                    if proStore.isPurchasing || proStore.isLoadingProduct {
                        ProgressView()
                            .tint(.white)
                    } else if proStore.isPro {
                        Image(systemName: "checkmark.seal.fill")
                    }

                    Text(purchaseButtonTitle)
                }
                .primaryButtonStyle()
            }
            .disabled(proStore.isPurchasing || proStore.isRestoring || proStore.isLoadingProduct || proStore.isPro)

            Text(NSLocalizedString("pro.purchase.note", comment: ""))
                .font(.caption.weight(.medium))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
    }

    private var purchaseButtonTitle: String {
        if proStore.isPro {
            return NSLocalizedString("pro.purchased", comment: "")
        }
        if proStore.isPurchasing {
            return NSLocalizedString("pro.purchasing", comment: "")
        }
        if proStore.isLoadingProduct {
            return NSLocalizedString("pro.loading", comment: "")
        }
        if proStore.product != nil {
            return String(
                format: NSLocalizedString("pro.purchase.format", comment: ""),
                proStore.displayPrice
            )
        }
        return NSLocalizedString("pro.reload", comment: "")
    }

    private func purchase() {
        Task {
            do {
                try await proStore.purchase()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func restore() {
        Task {
            do {
                try await proStore.restore()
                HapticManager.success()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}
