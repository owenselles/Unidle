#!/usr/bin/env swift
// Watches a running copy of Unidle and reports, for each pointer movement it
// observes: how far the cursor travelled, whether it returned to where it
// started, and whether the system idle clock was reset.
//
// Run it with the app running and then leave the machine alone:
//     swift Tools/verify-movement.swift [seconds]

import CoreGraphics
import Foundation

let runFor = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 120 : 120
let anyInput = CGEventType(rawValue: ~0)!

func idle() -> Double { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput) }
func pointer() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
    Double(((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot())
}

print("watching for pointer movements for \(Int(runFor))s — leave the machine alone")
var anchor = pointer()
var previousIdle = idle()
var seen = 0
let deadline = Date().addingTimeInterval(runFor)

while Date() < deadline {
    Thread.sleep(forTimeInterval: 0.02)
    let now = idle()

    // A movement just happened if the idle clock collapsed from a high value.
    if previousIdle > 20, now < 5 {
        seen += 1
        var furthest = 0.0
        let start = Date()
        while Date().timeIntervalSince(start) < 0.7 {
            furthest = max(furthest, distance(pointer(), anchor))
            Thread.sleep(forTimeInterval: 0.01)
        }
        Thread.sleep(forTimeInterval: 0.2)
        let drift = distance(pointer(), anchor)
        print(String(format: "  movement %d: idle %.0fs -> %.1fs | travelled %.0fpt | drift %.2fpt %@",
                     seen, previousIdle, now, furthest, drift,
                     (drift < 1 ? "OK" : "DRIFTING") as NSString))
        anchor = pointer()
    }
    previousIdle = now
}

if seen == 0 {
    print("  no movement observed — was the machine in use, or the app switched off?")
}
