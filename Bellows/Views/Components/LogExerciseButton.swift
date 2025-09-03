import SwiftUI

struct LogExerciseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Log Exercise")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(LinearGradient(
                colors: [DS.ColorToken.gradientStart, DS.ColorToken.gradientEnd],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}