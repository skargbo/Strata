import SwiftUI

struct SkillSuggestionChips: View {
    let suggestions: [Skill]
    let onSelect: (Skill) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.caption2)
                .foregroundStyle(.orange)

            ForEach(suggestions.prefix(2)) { skill in
                Button {
                    onSelect(skill)
                } label: {
                    HStack(spacing: 4) {
                        Text("/\(skill.name)")
                            .fontWeight(.medium)
                        if let hint = skill.argumentHint {
                            Text(hint)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Color.orange.opacity(0.1),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
