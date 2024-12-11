import SwiftUI
import Firebase

// MARK: - Message Model
struct Message {
    let sender: String
    let text: String
    let timestamp: Date
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
                    let sender = data[FirebaseConstants.sender] as? String ?? ""
                    let text = data[FirebaseConstants.text] as? String ?? ""
                    let timestamp = data["timestamp"] as? Timestamp ?? Timestamp()
                    let date = timestamp.dateValue()

                    let message = Message(sender: sender, text: text, timestamp: date)

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
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    // Close current view, return to the previous view (ProfileView)
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title)
                }
                .padding()
            }
            // Calendar UI for the entire year
            CalendarView(selectedDate: $selectedDate)

            // Display messages for the selected date
            if let selectedDate = selectedDate {
                if let messages = messagesViewModel.messagesByDate[selectedDate] {
                    List(messages.sorted(by: { $0.timestamp < $1.timestamp }), id: \.timestamp) { message in
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
        .navigationBarHidden(true)
    }
}

// MARK: - CalendarView for Full Year
struct CalendarView: View {
    @Binding var selectedDate: Date?
    @State private var currentYear: Date = Date()

    var body: some View {
        VStack {
            Text("\(currentYear, formatter: yearFormatter)")
                .font(.headline)
                .padding()

            // Generate and display all months for the year
            let months = generateMonthsInYear(for: currentYear)
            ScrollView {
                ForEach(months, id: \.self) { month in
                    VStack {
                        Text("\(month, formatter: monthFormatter)")
                            .font(.headline)
                            .padding()

                        // Days of the week header
                        HStack {
                            ForEach(weekdays, id: \.self) { day in
                                Text(day)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        // Calendar grid for each month
                        let days = generateDaysInMonth(for: month)
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
                    }
                    .padding()
                }
            }
        }
        .padding()
    }

    // Formatter for displaying the year
    private let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    // Formatter for displaying the month
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    // Days of the week
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // Function to generate all months in the current year
    private func generateMonthsInYear(for date: Date) -> [Date] {
        var months: [Date] = []
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)

        for month in 1...12 {
            if let monthDate = calendar.date(from: DateComponents(year: year, month: month)) {
                months.append(monthDate)
            }
        }

        return months
    }

    // Function to generate all days in the given month
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
