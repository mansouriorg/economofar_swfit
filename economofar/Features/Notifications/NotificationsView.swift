import SwiftUI

struct NotificationsView: View {

    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            NotificationsDesign.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header

                    if viewModel.isLoadingNotifications {
                        loadingCard
                    } else if viewModel.notifications.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.notifications) { notification in
                                notificationRow(notification)
                                    .onTapGesture {
                                        Task {
                                            await viewModel.markAsRead(notification)
                                        }
                                    }
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadNotifications()
        }
        .refreshable {
            await viewModel.loadNotifications()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Centre de notifications")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(NotificationsDesign.primaryText)

            Text("Retrouvez ici vos alertes de tickets, budgets et rapports.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(NotificationsDesign.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Chargement des notifications...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NotificationsDesign.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(NotificationsDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(NotificationsDesign.border, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(NotificationsDesign.accent)

            Text("Aucune notification")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NotificationsDesign.primaryText)

            Text("Vos futures alertes apparaîtront ici.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(NotificationsDesign.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(NotificationsDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(NotificationsDesign.border, lineWidth: 1)
        }
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(notification.isRead ? NotificationsDesign.softGray : NotificationsDesign.accentSoft)
                    .frame(width: 42, height: 42)

                Image(systemName: notification.type.iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(notification.isRead ? NotificationsDesign.secondaryText : NotificationsDesign.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NotificationsDesign.primaryText)
                        .lineLimit(2)

                    if !notification.isRead {
                        Circle()
                            .fill(NotificationsDesign.accent)
                            .frame(width: 7, height: 7)
                    }
                }

                Text(notification.body)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(NotificationsDesign.secondaryText)
                    .lineLimit(3)

                if let createdAt = notification.createdAt {
                    Text(formatBackendDate(createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotificationsDesign.tertiaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(NotificationsDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NotificationsDesign.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 6)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(NotificationsDesign.danger)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NotificationsDesign.danger)

            Spacer()
        }
        .padding(14)
        .background(NotificationsDesign.dangerSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formatBackendDate(_ value: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date.formatted(date: .abbreviated, time: .shortened)
            }
        }

        return value
    }
}

private enum NotificationsDesign {
    static let background = color(0xF7F8FA)
    static let card = Color.white
    static let border = color(0xE5E7EB)

    static let primaryText = color(0x111827)
    static let secondaryText = color(0x6B7280)
    static let tertiaryText = color(0x9CA3AF)

    static let accent = color(0x1F5EFF)
    static let accentSoft = color(0xE8EFFF)

    static let softGray = color(0xF3F4F6)
    static let danger = color(0xDC2626)
    static let dangerSoft = color(0xFEF2F2)

    private static func color(_ hex: UInt, alpha: Double = 1.0) -> Color {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
