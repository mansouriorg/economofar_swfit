import SwiftUI
import UIKit

struct ReceiptDetailView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    let receiptId: UUID

    @State private var receipt: ReceiptDetailResponse? = nil

    @State private var merchantName = ""
    @State private var totalAmount = ""
    @State private var purchaseDate = ""
    @State private var category = "Autre"
    @State private var paymentMethod = "Carte"

    @State private var note = ""
    @State private var warrantyDate = ""
    @State private var reimbursable = false
    @State private var usageType: ReceiptUsageType = .personal

    @State private var vatAmount = ""
    @State private var deductible = false
    @State private var projectName = ""
    @State private var clientName = ""
    @State private var expenseReportReference = ""

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isExporting = false

    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    @State private var itemToEdit: ReceiptEditableItemForm? = nil
    @State private var showAddItemSheet = false
    @State private var showDeleteConfirmation = false

    @State private var exportedFile: ReceiptExportedFile? = nil

    private let service = ReceiptDetailService.shared

    private var receiptItems: [ReceiptItemDetailResponse] {
        receipt?.safeItems ?? []
    }

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            if isLoading && receipt == nil {
                loadingView
            } else {
                contentView
            }
        }
        .navigationTitle("Détail du reçu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                actionMenu
            }
        }
        .task {
            await loadReceipt()
        }
        .refreshable {
            await loadReceipt()
        }
        .sheet(item: $itemToEdit) { itemForm in
            ReceiptItemEditorSheet(
                title: "Modifier l’article",
                item: itemForm,
                onCancel: {
                    itemToEdit = nil
                },
                onSave: { updatedItem in
                    itemToEdit = nil

                    Task {
                        await updateItem(updatedItem)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddItemSheet) {
            ReceiptItemEditorSheet(
                title: "Ajouter un article",
                item: ReceiptEditableItemForm(),
                onCancel: {
                    showAddItemSheet = false
                },
                onSave: { newItem in
                    showAddItemSheet = false

                    Task {
                        await addItem(newItem)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $exportedFile) { file in
            ReceiptExportShareSheet(file: file)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Supprimer ce reçu ?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer définitivement", role: .destructive) {
                Task {
                    await deleteReceipt()
                }
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action supprimera le reçu et ses articles.")
        }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let errorMessage {
                    ReceiptDetailBanner(
                        icon: "exclamationmark.triangle.fill",
                        message: errorMessage,
                        tint: EconomofarUI.danger,
                        background: EconomofarUI.dangerSoft
                    )
                }

                if let successMessage {
                    ReceiptDetailBanner(
                        icon: "checkmark.circle.fill",
                        message: successMessage,
                        tint: EconomofarUI.success,
                        background: EconomofarUI.successSoft
                    )
                }

                receiptImageCard
                summaryCard
                mainInformationCard
                businessInformationCard
                itemsCard
                rawOcrCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Toolbar

    private var actionMenu: some View {
        Menu {
            Button {
                Task {
                    await saveReceipt()
                }
            } label: {
                Label("Enregistrer", systemImage: "checkmark.circle")
            }

            Button {
                Task {
                    await duplicateReceipt()
                }
            } label: {
                Label("Dupliquer", systemImage: "doc.on.doc")
            }

            Divider()

            Button {
                Task {
                    await downloadPdf()
                }
            } label: {
                Label("Télécharger PDF", systemImage: "doc.richtext")
            }

            Button {
                Task {
                    await exportAccountantCsv()
                }
            } label: {
                Label("Export comptable CSV", systemImage: "tablecells")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Supprimer", systemImage: "trash")
            }

        } label: {
            if isSaving || isExporting {
                ProgressView()
                    .tint(EconomofarUI.accent)
            } else {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }
        }
        .disabled(isSaving || isExporting)
    }

    // MARK: - Cards

    private var receiptImageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Image du reçu", systemImage: "photo")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Spacer()

                if let contentType = receipt?.imageContentType,
                   !contentType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(contentType)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(EconomofarUI.cardSoft)
                        .clipShape(Capsule())
                }
            }

            if let url = imageURL(from: receipt?.imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(EconomofarUI.cardSoft)
                                .frame(height: 220)

                            ProgressView()
                                .tint(EconomofarUI.accent)
                        }

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 180)
                            .background(EconomofarUI.cardSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    case .failure:
                        imagePlaceholder(
                            title: "Image non disponible",
                            subtitle: "Le backend doit fournir une imageUrl valide."
                        )

                    @unknown default:
                        imagePlaceholder(
                            title: "Image non disponible",
                            subtitle: "Impossible d’afficher l’image."
                        )
                    }
                }
            } else {
                imagePlaceholder(
                    title: "Aucune image",
                    subtitle: "L’image originale sera affichée ici quand imageUrl sera disponible."
                )
            }
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            ReceiptDetailIconBox(
                icon: usageType.icon,
                tint: usageType == .business ? EconomofarUI.accent : EconomofarUI.success
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(merchantName.isEmpty ? "Commerçant inconnu" : merchantName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)

                Text("\(category) • \(paymentMethod)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(1)

                Text(purchaseDate.isEmpty ? "Date inconnue" : purchaseDate)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(displayTotalAmount)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.accent)
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    private var mainInformationCard: some View {
        ReceiptSectionCard(title: "Informations principales", icon: "receipt") {
            VStack(spacing: 14) {
                ReceiptDetailTextField(
                    title: "Commerçant",
                    placeholder: "Carrefour",
                    icon: "storefront",
                    text: $merchantName
                )

                HStack(spacing: 12) {
                    ReceiptDetailTextField(
                        title: "Montant total",
                        placeholder: "0.00",
                        icon: "eurosign.circle",
                        text: $totalAmount,
                        keyboardType: .decimalPad
                    )

                    ReceiptDetailTextField(
                        title: "Date",
                        placeholder: "YYYY-MM-DD",
                        icon: "calendar",
                        text: $purchaseDate
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Catégorie", systemImage: "tag")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Picker("Catégorie", selection: $category) {
                        ForEach(availableCategories, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(EconomofarUI.cardSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Moyen de paiement", systemImage: "creditcard")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Picker("Paiement", selection: $paymentMethod) {
                        ForEach(ReceiptPaymentMethodOptions.all, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(EconomofarUI.cardSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Note", systemImage: "note.text")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    TextEditor(text: $note)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 90)
                        .padding(10)
                        .background(EconomofarUI.cardSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    Task {
                        await saveReceipt()
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .semibold))
                        }

                        Text("Enregistrer les modifications")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(EconomofarUI.mainGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(isSaving)
            }
        }
    }

    private var businessInformationCard: some View {
        ReceiptSectionCard(title: "Business & comptabilité", icon: "briefcase") {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Type", systemImage: usageType.icon)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Picker("Type", selection: $usageType) {
                        ForEach(ReceiptUsageType.allCases) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle(isOn: $reimbursable) {
                    Label("Remboursable", systemImage: "arrow.uturn.backward.circle")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                }

                Toggle(isOn: $deductible) {
                    Label("Déductible", systemImage: "checkmark.seal")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                }

                HStack(spacing: 12) {
                    ReceiptDetailTextField(
                        title: "TVA",
                        placeholder: "0.00",
                        icon: "percent",
                        text: $vatAmount,
                        keyboardType: .decimalPad
                    )

                    ReceiptDetailTextField(
                        title: "Garantie",
                        placeholder: "YYYY-MM-DD",
                        icon: "calendar.badge.checkmark",
                        text: $warrantyDate
                    )
                }

                ReceiptDetailTextField(
                    title: "Projet",
                    placeholder: "Projet ou mission",
                    icon: "folder",
                    text: $projectName
                )

                ReceiptDetailTextField(
                    title: "Client",
                    placeholder: "Nom du client",
                    icon: "person.crop.circle",
                    text: $clientName
                )

                ReceiptDetailTextField(
                    title: "Référence note de frais",
                    placeholder: "EXP-2026-06-001",
                    icon: "number",
                    text: $expenseReportReference
                )
            }
        }
    }

    private var itemsCard: some View {
        ReceiptSectionCard(title: "Articles", icon: "list.bullet.rectangle") {
            VStack(spacing: 12) {
                if receiptItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(EconomofarUI.accent)

                        Text("Aucun article")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)

                        Text("Ajoutez les articles du reçu manuellement.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(EconomofarUI.cardSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    ForEach(receiptItems) { item in
                        ReceiptItemDetailRow(
                            item: item,
                            onEdit: {
                                itemToEdit = ReceiptEditableItemForm(item: item)
                            },
                            onDelete: {
                                Task {
                                    await deleteItem(item)
                                }
                            }
                        )
                    }
                }

                Button {
                    showAddItemSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Ajouter un article")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(EconomofarUI.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var rawOcrCard: some View {
        ReceiptSectionCard(title: "Texte OCR", icon: "doc.text.magnifyingglass") {
            Text(receipt?.rawOcrText ?? "Aucun texte OCR disponible.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(EconomofarUI.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(EconomofarUI.cardSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(EconomofarUI.accent)
                .scaleEffect(1.2)

            Text("Chargement du reçu...")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
    }

    // MARK: - Computed

    private var availableCategories: [String] {
        let values = ReceiptBusinessCategoryOptions.all

        if values.contains(category) {
            return values
        }

        return [category] + values
    }

    private var displayTotalAmount: String {
        let amount = ReceiptDetailNumberHelper.double(from: totalAmount) ?? receipt?.totalAmount ?? 0.0
        return String(format: "%.2f €", amount)
    }

    // MARK: - Load

    private func loadReceipt() async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await service.getReceiptDetail(
                receiptId: receiptId,
                token: token
            )

            receipt = response
            fillForm(with: response)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fillForm(with receipt: ReceiptDetailResponse) {
        merchantName = receipt.merchantName ?? ""
        totalAmount = ReceiptDetailNumberHelper.string(from: receipt.totalAmount)
        purchaseDate = ReceiptDetailDateHelper.inputDate(from: receipt.purchaseDate)
        category = receipt.category ?? "Autre"
        paymentMethod = receipt.paymentMethod ?? "Carte"

        note = receipt.note ?? ""
        warrantyDate = receipt.warrantyDate ?? ""
        reimbursable = receipt.reimbursable ?? false
        usageType = receipt.usageType ?? .personal

        vatAmount = ReceiptDetailNumberHelper.string(from: receipt.vatAmount)
        deductible = receipt.deductible ?? false
        projectName = receipt.projectName ?? ""
        clientName = receipt.clientName ?? ""
        expenseReportReference = receipt.expenseReportReference ?? ""
    }

    // MARK: - Actions

    private func saveReceipt() async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let updateRequest = ReceiptDetailUpdateRequest(
            merchantName: merchantName,
            purchaseDate: purchaseDate,
            totalAmount: ReceiptDetailNumberHelper.double(from: totalAmount),
            category: category,
            paymentMethod: paymentMethod,
            rawOcrText: receipt?.rawOcrText,
            imageUrl: receipt?.imageUrl,
            note: note,
            warrantyDate: warrantyDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : warrantyDate,
            reimbursable: reimbursable,
            usageType: usageType,
            vatAmount: ReceiptDetailNumberHelper.double(from: vatAmount),
            deductible: deductible,
            projectName: projectName,
            clientName: clientName,
            expenseReportReference: expenseReportReference
        )

        do {
            let updated = try await service.updateReceiptDetail(
                receiptId: receiptId,
                requestBody: updateRequest,
                token: token
            )

            receipt = updated
            fillForm(with: updated)
            successMessage = "Reçu mis à jour."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func duplicateReceipt() async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            let duplicated = try await service.duplicateReceipt(
                receiptId: receiptId,
                token: token
            )

            successMessage = "Reçu dupliqué : \(duplicated.displayMerchant)."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func deleteReceipt() async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            try await service.deleteReceipt(
                receiptId: receiptId,
                token: token
            )

            isSaving = false
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func addItem(_ itemForm: ReceiptEditableItemForm) async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await service.addItem(
                receiptId: receiptId,
                item: itemForm.toRequest(),
                token: token
            )

            await loadReceipt()
            successMessage = "Article ajouté."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func updateItem(_ itemForm: ReceiptEditableItemForm) async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        guard let itemId = itemForm.id else {
            errorMessage = "Article invalide."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await service.updateItem(
                receiptId: receiptId,
                itemId: itemId,
                item: itemForm.toRequest(),
                token: token
            )

            await loadReceipt()
            successMessage = "Article mis à jour."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func deleteItem(_ item: ReceiptItemDetailResponse) async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            try await service.deleteItem(
                receiptId: receiptId,
                itemId: item.id,
                token: token
            )

            await loadReceipt()
            successMessage = "Article supprimé."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func downloadPdf() async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isExporting = true
        errorMessage = nil
        successMessage = nil

        do {
            let url = try await service.downloadReceiptPdf(
                receiptId: receiptId,
                token: token
            )

            exportedFile = ReceiptExportedFile(
                url: url,
                title: "PDF du reçu"
            )

            successMessage = "PDF généré."
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    private func exportAccountantCsv() async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isExporting = true
        errorMessage = nil
        successMessage = nil

        do {
            let url = try await service.exportAccountantCsv(
                receiptId: receiptId,
                token: token
            )

            exportedFile = ReceiptExportedFile(
                url: url,
                title: "Export comptable CSV"
            )

            successMessage = "Export comptable généré."
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    // MARK: - Image

    private func imageURL(from imageUrl: String?) -> URL? {
        guard let imageUrl,
              !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              imageUrl != "placeholder.jpg" else {
            return nil
        }

        if let url = URL(string: imageUrl),
           url.scheme == "http" || url.scheme == "https" {
            return url
        }

        if imageUrl.hasPrefix("/") {
            return URL(string: "http://localhost:8080\(imageUrl)")
        }

        return URL(string: "http://localhost:8080/\(imageUrl)")
    }

    private func imagePlaceholder(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "photo")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .background(EconomofarUI.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Receipt Item Row

struct ReceiptItemDetailRow: View {
    let item: ReceiptItemDetailResponse
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ReceiptDetailIconBox(
                icon: item.usageType?.icon ?? "cart",
                tint: item.usageType == .business ? EconomofarUI.accent : EconomofarUI.success
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text("\(item.displayCategory) • \(item.displayUsageType)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                Text("Qté \(item.displayQuantity) • Unit. \(item.displayUnitPrice)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(item.displayTotalPrice)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }
        }
        .padding(14)
        .background(EconomofarUI.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Item Editor Sheet

struct ReceiptItemEditorSheet: View {
    let title: String
    @State var item: ReceiptEditableItemForm

    let onCancel: () -> Void
    let onSave: (ReceiptEditableItemForm) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ReceiptSectionCard(title: "Article", icon: "cart") {
                            VStack(spacing: 14) {
                                ReceiptDetailTextField(
                                    title: "Nom",
                                    placeholder: "Lait, café, pain...",
                                    icon: "textformat",
                                    text: $item.name
                                )

                                HStack(spacing: 12) {
                                    ReceiptDetailTextField(
                                        title: "Quantité",
                                        placeholder: "1",
                                        icon: "number",
                                        text: $item.quantity,
                                        keyboardType: .numberPad
                                    )

                                    ReceiptDetailTextField(
                                        title: "Prix unit.",
                                        placeholder: "0.00",
                                        icon: "eurosign.circle",
                                        text: $item.unitPrice,
                                        keyboardType: .decimalPad
                                    )
                                }

                                ReceiptDetailTextField(
                                    title: "Prix total",
                                    placeholder: "0.00",
                                    icon: "sum",
                                    text: $item.totalPrice,
                                    keyboardType: .decimalPad
                                )

                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Catégorie", systemImage: "tag")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(EconomofarUI.textSecondary)

                                    Picker("Catégorie", selection: $item.category) {
                                        ForEach(ReceiptBusinessCategoryOptions.all, id: \.self) { value in
                                            Text(value).tag(value)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(EconomofarUI.cardSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Type", systemImage: item.usageType.icon)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(EconomofarUI.textSecondary)

                                    Picker("Type", selection: $item.usageType) {
                                        ForEach(ReceiptUsageType.allCases) { type in
                                            Text(type.title).tag(type)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                Button {
                                    onSave(item)
                                } label: {
                                    Text("Enregistrer l’article")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 15)
                                        .background(EconomofarUI.mainGradient)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Shared UI

struct ReceiptSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            content
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }
}

struct ReceiptDetailTextField: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .textInputAutocapitalization(.never)
                .padding()
                .background(EconomofarUI.cardSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(EconomofarUI.border, lineWidth: 1)
                }
        }
    }
}

struct ReceiptDetailIconBox: View {
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 48, height: 48)

            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
        }
    }
}

struct ReceiptDetailBanner: View {
    let icon: String
    let message: String
    let tint: Color
    let background: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ReceiptExportShareSheet: View {
    let file: ReceiptExportedFile

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(EconomofarUI.accentSoft)
                        .frame(width: 86, height: 86)

                    Image(systemName: "doc.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(EconomofarUI.accent)
                }

                VStack(spacing: 8) {
                    Text(file.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text(file.url.lastPathComponent)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ShareLink(item: file.url) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))

                        Text("Partager le fichier")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(EconomofarUI.mainGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 34)
            .background(EconomofarUI.background)
            .navigationTitle("Export prêt")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        ReceiptDetailView(receiptId: UUID())
            .environmentObject(SessionManager())
    }
}
