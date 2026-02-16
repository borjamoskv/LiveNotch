import SwiftUI
import EventKit

// ═══════════════════════════════════════════════════
// MARK: - 📅 Premium Calendar Panel
// ═══════════════════════════════════════════════════
// Premium timeline view with meeting countdown,
// one-click join, schedule overview, and urgency indicators.

struct CalendarPanelView: View {
    @ObservedObject var calendar = CalendarService.shared
    @ObservedObject var viewModel: NotchViewModel
    
    @State private var isHovered = false
    @State private var pulsePhase: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            headerRow()
            
            Divider()
                .background(Color.white.opacity(0.04))
                .padding(.horizontal, 8)
            
            // ── Content ──
            if !calendar.hasAccess {
                permissionRequest()
            } else if calendar.todayEvents.isEmpty {
                emptyState()
            } else {
                eventTimeline()
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(DS.Spring.breath) {
                pulsePhase = 1.0
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Header
    // ═══════════════════════════════════════
    
    @ViewBuilder
    private func headerRow() -> some View {
        HStack {
            // Calendar icon with urgency glow
            ZStack {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                // Urgency pulse for imminent meetings
                if let next = calendar.nextEvent, next.minutesUntil < 15 {
                    Circle()
                        .fill(Color(nsColor: next.urgencyColor).opacity(0.3 * pulsePhase))
                        .frame(width: 24, height: 24)
                        .blur(radius: 4)
                }
            }
            
            Text("Schedule")
                .font(DS.Fonts.smallBold)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Event count badge
            if !calendar.todayEvents.isEmpty {
                Text("\(calendar.todayEvents.count)")
                    .font(DS.Fonts.microBold)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Capsule())
            }
            
            // Close
            Button(action: {
                withAnimation(DS.Anim.springFast) {
                    viewModel.isCalendarVisible = false
                }
                HapticManager.shared.play(.button)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(DS.Fonts.body)
                    .foregroundColor(.white.opacity(0.15))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Event Timeline
    // ═══════════════════════════════════════
    
    @ViewBuilder
    private func eventTimeline() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                // Next meeting countdown — hero card
                if let next = calendar.nextEvent {
                    nextMeetingCard(event: next)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                }
                
                // Remaining events — compact list
                if calendar.todayEvents.count > 1 {
                    VStack(spacing: 1) {
                        ForEach(Array(calendar.todayEvents.dropFirst())) { event in
                            eventRow(event: event)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxHeight: 200)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Next Meeting Hero Card
    // ═══════════════════════════════════════
    
    @ViewBuilder
    private func nextMeetingCard(event: CalendarService.CalEvent) -> some View {
        let urgency = Color(nsColor: event.urgencyColor)
        let isImminent = event.minutesUntil < 10
        
        VStack(alignment: .leading, spacing: 6) {
            meetingCardHeader(event: event, urgency: urgency, isImminent: isImminent)
            
            // Meeting title
            Text(event.title)
                .font(DS.Fonts.smallBold)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
            
            meetingCardTimeRow(event: event, urgency: urgency)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(urgency.opacity(isImminent ? 0.06 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(urgency.opacity(isImminent ? 0.15 : 0.06), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func meetingCardHeader(event: CalendarService.CalEvent, urgency: Color, isImminent: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(urgency)
                .frame(width: 6, height: 6)
                .shadow(color: urgency.opacity(0.6), radius: isImminent ? 4 : 2)
                .scaleEffect(isImminent ? (1.0 + pulsePhase * 0.3) : 1.0)
            
            if let calColor = event.calendarColor {
                Circle()
                    .fill(Color(nsColor: calColor))
                    .frame(width: 4, height: 4)
            }
            
            Text(isImminent ? "NEXT" : "UPCOMING")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundColor(urgency.opacity(0.9))
                .tracking(1.2)
            
            Spacer()
            
            Text(countdownText(minutes: event.minutesUntil))
                .font(DS.Fonts.tinyMono)
                .foregroundColor(urgency.opacity(0.8))
        }
    }
    
    @ViewBuilder
    private func meetingCardTimeRow(event: CalendarService.CalEvent, urgency: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
            
            Text("\(event.timeString) — \(endTimeString(event: event))")
                .font(DS.Fonts.tinyMono)
                .foregroundColor(.white.opacity(0.4))
            
            Spacer()
            
            if let meetingURL = event.meetingURL {
                Button(action: {
                    NSWorkspace.shared.open(meetingURL)
                    HapticManager.shared.play(.success)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 8))
                        Text("Join")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(urgency.opacity(0.3))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(urgency.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Event Row (Compact)
    // ═══════════════════════════════════════
    
    @ViewBuilder
    private func eventRow(event: CalendarService.CalEvent) -> some View {
        HStack(spacing: 8) {
            // Timeline spine — vertical line with dot
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 1)
                Circle()
                    .fill(Color(nsColor: event.calendarColor ?? .systemGray))
                    .frame(width: 5, height: 5)
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 1)
            }
            .frame(width: 5)
            
            // Time
            Text(event.timeString)
                .font(DS.Fonts.tinyMono)
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 36, alignment: .leading)
            
            // Title
            Text(event.title)
                .font(DS.Fonts.small)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
            
            Spacer()
            
            // Duration
            Text(durationText(event: event))
                .font(DS.Fonts.micro)
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Empty / Permission States
    // ═══════════════════════════════════════
    
    @ViewBuilder
    private func emptyState() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.15))
            
            Text("Clear schedule")
                .font(DS.Fonts.small)
                .foregroundColor(.white.opacity(0.3))
            
            Text("No more events today")
                .font(DS.Fonts.micro)
                .foregroundColor(.white.opacity(0.15))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    @ViewBuilder
    private func permissionRequest() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(.white.opacity(0.2))
            
            Text("Calendar access needed")
                .font(DS.Fonts.small)
                .foregroundColor(.white.opacity(0.4))
            
            Button(action: {
                calendar.requestAccess()
            }) {
                Text("Grant Access")
                    .font(DS.Fonts.microBold)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.blue.opacity(0.15), lineWidth: 0.5)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // ═══════════════════════════════════════
    // MARK: - Helpers
    // ═══════════════════════════════════════
    
    private func countdownText(minutes: Int) -> String {
        if minutes < 0 { return "NOW" }
        if minutes < 1 { return "< 1m" }
        if minutes < 60 { return "in \(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "in \(h)h\(m)m" : "in \(h)h"
    }
    
    private func endTimeString(event: CalendarService.CalEvent) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.endDate)
    }
    
    private func durationText(event: CalendarService.CalEvent) -> String {
        let mins = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60
        let m = mins % 60
        return m > 0 ? "\(h)h\(m)m" : "\(h)h"
    }
}
