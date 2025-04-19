import SwiftUI

struct AppIcon: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.2, blue: 0.2),
                    Color(red: 0.1, green: 0.1, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Red circle for "live" status
            Circle()
                .fill(Color.red)
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.2)
                .shadow(color: .red.opacity(0.5), radius: size * 0.1)
            
            // YouTube play button shape
            Path { path in
                let width = size * 0.4
                let height = width * 0.7
                path.move(to: CGPoint(x: width * 0.2, y: 0))
                path.addLine(to: CGPoint(x: width, y: height * 0.5))
                path.addLine(to: CGPoint(x: width * 0.2, y: height))
                path.closeSubpath()
            }
            .fill(Color.white)
            .frame(width: size * 0.4, height: size * 0.28)
            .offset(x: size * 0.1)
            .shadow(color: .black.opacity(0.3), radius: size * 0.05)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}

#Preview {
    HStack {
        AppIcon(size: 32)
        AppIcon(size: 64)
        AppIcon(size: 128)
        AppIcon(size: 256)
    }
    .padding()
    .background(Color.gray)
} 