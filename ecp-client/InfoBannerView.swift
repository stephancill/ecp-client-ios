import SwiftUI

struct InfoBannerView: View {
    let iconSystemName: String
    let iconBackgroundColor: Color
    let iconForegroundColor: Color
    let title: String
    let subtitle: String
    let buttonTitle: String
    let buttonAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)
                Image(systemName: iconSystemName)
                    .foregroundColor(iconForegroundColor)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: buttonAction) {
                Text(buttonTitle)
                    .font(.system(.footnote, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
    }
}