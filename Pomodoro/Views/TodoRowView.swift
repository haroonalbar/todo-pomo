import SwiftUI
import AppKit

/// Solid opaque tooltip background for maximum readability
struct TooltipBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Fully opaque solid background
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white)
            
            // Subtle inner shadow/gradient for depth
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Strong border for definition
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15), lineWidth: 1)
        }
    }
}

/// Countdown timer view for due dates
struct CountdownTimerView: View {
    let dueDate: Date
    let isCompleted: Bool
    
    /// Timer that updates every second
    @State private var now = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .imageScale(.small)
            Text(countdownText)
                .font(.system(.caption2, design: .monospaced, weight: .medium))
        }
        .foregroundStyle(countdownColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(countdownColor.opacity(0.15))
        )
        .onReceive(timer) { _ in
            now = Date()
        }
    }
    
    /// Time remaining in seconds
    private var timeRemaining: TimeInterval {
        dueDate.timeIntervalSince(now)
    }
    
    /// Icon based on urgency
    private var iconName: String {
        if isCompleted {
            return "checkmark.circle"
        } else if timeRemaining <= 0 {
            return "exclamationmark.triangle.fill"
        } else if timeRemaining <= 300 { // 5 min
            return "flame.fill"
        } else if timeRemaining <= 1800 { // 30 min
            return "clock.badge.exclamationmark"
        } else {
            return "clock"
        }
    }
    
    /// Formatted countdown text
    private var countdownText: String {
        if isCompleted {
            return "Done"
        }
        
        let remaining = timeRemaining
        
        if remaining <= 0 {
            // Overdue
            let overdue = abs(remaining)
            if overdue < 60 {
                return "OVERDUE"
            } else if overdue < 3600 {
                let mins = Int(overdue / 60)
                return "-\(mins)m"
            } else {
                let hours = Int(overdue / 3600)
                let mins = Int((overdue.truncatingRemainder(dividingBy: 3600)) / 60)
                return "-\(hours)h \(mins)m"
            }
        } else if remaining < 60 {
            // Less than a minute
            let secs = Int(remaining)
            return "\(secs)s"
        } else if remaining < 3600 {
            // Less than an hour
            let mins = Int(remaining / 60)
            let secs = Int(remaining.truncatingRemainder(dividingBy: 60))
            if remaining < 300 { // Show seconds when < 5 min
                return "\(mins)m \(secs)s"
            }
            return "\(mins)m"
        } else if remaining < 86400 {
            // Less than a day
            let hours = Int(remaining / 3600)
            let mins = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        } else {
            // Days
            let days = Int(remaining / 86400)
            let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
            return "\(days)d \(hours)h"
        }
    }
    
    /// Color based on time remaining
    /// Green -> Yellow -> Orange -> Red
    private var countdownColor: Color {
        if isCompleted {
            return .green
        }
        
        let remaining = timeRemaining
        
        if remaining <= 0 {
            // Overdue - bright red
            return .red
        } else if remaining <= 300 {
            // < 5 minutes - red
            return .red
        } else if remaining <= 600 {
            // 5-10 minutes - red-orange
            return Color(red: 1.0, green: 0.3, blue: 0.2)
        } else if remaining <= 1800 {
            // 10-30 minutes - orange
            return .orange
        } else if remaining <= 3600 {
            // 30 min - 1 hour - orange-yellow
            return Color(red: 1.0, green: 0.6, blue: 0.0)
        } else if remaining <= 7200 {
            // 1-2 hours - yellow
            return Color(red: 0.9, green: 0.8, blue: 0.0)
        } else if remaining <= 14400 {
            // 2-4 hours - yellow-green
            return Color(red: 0.6, green: 0.8, blue: 0.2)
        } else {
            // > 4 hours - green
            return .green
        }
    }
}

/// A single todo item row in the list
struct TodoRowView: View {
    /// The todo item to display
    let todo: TodoItem
    
    /// Whether this todo is linked to the current work session
    let isLinked: Bool
    
    /// Whether a work session is currently active
    let isWorkSessionActive: Bool
    
    /// Whether this is the first item (can't move up)
    var isFirst: Bool = false
    
    /// Whether this is the last item (can't move down)
    var isLast: Bool = false
    
    /// Callback when checkbox is tapped
    let onToggle: () -> Void
    
    /// Callback when delete is tapped
    let onDelete: () -> Void
    
    /// Callback when link button is tapped
    let onLinkToggle: () -> Void
    
    /// Callback when edit is tapped
    let onEdit: () -> Void
    
    /// Callback when move up is tapped
    var onMoveUp: (() -> Void)? = nil
    
    /// Callback when move down is tapped
    var onMoveDown: (() -> Void)? = nil
    
    /// Callback when drag starts
    var onDragStarted: (() -> Void)? = nil
    
    /// Whether any item is currently being dragged (to hide tooltip)
    var isDragging: Bool = false
    
    /// Hover state for showing delete button and tooltip
    @State private var isHovering = false
    
    /// Whether drag handle is being hovered
    @State private var isDragHandleHovering = false
    
    /// Environment color scheme for tooltip
    @Environment(\.colorScheme) private var colorScheme
    
    /// Check if title is truncated (longer than ~25 chars typically gets cut off)
    private var isTitleLong: Bool {
        todo.title.count > 25
    }
    
    /// High contrast text color for tooltip
    private var tooltipTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    /// Drag handle color based on hover state
    private var dragHandleColor: Color {
        if isDragHandleHovering {
            return .blue
        } else if isHovering {
            return .secondary
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Drag handle (show on hover for incomplete todos)
            if !todo.isCompleted {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(dragHandleColor)
                    .frame(width: 16, height: 20)
                    .contentShape(Rectangle())
                    .scaleEffect(isDragHandleHovering ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDragHandleHovering)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isDragHandleHovering = hovering
                        }
                        if hovering {
                            NSCursor.openHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
            
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            
            // Title and countdown timer
            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.system(.body, design: .default))
                    .strikethrough(todo.isCompleted, color: .secondary)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                
                // Countdown timer (only for incomplete tasks with due dates)
                if let dueDate = todo.dueDate {
                    CountdownTimerView(dueDate: dueDate, isCompleted: todo.isCompleted)
                }
            }
            
            Spacer()
            
            // Link to session button (only show during work session for incomplete todos)
            if isWorkSessionActive && !todo.isCompleted {
                Button(action: onLinkToggle) {
                    Image(systemName: isLinked ? "link.circle.fill" : "link.circle")
                        .foregroundStyle(isLinked ? .blue : .secondary)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .help("Link task to current work session")
            }
            
            // Edit and Delete buttons (show on hover)
            if isHovering && !todo.isCompleted {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.blue)
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isLinked ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(alignment: .bottomLeading) {
            // Instant tooltip overlay - shows full text below the row (hidden while dragging)
            if isHovering && isTitleLong && !isDragging {
                Text(todo.title)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(tooltipTextColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 220, alignment: .leading)
                    .background(
                        TooltipBackground()
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
                    .offset(x: 24, y: 40)
                    .zIndex(100)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}
