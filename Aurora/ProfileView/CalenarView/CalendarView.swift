import SwiftUI
import Firebase

// MARK: - Message Model
struct Message: Hashable {
    let id: String // Unique message ID
    let sender: String
    let text: String
    let timestamp: Date
    let fromId: String
    let toId: String
}

// Date formatter for displaying timestamps
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - MessagesViewModel
class MessagesViewModel: ObservableObject {
    @Published var messagesByDate: [Date: [Message]] = [:]
    @Published var errorMessage: String?

    func searchSavedMessages(fromId: String, toId: String) {
        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .getDocuments { (snapshot, error) in
                if let error = error {
                    self.errorMessage = "Failed to fetch messages: \(error)"
                    return
                }

                var messagesByDate: [Date: [Message]] = [:]
                snapshot?.documents.forEach { document in
                    let data = document.data()
                    let id = document.documentID
                    let sender = data["sender"] as? String ?? ""
                    let text = data["text"] as? String ?? ""
                    let timestamp = data["timestamp"] as? Timestamp ?? Timestamp()
                    let fromId = data["fromId"] as? String ?? ""
                    let toId = data["toId"] as? String ?? ""
                    let date = timestamp.dateValue()

                    let message = Message(id: id, sender: sender, text: text, timestamp: date, fromId: fromId, toId: toId)

                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day], from: date)
                    if let messageDate = calendar.date(from: components) {
                        if messagesByDate[messageDate] == nil {
                            messagesByDate[messageDate] = []
                        }
                        messagesByDate[messageDate]?.append(message)
                    }
                }

                self.messagesByDate = messagesByDate
            }
    }
}

// MARK: - CalendarMessagesView
struct CalendarMessagesView: View {
    @ObservedObject var messagesViewModel: MessagesViewModel
    @State private var selectedDate: Date? = nil
    @State private var isEditing: Bool = false
    @State private var selectedMessages: Set<Message> = []

    var body: some View {
        VStack {
            // Calendar UI
            CalendarView(selectedDate: $selectedDate)

            // Edit Button
            HStack {
                if isEditing {
                    Button("Delete") {
                        deleteSelectedMessages()
                    }
                    .disabled(selectedMessages.isEmpty)
                    .padding()
                }

                Spacer()

                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                    if !isEditing {
                        selectedMessages.removeAll()
                    }
                }
                .padding()
            }

            // Display messages for the selected date
            if let selectedDate = selectedDate {
                if let messages = messagesViewModel.messagesByDate[selectedDate] {
                    List(messages.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { message in
                        HStack {
                            if isEditing {
                                Button(action: {
                                    toggleMessageSelection(message)
                                }) {
                                    Image(systemName: selectedMessages.contains(message) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(.blue)
                                }
                            }

                            VStack(alignment: .leading) {
                                Text(message.sender)
                                    .font(.headline)
                                Text(message.text)
                                    .font(.subheadline)
                                Text("\(message.timestamp, formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } else {
                    Text("No messages for this day")
                        .padding()
                }
            } else {
                Text("Select a date to see messages")
                    .padding()
            }
        }
        .navigationTitle("Messages Calendar")
    }

    // Toggle message selection in edit mode
    private func toggleMessageSelection(_ message: Message) {
        if selectedMessages.contains(message) {
            selectedMessages.remove(message)
        } else {
            selectedMessages.insert(message)
        }
    }

    // Delete selected messages
    private func deleteSelectedMessages() {
        guard let selectedDate = selectedDate else { return }
        guard let messagesToDelete = messagesViewModel.messagesByDate[selectedDate]?.filter({ selectedMessages.contains($0) }) else { return }

        // Delete messages from Firestore
        for message in messagesToDelete {
            deleteMessageFromFirestore(message)
        }

        // Remove messages locally
        messagesViewModel.messagesByDate[selectedDate]?.removeAll(where: { selectedMessages.contains($0) })
        selectedMessages.removeAll()
    }

    // Firestore deletion logic
    private func deleteMessageFromFirestore(_ message: Message) {
        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(message.fromId)
            .collection(message.toId)
            .document(message.id)
            .delete { error in
                if let error = error {
                    print("Error deleting message: \(error)")
                } else {
                    print("Message deleted successfully")
                }
            }
    }
}


struct CalendarView: View {
    @Binding var selectedDate: Date?
    @State private var currentMonth: Date = Date()

    private var months: [Date] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        var allMonths: [Date] = []
        for month in 1...12 {
            let components = DateComponents(year: currentYear, month: month, day: 1)
            if let monthDate = calendar.date(from: components) {
                allMonths.append(monthDate)
            }
        }
        return allMonths
    }

    var body: some View {
        VStack {
            // Horizontal month bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(months, id: \.self) { monthDate in
                        Button(action: {
                            currentMonth = monthDate
                        }) {
                            Text("\(monthDate, formatter: monthFormatter)")
                                .font(.subheadline)
                                .foregroundColor(isSameMonth(monthDate, as: currentMonth) ? .white : .primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(isSameMonth(monthDate, as: currentMonth) ? Color.blue : Color.clear)
                                .cornerRadius(5)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Days of the Week Header
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
            }

            let days = generateDaysInMonth(for: currentMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(days, id: \.self) { day in
                    if let day = day {
                        Button(action: {
                            selectedDate = day
                        }) {
                            Text("\(Calendar.current.component(.day, from: day))")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(selectedDate == day ? Color.blue.opacity(0.3) : Color.clear)
                                .cornerRadius(5)
                        }
                    } else {
                        Text("") // Empty placeholder for padding days
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
            }
            .padding()
        }
    }

    // Formatter for displaying month names (e.g. "Jan", "Feb", "Mar")
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    // Days of the week
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // Check if two dates are in the same month and year
    private func isSameMonth(_ date1: Date, as date2: Date) -> Bool {
        let calendar = Calendar.current
        let comp1 = calendar.dateComponents([.year, .month], from: date1)
        let comp2 = calendar.dateComponents([.year, .month], from: date2)
        return comp1.year == comp2.year && comp1.month == comp2.month
    }

    // Function to generate all days in the current month
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        var days: [Date?] = []
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)!

        // Get the first day of the month
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let weekday = calendar.component(.weekday, from: firstDayOfMonth) - 1

        // Add padding for days before the first day of the month
        days.append(contentsOf: Array(repeating: nil, count: weekday))

        // Add all days in the current month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}
