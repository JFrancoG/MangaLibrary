//
//  AccountCredentialFieldModifier.swift
//  MangaLibrary
//

import SwiftUI

struct AccountCredentialFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(.surface, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.controlBorder, lineWidth: 1)
            }
            .listRowInsets(
                EdgeInsets(
                    top: 4,
                    leading: 4,
                    bottom: 4,
                    trailing: 4
                )
            )
            .listRowBackground(Color.canvas)
    }
}
