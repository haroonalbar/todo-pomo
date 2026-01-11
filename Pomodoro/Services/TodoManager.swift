import Foundation
import Combine

/// Manages todo items with persistence and due date notifications
class TodoManager: ObservableObject {
    /// Published collection of todo items
    @Published private(set) var todos: [TodoItem] = []
    
    /// The currently active/linked todo for the work session
    @Published var activeTodoId: UUID?
    
    /// Reference to notification service for due date reminders
    private let notificationService: NotificationService
    
    /// Set of cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// URL for todo storage file
    private var todosFileURL: URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("Pomodoro")
        
        // Create the directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        
        return appDirectory.appendingPathComponent("todos.json")
    }
    
    /// Initialize and load saved todos
    /// - Parameter notificationService: The notification service to use for due date reminders
    init(notificationService: NotificationService = NotificationService()) {
        self.notificationService = notificationService
        loadTodos()
    }
    
    // MARK: - CRUD Operations
    
    /// Add a new todo item
    /// - Parameters:
    ///   - title: The todo text
    ///   - dueDate: Optional due date
    /// - Returns: The created todo item
    @discardableResult
    func addTodo(title: String, dueDate: Date? = nil) -> TodoItem {
        let todo = TodoItem(title: title, dueDate: dueDate)
        todos.insert(todo, at: 0) // Add to top of list
        saveTodos()
        
        // Schedule due date notification if applicable
        if let dueDate = dueDate {
            scheduleDueDateNotification(for: todo, at: dueDate)
        }
        
        return todo
    }
    
    /// Update an existing todo item
    /// - Parameter todo: The updated todo item
    func updateTodo(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        
        let oldTodo = todos[index]
        todos[index] = todo
        saveTodos()
        
        // Handle due date notification changes
        if oldTodo.dueDate != todo.dueDate {
            removeDueDateNotification(for: todo.id)
            if let dueDate = todo.dueDate, !todo.isCompleted {
                scheduleDueDateNotification(for: todo, at: dueDate)
            }
        }
        
        // Remove notification if completed
        if todo.isCompleted && !oldTodo.isCompleted {
            removeDueDateNotification(for: todo.id)
        }
    }
    
    /// Toggle the completion status of a todo
    /// - Parameter id: The todo's unique identifier
    func toggleCompletion(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isCompleted.toggle()
        
        // Clear linked session if completing
        if todos[index].isCompleted {
            todos[index].linkedSessionId = nil
            if activeTodoId == id {
                activeTodoId = nil
            }
            removeDueDateNotification(for: id)
        } else {
            // Reschedule notifications if un-completing and has future due date
            if let dueDate = todos[index].dueDate, dueDate > Date() {
                scheduleDueDateNotification(for: todos[index], at: dueDate)
            }
        }
        
        saveTodos()
    }
    
    /// Delete a todo item
    /// - Parameter id: The todo's unique identifier
    func deleteTodo(id: UUID) {
        removeDueDateNotification(for: id)
        if activeTodoId == id {
            activeTodoId = nil
        }
        todos.removeAll { $0.id == id }
        saveTodos()
    }
    
    /// Delete all completed todos
    func deleteCompletedTodos() {
        let completedIds = todos.filter { $0.isCompleted }.map { $0.id }
        completedIds.forEach { removeDueDateNotification(for: $0) }
        todos.removeAll { $0.isCompleted }
        saveTodos()
    }
    
    /// Move a todo from one position to another
    /// - Parameters:
    ///   - fromId: The ID of the todo to move
    ///   - toId: The ID of the todo to move before (or nil to move to end)
    func moveTodo(fromId: UUID, toId: UUID?) {
        guard let fromIndex = todos.firstIndex(where: { $0.id == fromId }) else { return }
        
        let todo = todos.remove(at: fromIndex)
        
        if let toId = toId, let toIndex = todos.firstIndex(where: { $0.id == toId }) {
            todos.insert(todo, at: toIndex)
        } else {
            todos.append(todo)
        }
        
        saveTodos()
    }
    
    /// Reorder todos by moving from source indices to destination
    /// - Parameters:
    ///   - source: Source index set
    ///   - destination: Destination index
    func moveTodos(from source: IndexSet, to destination: Int) {
        todos.move(fromOffsets: source, toOffset: destination)
        saveTodos()
    }
    
    /// Move a todo up by one position
    /// - Parameter id: The ID of the todo to move up
    func moveTodoUp(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }),
              index > 0 else { return }
        todos.swapAt(index, index - 1)
        saveTodos()
    }
    
    /// Move a todo down by one position
    /// - Parameter id: The ID of the todo to move down
    func moveTodoDown(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }),
              index < todos.count - 1 else { return }
        todos.swapAt(index, index + 1)
        saveTodos()
    }
    
    // MARK: - Session Linking
    
    /// Link a todo to the current work session
    /// - Parameters:
    ///   - todoId: The todo's unique identifier
    ///   - sessionId: The work session's unique identifier
    func linkToSession(todoId: UUID, sessionId: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == todoId }) else { return }
        
        // Clear any existing links
        for i in todos.indices {
            if todos[i].linkedSessionId == sessionId {
                todos[i].linkedSessionId = nil
            }
        }
        
        todos[index].linkedSessionId = sessionId
        activeTodoId = todoId
        saveTodos()
    }
    
    /// Unlink a todo from its session
    /// - Parameter todoId: The todo's unique identifier
    func unlinkFromSession(todoId: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == todoId }) else { return }
        todos[index].linkedSessionId = nil
        if activeTodoId == todoId {
            activeTodoId = nil
        }
        saveTodos()
    }
    
    /// Clear all session links (called when work session ends)
    func clearSessionLinks() {
        for i in todos.indices {
            todos[i].linkedSessionId = nil
        }
        activeTodoId = nil
        saveTodos()
    }
    
    // MARK: - Computed Properties
    
    /// Get incomplete todos sorted by due date
    var incompleteTodos: [TodoItem] {
        todos.filter { !$0.isCompleted }
            .sorted { first, second in
                // Sort by due date (items with due dates first, then by date)
                switch (first.dueDate, second.dueDate) {
                case (nil, nil):
                    return first.createdAt > second.createdAt
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                case let (date1?, date2?):
                    return date1 < date2
                }
            }
    }
    
    /// Get completed todos
    var completedTodos: [TodoItem] {
        todos.filter { $0.isCompleted }
    }
    
    /// Get the currently active/linked todo
    var activeTodo: TodoItem? {
        guard let id = activeTodoId else { return nil }
        return todos.first { $0.id == id }
    }
    
    /// Count of incomplete todos
    var incompleteCount: Int {
        todos.filter { !$0.isCompleted }.count
    }
    
    /// Count of todos due today
    var dueTodayCount: Int {
        todos.filter { $0.isDueToday && !$0.isCompleted }.count
    }
    
    /// Count of overdue todos
    var overdueCount: Int {
        todos.filter { $0.isOverdue }.count
    }
    
    // MARK: - Persistence
    
    /// Save todos to disk
    func saveTodos() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(todos)
            try data.write(to: todosFileURL)
        } catch {
            print("Failed to save todos: \(error)")
        }
    }
    
    /// Load todos from disk
    func loadTodos() {
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: todosFileURL.path) {
                let data = try Data(contentsOf: todosFileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                todos = try decoder.decode([TodoItem].self, from: data)
                
                // Clean up notifications for completed todos first
                cleanupCompletedTodoNotifications()
                
                // Reschedule notifications for todos with future due dates
                rescheduleDueDateNotifications()
            }
        } catch {
            print("Failed to load todos: \(error)")
            todos = []
        }
    }
    
    /// Remove any stale notifications for completed todos
    private func cleanupCompletedTodoNotifications() {
        for todo in todos where todo.isCompleted {
            notificationService.removeTodoNotifications(todoId: todo.id)
        }
    }
    
    // MARK: - Due Date Notifications
    
    /// Schedule reminder notifications for a todo's due date (1hr, 30min, 10min, 5min before)
    private func scheduleDueDateNotification(for todo: TodoItem, at dueDate: Date) {
        // Only schedule if due date is in the future
        guard dueDate > Date() else { return }
        notificationService.scheduleTodoReminders(
            todoId: todo.id,
            title: todo.title,
            dueDate: dueDate
        )
    }
    
    /// Remove all scheduled notifications for a todo
    private func removeDueDateNotification(for todoId: UUID) {
        notificationService.removeTodoNotifications(todoId: todoId)
    }
    
    /// Reschedule all due date notifications (called on app launch)
    private func rescheduleDueDateNotifications() {
        for todo in todos where !todo.isCompleted {
            if let dueDate = todo.dueDate, dueDate > Date() {
                scheduleDueDateNotification(for: todo, at: dueDate)
            }
        }
    }
}

