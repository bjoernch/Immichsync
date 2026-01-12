import SwiftUI

struct LogoView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.52, blue: 0.96), Color(red: 0.14, green: 0.82, blue: 0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.22, height: size * 0.22)
                .offset(x: size * -0.18, y: size * -0.18)

            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.2, y: size * -0.08)

            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(x: size * 0.05, y: size * 0.2)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}
