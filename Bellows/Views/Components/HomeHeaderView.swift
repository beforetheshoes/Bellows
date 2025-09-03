import SwiftUI

struct HomeHeaderView: View {
    let date: Date
    
    var body: some View {
        HStack {
            Text(dateString(date))
                .font(.headline).bold()
            Spacer()
            Text("Today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .full; return f.string(from: d)
    }
}