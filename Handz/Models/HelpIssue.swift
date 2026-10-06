import Foundation

/// The options on the "Get Help with This Job" screen. Each one tells
/// the person plainly what will happen next.
struct HelpIssue: Identifiable, Equatable {
    let id: String
    let label: String
    let icon: String
    let whatHappensNext: String

    private static let review =
        "The job is paused and our team reviews what happened with both of you. You'll get a notification when there's an update."

    static let forCustomer: [HelpIssue] = [
        HelpIssue(id: "worker_no_show", label: "Worker didn't show up", icon: "person.fill.questionmark",
                  whatHappensNext: "The worker is removed from the job right away. If no other workers remain, your job reopens so you can accept another interested worker. You can report this 15 minutes after the scheduled start."),
        HelpIssue(id: "work_incomplete", label: "Work isn't finished", icon: "hourglass", whatHappensNext: review),
        HelpIssue(id: "poor_quality", label: "Poor quality work", icon: "hand.thumbsdown", whatHappensNext: review),
        HelpIssue(id: "property_damage", label: "Something was damaged", icon: "exclamationmark.triangle", whatHappensNext: review),
        HelpIssue(id: "safety_concern", label: "Safety concern", icon: "exclamationmark.shield.fill", whatHappensNext: review),
        HelpIssue(id: "other", label: "Something else", icon: "ellipsis.bubble", whatHappensNext: review),
    ]

    static let forWorker: [HelpIssue] = [
        HelpIssue(id: "customer_no_show", label: "Customer wasn't there / no access", icon: "person.fill.questionmark", whatHappensNext: review),
        HelpIssue(id: "customer_wont_pay", label: "Customer won't pay", icon: "creditcard", whatHappensNext: review),
        HelpIssue(id: "job_not_as_described", label: "Job isn't as described", icon: "doc.text.magnifyingglass", whatHappensNext: review),
        HelpIssue(id: "unsafe_conditions", label: "Unsafe conditions", icon: "exclamationmark.triangle", whatHappensNext: review),
        HelpIssue(id: "safety_concern", label: "Safety concern", icon: "exclamationmark.shield.fill", whatHappensNext: review),
        HelpIssue(id: "other", label: "Something else", icon: "ellipsis.bubble", whatHappensNext: review),
    ]

    static func label(for id: String) -> String {
        (forCustomer + forWorker).first(where: { $0.id == id })?.label ?? "Something else"
    }
}
