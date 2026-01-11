import Foundation
import UserNotifications

/// Service that manages notifications for the Pomodoro app
class NotificationService {
    /// Notification identifier types
    enum NotificationType: String {
        case workComplete = "work-complete"
        case restComplete = "rest-complete"
        case idleReminder = "idle-reminder"
        case todoDue = "todo-due"
        case todoReminder = "todo-reminder"
    }
    
    /// Reminder intervals in minutes before due date
    static let reminderIntervals: [Int] = [60, 30, 10, 5]
    
    /// Initialize the notification service and request permissions
    init() {
        requestPermission()
    }
    
    /// Request notification permission from the user
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
                return
            }
            
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    /// Send a work session completed notification
    func notifyWorkComplete() {
        sendNotification(
            type: .workComplete,
            title: "Work Session Complete",
            body: "Good job! Time to take a break.",
            timeInterval: 1
        )
    }
    
    /// Send a rest session completed notification
    func notifyRestComplete() {
        sendNotification(
            type: .restComplete,
            title: "Break Time Over",
            body: "Ready to get back to work?",
            timeInterval: 1
        )
    }
    
    /// Send an idle reminder notification
    /// - Parameter timeToNextReminder: Time in seconds until the next reminder
    func notifyIdleReminder(timeToNextReminder: TimeInterval) {
        sendNotification(
            type: .idleReminder,
            title: "Pomodoro Timer Idle",
            body: "Ready to start a new work session?",
            timeInterval: 1
        )
    }
    
    /// Generic method to send a notification
    /// - Parameters:
    ///   - type: The type of notification
    ///   - title: The notification title
    ///   - body: The notification body text
    ///   - timeInterval: Time interval in seconds before showing the notification
    private func sendNotification(type: NotificationType, title: String, body: String, timeInterval: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // Create request with unique identifier
        let identifier = "\(type.rawValue)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add the request
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove any pending notifications of a specific type
    /// - Parameter type: The type of notifications to remove
    func removePendingNotifications(ofType type: NotificationType) {
        let center = UNUserNotificationCenter.current()
        
        center.getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.filter { 
                $0.identifier.hasPrefix(type.rawValue) 
            }.map { $0.identifier }
            
            center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
    
    /// Remove all pending notifications
    func removeAllPendingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Todo Due Date Notifications
    
    /// Schedule reminder notifications for a todo at specific intervals
    /// - Parameters:
    ///   - todoId: The unique identifier of the todo
    ///   - title: The todo's title
    ///   - dueDate: When the todo is due
    func scheduleTodoReminders(todoId: UUID, title: String, dueDate: Date) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        
        // Schedule reminders at 1 hour, 30 min, 10 min, and 5 min before
        for minutesBefore in Self.reminderIntervals {
            let reminderDate = dueDate.addingTimeInterval(-Double(minutesBefore * 60))
            
            // Only schedule if the reminder time is in the future
            guard reminderDate > now else { continue }
            
            // Create notification content with time remaining
            let content = UNMutableNotificationContent()
            content.title = "Task Reminder"
            content.body = "\(title)\n⏰ \(formatTimeRemaining(minutesBefore)) remaining"
            content.sound = UNNotificationSound.default
            
            // Create trigger based on reminder date
            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            // Create request with unique identifier for this reminder
            let identifier = "\(NotificationType.todoReminder.rawValue)-\(todoId.uuidString)-\(minutesBefore)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // Add the request
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling todo reminder: \(error.localizedDescription)")
                }
            }
        }
        
        // Also schedule a notification at the exact due time
        if dueDate > now {
            let content = UNMutableNotificationContent()
            content.title = "⚠️ Task Due Now!"
            content.body = title
            content.sound = UNNotificationSound.default
            
            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let identifier = "\(NotificationType.todoDue.rawValue)-\(todoId.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling todo due notification: \(error.localizedDescription)")
                }
            }
            
            // Schedule overdue notification 1 minute after deadline
            let overdueDate = dueDate.addingTimeInterval(60)
            let overdueContent = UNMutableNotificationContent()
            overdueContent.title = "🔴 OVERDUE: Task Deadline Exceeded!"
            overdueContent.body = "\(title)\n❌ This task is now past its deadline"
            overdueContent.sound = UNNotificationSound.default
            overdueContent.interruptionLevel = .timeSensitive
            
            let overdueTriggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: overdueDate
            )
            let overdueTrigger = UNCalendarNotificationTrigger(dateMatching: overdueTriggerDate, repeats: false)
            
            let overdueIdentifier = "\(NotificationType.todoDue.rawValue)-\(todoId.uuidString)-overdue"
            let overdueRequest = UNNotificationRequest(identifier: overdueIdentifier, content: overdueContent, trigger: overdueTrigger)
            
            center.add(overdueRequest) { error in
                if let error = error {
                    print("Error scheduling overdue notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Format time remaining for notification body
    private func formatTimeRemaining(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            return "\(hours) hour"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    /// Remove all scheduled notifications for a todo
    /// - Parameter todoId: The unique identifier of the todo
    func removeTodoNotifications(todoId: UUID) {
        let center = UNUserNotificationCenter.current()
        
        // Remove the due notification and overdue notification
        let dueIdentifier = "\(NotificationType.todoDue.rawValue)-\(todoId.uuidString)"
        let overdueIdentifier = "\(NotificationType.todoDue.rawValue)-\(todoId.uuidString)-overdue"
        
        // Remove all reminder notifications
        var identifiersToRemove = [dueIdentifier, overdueIdentifier]
        for minutesBefore in Self.reminderIntervals {
            identifiersToRemove.append("\(NotificationType.todoReminder.rawValue)-\(todoId.uuidString)-\(minutesBefore)")
        }
        
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
    }
    
    // Legacy methods for compatibility
    func scheduleTodoDueNotification(todoId: UUID, title: String, dueDate: Date) {
        scheduleTodoReminders(todoId: todoId, title: title, dueDate: dueDate)
    }
    
    func removeTodoDueNotification(todoId: UUID) {
        removeTodoNotifications(todoId: todoId)
    }
}
