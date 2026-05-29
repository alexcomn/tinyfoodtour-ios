import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color("Tomato").ignoresSafeArea()

            // Logo image centered, width = 60% of screen — mirrors Splash.tsx w-[60vw]
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.60)
        }
    }
}

#Preview {
    SplashView()
}
