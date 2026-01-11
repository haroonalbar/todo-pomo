import Foundation

/// Represents a todo item in the task list
struct TodoItem: Codable, Equatable, Identifiable {
    /// Unique identifier for the todo
    let id: UUID
    /// The title/text of the todo
    var title: String
    /// Whether the todo has been completed
    var isCompleted: Bool
    /// When the todo was created
    let createdAt: Date
    /// Optional due date for reminders
    var dueDate: Date?
    /// Links to an active pomodoro work session
    var linkedSessionId: UUID?
    
    /// Initialize a new todo item
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - title: The todo text
    ///   - isCompleted: Completion status (defaults to false)
    ///   - createdAt: Creation date (defaults to now)
    ///   - dueDate: Optional due date
    ///   - linkedSessionId: Optional linked work session
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        linkedSessionId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.linkedSessionId = linkedSessionId
    }
    
    /// Check if the todo is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
    
    /// Check if the todo is due today
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    /// Check if the todo is due soon (within next hour)
    var isDueSoon: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)
        return dueDate > now && dueDate <= oneHourFromNow
    }
    
    /// Formatted due date string
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(dueDate) {
            formatter.dateFormat = "HH:mm"
            return "Today \(formatter.string(from: dueDate))"
        } else if Calendar.current.isDateInTomorrow(dueDate) {
            formatter.dateFormat = "HH:mm"
            return "Tomorrow \(formatter.string(from: dueDate))"
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
            return formatter.string(from: dueDate)
        }
    }
}

