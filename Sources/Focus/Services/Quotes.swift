import Foundation

/// Short motivational lines shown on the break screen.
enum Quotes {
    static let all: [(text: String, author: String)] = [
        ("Well begun is half done.", "Aristotle"),
        ("It does not matter how slowly you go, so long as you do not stop.", "Confucius"),
        ("Amateurs sit and wait for inspiration, the rest of us just get up and go to work.", "Stephen King"),
        ("The secret of getting ahead is getting started.", "Mark Twain"),
        ("Simplicity is the ultimate sophistication.", "Leonardo da Vinci"),
        ("What we fear doing most is usually what we most need to do.", "Tim Ferriss"),
        ("You may delay, but time will not.", "Benjamin Franklin"),
        ("Done is better than perfect.", "Sheryl Sandberg"),
        ("Action is the foundational key to all success.", "Pablo Picasso"),
        ("Rest is not idleness.", "John Lubbock"),
        ("Deep work is the ability to focus without distraction.", "Cal Newport"),
        ("Nothing is less productive than to make more efficient what should not be done at all.", "Peter Drucker"),
        ("Concentrate all your thoughts upon the work in hand.", "Alexander Graham Bell"),
        ("Tension is who you think you should be. Relaxation is who you are.", "Chinese proverb"),
        ("Almost everything will work again if you unplug it for a few minutes.", "Anne Lamott"),
    ]

    static func random() -> (text: String, author: String) {
        all.randomElement() ?? all[0]
    }
}

/// Notification copy, drawn at random.
enum NotificationCopy {
    static let flowTitles = [
        "Well done! Your session is complete.",
        "Great work session!",
        "Good job — session finished.",
        "Session complete. Awesome!",
        "Nice work! Focus time is over.",
        "You crushed it!",
        "Another session completed.",
    ]

    static let flowBodies = [
        "It's time to have a break.",
        "Time to relax and have a break.",
        "You've earned a well-deserved break!",
        "Recharge time! Enjoy a break.",
        "Take a deep breath and unwind.",
        "Let's pause and refresh.",
    ]

    static let breakTitles = [
        "Your break is over.",
        "Ready to focus again?",
        "Break's done. Time to work!",
        "Back to it! Let's focus.",
        "Hope you enjoyed your break!",
    ]

    static let breakBodies = [
        "Your next session is waiting.",
        "Let's get back to work.",
        "Let's get things done.",
        "Time to get back into focus.",
        "You're all set to dive back in.",
    ]
}
