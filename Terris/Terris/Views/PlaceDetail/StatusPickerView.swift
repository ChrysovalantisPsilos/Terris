//
//  StatusPickerView.swift
//  Terris
//

import SwiftUI

struct StatusPickerView: View {
    @Binding var status: TravelStatus

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TravelStatus.allCases) { s in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        status = s
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: s.icon)
                        if s == status {
                            Text(s.label)
                                .font(.caption.weight(.semibold))
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(s == status ? s.color : Color(.secondarySystemFill))
                    )
                    .foregroundStyle(s == status ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
