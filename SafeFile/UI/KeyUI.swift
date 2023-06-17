//
//  KeyUI.swift
//  SafeFile
//
//  Created by Sameh Sayed on 4/1/23.
//

import SwiftUI
struct ShakeAnimation: GeometryEffect {
    var amount: CGFloat = 5
    var bouncesPerUnit: CGFloat = 1
    var animatableData: CGFloat

    func effectValue(size _: CGSize) -> ProjectionTransform {
        let translation = -abs(amount * sin(animatableData * .pi * bouncesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: 0, y: translation))
    }
}

struct KeyUI: View {
    var keyType: KeyType

    @Binding var isShaking: Bool

    enum KeyType: String {
        case `public` = "Public Key"
        case `private` = "Private Key"
    }

    var image: String {
        switch keyType {
        case .public:
            return "key.fill"
        case .private:
            return "key"
        }
    }

    var body: some View {
        VStack {
            Image(systemName: image)
                .resizable()
                .help(keyType.rawValue)
                .frame(width: 20, height: 40)
                .modifier(ShakeAnimation(animatableData: isShaking ? 1 : 0))
                .animation(isShaking ? Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : nil)

            Text(keyType.rawValue)
                .font(.caption2)
        }
    }
}

struct KeyUI_Previews: PreviewProvider {
    static var previews: some View {
        KeyUI(keyType: .private, isShaking: .constant(true))
    }
}
