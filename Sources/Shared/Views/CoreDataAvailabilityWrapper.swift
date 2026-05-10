import SwiftUI
import CoreData

/// Wrapper view that checks if Core Data is available before showing the wrapped content
struct CoreDataAvailabilityWrapper<Content: View>: View {
    let content: Content
    @State private var isCoreDataAvailable = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if isCoreDataAvailable {
                content
            } else {
                developmentModeView
            }
        }
        .onAppear {
            checkCoreDataAvailability()
        }
    }

    private var developmentModeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Development Mode")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Core Data is not available in `swift run` mode.")
                    .font(.body)

                Text("This feature requires running ClipFlow in Xcode:")
                    .font(.body)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    bulletPoint("Open ClipFlow.xcodeproj in Xcode")
                    bulletPoint("Select ClipFlow scheme")
                    bulletPoint("Press ⌘R to build and run")
                }
                .padding(.leading, 16)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            Text("Core Data models (.xcdatamodeld) need to be compiled to .momd format, which only happens in Xcode build process.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: 600)
        .padding(40)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .fontWeight(.bold)
            Text(text)
        }
        .font(.body)
    }

    private func checkCoreDataAvailability() {
        // Try to fetch entities to see if Core Data is working
        let context = CoreDataStack.shared.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SnippetGroup")
        fetchRequest.fetchLimit = 1

        do {
            _ = try context.fetch(fetchRequest)
            isCoreDataAvailable = true
        } catch let error as NSError {
            print("⚠️ Core Data not available: \(error.localizedDescription)")
            isCoreDataAvailable = false
        }
    }
}

#Preview {
    CoreDataAvailabilityWrapper {
        Text("This would be the real content")
    }
}
