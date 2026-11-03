import SwiftUI

struct NewPasswordChecklist: View {
    let rules: [NewPasswordRule]
    var metColor: Color = .green
    var pendingColor: Color = .gray
    var textColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rules) { rule in
                HStack(spacing: 8) {
                    Image(systemName: rule.isMet ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(rule.isMet ? metColor : pendingColor)

                    Text(rule.text)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(rule.isMet ? textColor : pendingColor)

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rule.spoken)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
