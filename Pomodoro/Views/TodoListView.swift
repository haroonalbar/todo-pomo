import SwiftUI

/// View for displaying and managing the todo list in the menubar
struct TodoListView: View {
    /// Reference to the state manager
    @ObservedObject var stateManager: StateManager
    
    /// Direct reference to todo manager for proper observation
    @ObservedObject var todoManager: TodoManager
    
    /// State for the new todo text field
    @State private var newTodoTitle = ""
    
    /// State for showing the add todo field
    @State private var isAddingTodo = false
    
    /// State for the due date picker
    @State private var newTodoDueDate: Date = Date()
    
    /// State for whether to include a due date
    @State private var includeDueDate = false
    
    /// State for showing custom date picker
    @State private var showCustomDatePicker = false
    
    /// State for showing completed todos
    @State private var showCompleted = false
    
    /// State for the currently dragged todo ID
    @State private var draggingTodoId: UUID? = nil
    
    /// State for the current drop target ID
    @State private var dropTargetId: UUID? = nil
    
    /// State for editing a todo
    @State private var editingTodoId: UUID? = nil
    @State private var editingTitle: String = ""
    @State private var editingDueDate: Date = Date()
    @State private var editingHasDueDate: Bool = false
    @State private var editingShowCustomPicker: Bool = false
    
    /// Maximum number of todos to show before scrolling
    private let maxVisibleTodos = 5
    
    /// Computed property to get all visible todos (maintains manual order)
    private var visibleTodos: [TodoItem] {
        var result = todoManager.todos.filter { !$0.isCompleted }
        
        if showCompleted {
            result.append(contentsOf: todoManager.todos.filter { $0.isCompleted })
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.blue)
                Text("Tasks")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Badge for incomplete count
                let incompleteCount = todoManager.todos.filter { !$0.isCompleted }.count
                if incompleteCount > 0 {
                    Text("\(incompleteCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                        .foregroundStyle(.blue)
                }
                
                // Toggle completed visibility
                let hasCompleted = todoManager.todos.contains { $0.isCompleted }
                if hasCompleted {
                    Button(action: { showCompleted.toggle() }) {
                        Image(systemName: showCompleted ? "eye.slash" : "eye")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showCompleted ? "Hide completed" : "Show completed")
                }
            }
            .padding(.horizontal, 5)
            
            // Todo list - always show if there are todos
            if visibleTodos.isEmpty && !isAddingTodo {
                Text("No tasks yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
            } else if !visibleTodos.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(visibleTodos.enumerated()), id: \.element.id) { index, todo in
                        if editingTodoId == todo.id {
                            editTodoForm(for: todo)
                        } else {
                            todoRow(for: todo, isFirst: index == 0, isLast: index == visibleTodos.count - 1)
                                .background(
                                    // Drop indicator line
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue)
                                        .frame(height: 2)
                                        .opacity(dropTargetId == todo.id ? 1 : 0)
                                        .offset(y: -4)
                                    , alignment: .top
                                )
                                .draggable(todo.id.uuidString) {
                                    // Drag preview - styled card
                                    HStack(spacing: 6) {
                                        Image(systemName: "line.3.horizontal")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Text(todo.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.ultraThinMaterial)
                                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                    )
                                    .onAppear {
                                        draggingTodoId = todo.id
                                    }
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    // Handle drop
                                    dropTargetId = nil
                                    guard let draggedIdString = items.first,
                                          let draggedId = UUID(uuidString: draggedIdString),
                                          draggedId != todo.id,
                                          !todo.isCompleted else { 
                                        draggingTodoId = nil
                                        return false 
                                    }
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        todoManager.moveTodo(fromId: draggedId, toId: todo.id)
                                    }
                                    draggingTodoId = nil
                                    return true
                                } isTargeted: { isTargeted in
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        if isTargeted && !todo.isCompleted && draggingTodoId != todo.id {
                                            dropTargetId = todo.id
                                        } else if dropTargetId == todo.id {
                                            dropTargetId = nil
                                        }
                                    }
                                }
                                .scaleEffect(draggingTodoId == todo.id ? 0.95 : 1.0)
                                .opacity(draggingTodoId == todo.id ? 0.4 : 1.0)
                                .offset(y: dropTargetId == todo.id ? 4 : 0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dropTargetId)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: draggingTodoId)
                        }
                    }
                }
                .padding(.horizontal, 5)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: todoManager.todos.map { $0.id })
                .onAppear {
                    // Reset drag state when view appears (fixes stale state after menu close)
                    draggingTodoId = nil
                    dropTargetId = nil
                }
            }
            
            // Add todo section
            if isAddingTodo {
                VStack(spacing: 8) {
                    TextField("New task...", text: $newTodoTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addTodo()
                        }
                    
                    // Deadline section
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(includeDueDate ? .blue : .secondary)
                                .imageScale(.small)
                            Text("Deadline")
                                .font(.caption)
                                .foregroundStyle(includeDueDate ? .primary : .secondary)
                            
                            Spacer()
                            
                            if includeDueDate {
                                Text(formatSelectedDate(newTodoDueDate))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                                
                                Button(action: { 
                                    includeDueDate = false
                                    showCustomDatePicker = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .imageScale(.small)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Quick preset buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                QuickDateButton(title: "30m", icon: "clock") {
                                    setDueDate(minutesFromNow: 30)
                                }
                                QuickDateButton(title: "1h", icon: "clock") {
                                    setDueDate(minutesFromNow: 60)
                                }
                                QuickDateButton(title: "2h", icon: "clock") {
                                    setDueDate(minutesFromNow: 120)
                                }
                                QuickDateButton(title: "Today", icon: "sun.max") {
                                    setDueDate(endOfDay: Date())
                                }
                                QuickDateButton(title: "Tomorrow", icon: "sunrise") {
                                    setDueDate(endOfDay: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
                                }
                                QuickDateButton(title: "Custom", icon: "calendar") {
                                    showCustomDatePicker.toggle()
                                    if !includeDueDate {
                                        newTodoDueDate = Date().addingTimeInterval(3600)
                                        includeDueDate = true
                                    }
                                }
                            }
                        }
                        
                        // Custom date picker (shown when "Custom" is tapped)
                        if showCustomDatePicker {
                            HStack(spacing: 8) {
                                DatePicker(
                                    "",
                                    selection: $newTodoDueDate,
                                    in: Date()...,
                                    displayedComponents: [.date]
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .frame(maxWidth: 110)
                                
                                DatePicker(
                                    "",
                                    selection: $newTodoDueDate,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .frame(maxWidth: 80)
                            }
                            .onChange(of: newTodoDueDate) { _ in
                                includeDueDate = true
                            }
                        }
                    }
                    
                    // Action buttons
                    HStack {
                        Button("Cancel") {
                            cancelAddTodo()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("Add Task") {
                            addTodo()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal, 5)
            } else {
                Button(action: { isAddingTodo = true }) {
                    Label("Add Task", systemImage: "plus.circle")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .padding(.horizontal, 5)
            }
            
            // Clear completed button
            let hasCompletedTodos = todoManager.todos.contains { $0.isCompleted }
            if hasCompletedTodos {
                Button(action: {
                    todoManager.deleteCompletedTodos()
                }) {
                    Label("Clear Completed", systemImage: "trash")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
            }
        }
        .padding(.vertical, 5)
    }
    
    /// Add a new todo item
    private func addTodo() {
        let title = newTodoTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        let dueDate = includeDueDate ? newTodoDueDate : nil
        todoManager.addTodo(title: title, dueDate: dueDate)
        
        // Reset form
        cancelAddTodo()
    }
    
    /// Cancel adding a todo and reset form
    private func cancelAddTodo() {
        newTodoTitle = ""
        includeDueDate = false
        showCustomDatePicker = false
        newTodoDueDate = Date()
        isAddingTodo = false
    }
    
    /// Set due date from minutes from now
    private func setDueDate(minutesFromNow: Int) {
        newTodoDueDate = Date().addingTimeInterval(Double(minutesFromNow * 60))
        includeDueDate = true
        showCustomDatePicker = false
    }
    
    /// Set due date to end of a given day (6 PM)
    private func setDueDate(endOfDay date: Date) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 18
        components.minute = 0
        newTodoDueDate = Calendar.current.date(from: components) ?? date
        includeDueDate = true
        showCustomDatePicker = false
    }
    
    /// Format selected date for display
    private func formatSelectedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: date)
    }
    
    // MARK: - Todo Row Helpers
    
    /// Build a todo row with move up/down support
    @ViewBuilder
    private func todoRow(for todo: TodoItem, isFirst: Bool, isLast: Bool) -> some View {
        let incompleteTodos = visibleTodos.filter { !$0.isCompleted }
        let isFirstIncomplete = incompleteTodos.first?.id == todo.id
        let isLastIncomplete = incompleteTodos.last?.id == todo.id
        
        TodoRowView(
            todo: todo,
            isLinked: todoManager.activeTodoId == todo.id,
            isWorkSessionActive: stateManager.currentState == .work,
            isFirst: isFirstIncomplete,
            isLast: isLastIncomplete,
            onToggle: { todoManager.toggleCompletion(id: todo.id) },
            onDelete: { todoManager.deleteTodo(id: todo.id) },
            onLinkToggle: { handleLinkToggle(for: todo) },
            onEdit: { startEditing(todo: todo) },
            onMoveUp: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    todoManager.moveTodoUp(id: todo.id)
                }
            },
            onMoveDown: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    todoManager.moveTodoDown(id: todo.id)
                }
            },
            isDragging: draggingTodoId != nil
        )
    }
    
    /// Handle link toggle for a todo
    private func handleLinkToggle(for todo: TodoItem) {
        if todoManager.activeTodoId == todo.id {
            stateManager.unlinkTodo(todoId: todo.id)
        } else {
            stateManager.linkTodoToCurrentSession(todoId: todo.id)
        }
    }
    
    // MARK: - Edit Todo Functions
    
    /// Start editing a todo
    private func startEditing(todo: TodoItem) {
        editingTodoId = todo.id
        editingTitle = todo.title
        editingHasDueDate = todo.dueDate != nil
        editingDueDate = todo.dueDate ?? Date().addingTimeInterval(3600)
        editingShowCustomPicker = false
    }
    
    /// Cancel editing
    private func cancelEditing() {
        editingTodoId = nil
        editingTitle = ""
        editingHasDueDate = false
        editingDueDate = Date()
        editingShowCustomPicker = false
    }
    
    /// Save edited todo
    private func saveEdit() {
        guard let todoId = editingTodoId,
              let index = todoManager.todos.firstIndex(where: { $0.id == todoId }) else { return }
        
        let title = editingTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        var updatedTodo = todoManager.todos[index]
        updatedTodo.title = title
        updatedTodo.dueDate = editingHasDueDate ? editingDueDate : nil
        
        todoManager.updateTodo(updatedTodo)
        cancelEditing()
    }
    
    /// Set edit due date from minutes from now
    private func setEditDueDate(minutesFromNow: Int) {
        editingDueDate = Date().addingTimeInterval(Double(minutesFromNow * 60))
        editingHasDueDate = true
        editingShowCustomPicker = false
    }
    
    /// Set edit due date to end of a given day (6 PM)
    private func setEditDueDate(endOfDay date: Date) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 18
        components.minute = 0
        editingDueDate = Calendar.current.date(from: components) ?? date
        editingHasDueDate = true
        editingShowCustomPicker = false
    }
    
    /// Edit form for a todo
    @ViewBuilder
    private func editTodoForm(for todo: TodoItem) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "pencil")
                    .foregroundStyle(.orange)
                Text("Edit Task")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            TextField("Task title...", text: $editingTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Deadline section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(editingHasDueDate ? .blue : .secondary)
                        .imageScale(.small)
                    Text("Deadline")
                        .font(.caption)
                        .foregroundStyle(editingHasDueDate ? .primary : .secondary)
                    
                    Spacer()
                    
                    if editingHasDueDate {
                        Text(formatSelectedDate(editingDueDate))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        
                        Button(action: { 
                            editingHasDueDate = false
                            editingShowCustomPicker = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Quick preset buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        QuickDateButton(title: "30m", icon: "clock") {
                            setEditDueDate(minutesFromNow: 30)
                        }
                        QuickDateButton(title: "1h", icon: "clock") {
                            setEditDueDate(minutesFromNow: 60)
                        }
                        QuickDateButton(title: "2h", icon: "clock") {
                            setEditDueDate(minutesFromNow: 120)
                        }
                        QuickDateButton(title: "Today", icon: "sun.max") {
                            setEditDueDate(endOfDay: Date())
                        }
                        QuickDateButton(title: "Tomorrow", icon: "sunrise") {
                            setEditDueDate(endOfDay: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
                        }
                        QuickDateButton(title: "Custom", icon: "calendar") {
                            editingShowCustomPicker.toggle()
                            if !editingHasDueDate {
                                editingDueDate = Date().addingTimeInterval(3600)
                                editingHasDueDate = true
                            }
                        }
                    }
                }
                
                // Custom date picker
                if editingShowCustomPicker {
                    HStack(spacing: 8) {
                        DatePicker(
                            "",
                            selection: $editingDueDate,
                            in: Date()...,
                            displayedComponents: [.date]
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .frame(maxWidth: 110)
                        
                        DatePicker(
                            "",
                            selection: $editingDueDate,
                            displayedComponents: [.hourAndMinute]
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .frame(maxWidth: 80)
                    }
                    .onChange(of: editingDueDate) { _ in
                        editingHasDueDate = true
                    }
                }
            }
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    cancelEditing()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Save") {
                    saveEdit()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(editingTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Quick date selection button
struct QuickDateButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .imageScale(.small)
                Text(title)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.1))
            )
            .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }
}

