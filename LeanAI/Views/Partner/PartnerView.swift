import SwiftUI
import SwiftData

struct PartnerView: View {
    let myProfile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cloudKit = CloudKitSharingService()
    @State private var partnerCodeInput = ""
    @State private var showCodeEntry = false
    @State private var copied = false

    private var savedPartnerCode: String { myProfile.partnerPairCode }
    private var hasSavedCode: Bool { !savedPartnerCode.isEmpty }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // My share code card
                    myCodeCard

                    // Partner summary (if code saved)
                    if hasSavedCode {
                        partnerSummarySection
                    } else {
                        connectPartnerCard
                    }

                    // Info footer
                    VStack(spacing: 6) {
                        Label("Each person keeps their own data", systemImage: "lock.shield.fill")
                            .font(.caption).foregroundColor(.secondary)
                        Label("Only today's summary is shared — no food logs", systemImage: "eye.slash.fill")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Partner")
        .task {
            // Publish my own summary whenever this view appears
            await publishMySummary()
            // Refresh partner's summary if we have their code
            if hasSavedCode {
                await refreshPartner()
            }
        }
        .sheet(isPresented: $showCodeEntry) {
            codeEntrySheet
        }
    }

    // MARK: - My Share Code Card

    private var myCodeCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Your share code", systemImage: "qrcode")
                    .font(.headline).foregroundColor(.white)
                Spacer()
            }

            Text(myProfile.pairCode)
                .font(.system(size: 38, weight: .black, design: .monospaced))
                .foregroundColor(.leanGreen)
                .tracking(8)
                .padding(.vertical, 8)

            Text("Give this code to your partner so they can see your daily summary")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)

            Button(action: copyCode) {
                Label(copied ? "Copied!" : "Copy Code", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(copied ? Color.leanGreen : Color.leanBlue)
                    .cornerRadius(10)
                    .animation(.easeInOut(duration: 0.2), value: copied)
            }
        }
        .cardStyle()
    }

    // MARK: - Connect Partner Card

    private var connectPartnerCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.2.circle")
                .font(.system(size: 52))
                .foregroundColor(.leanPurple.opacity(0.7))

            VStack(spacing: 6) {
                Text("Connect with your partner")
                    .font(.title3.bold()).foregroundColor(.white)
                Text("Enter their 6-character code to see their daily progress. They'll need to enter yours too.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }

            Button(action: { showCodeEntry = true }) {
                Label("Enter Partner's Code", systemImage: "person.badge.plus")
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.leanPurple).cornerRadius(14)
            }
        }
        .cardStyle()
    }

    // MARK: - Partner Summary Section

    @ViewBuilder
    private var partnerSummarySection: some View {
        let summary = cloudKit.partnerSummary ?? cloudKit.loadCachedSummary(pairCode: savedPartnerCode)

        VStack(spacing: 14) {
            // Refresh header
            HStack {
                Text("Partner's Status")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                if cloudKit.isSyncing {
                    ProgressView().tint(.leanBlue).scaleEffect(0.8)
                } else {
                    Button(action: { Task { await refreshPartner() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.leanBlue)
                    }
                }
            }

            if let s = summary {
                partnerSummaryCard(s)
            } else if let error = cloudKit.lastError {
                ErrorBanner(message: error)
            } else {
                HStack(spacing: 10) {
                    ProgressView().tint(.leanBlue)
                    Text("Loading partner's data…")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding()
            }

            // Change partner code option
            Button(action: { showCodeEntry = true }) {
                Label("Change partner code (\(savedPartnerCode))", systemImage: "pencil")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func partnerSummaryCard(_ s: PartnerSummaryData) -> some View {
        VStack(spacing: 14) {
            // Partner header
            HStack(spacing: 14) {
                Circle()
                    .fill(LinearGradient(colors: [.leanPurple, .leanBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(Text(String(s.name.prefix(1)).uppercased()).font(.title2.bold()).foregroundColor(.white))

                VStack(alignment: .leading, spacing: 3) {
                    Text(s.name).font(.title3.bold()).foregroundColor(.white)
                    Text("\(s.currentWeightKg.kgFormatted) → \(s.targetWeightKg.kgFormatted)")
                        .font(.caption).foregroundColor(.secondary)
                    if let syncDate = cloudKit.loadCachedSyncDate(pairCode: savedPartnerCode) {
                        Text("Updated \(syncDate.timeFormatted)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer()
                // Status badge
                VStack(spacing: 2) {
                    Image(systemName: s.isOnTrackToday ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(s.isOnTrackToday ? .leanGreen : .leanOrange)
                        .font(.title2)
                    Text(s.isOnTrackToday ? "On track" : "Off track")
                        .font(.caption2)
                        .foregroundColor(s.isOnTrackToday ? .leanGreen : .leanOrange)
                }
            }

            Divider().background(Color.leanGray.opacity(0.3))

            // Today's stats
            HStack {
                PartnerStat(label: "Calories", value: "\(Int(s.todayCalories))", target: "\(Int(s.todayCalorieTarget))", color: .leanBlue)
                PartnerStat(label: "Protein", value: "\(Int(s.todayProtein))g", target: "\(Int(s.todayProteinTarget))g", color: .leanOrange)
                PartnerStat(label: "Burned", value: "\(Int(s.todayBurned))", target: "kcal", color: .leanGreen)
            }

            Divider().background(Color.leanGray.opacity(0.3))

            // Progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall progress")
                        .font(.caption).foregroundColor(.secondary)
                    ProgressBarView(value: s.progressPercent, color: .leanPurple)
                    Text("Lost \(String(format: "%.1f", s.weightLostKg)) kg · \(Int(s.progressPercent * 100))% to goal")
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Streak").font(.caption).foregroundColor(.secondary)
                    Text("🔥 \(s.streak)d")
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundColor(.leanYellow)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Code Entry Sheet

    private var codeEntrySheet: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("Enter Partner's Code")
                        .font(.title2.bold()).foregroundColor(.white).padding(.top, 32)
                    Text("Ask your partner to go to Me → Partner and share their 6-character code with you.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)

                    TextField("e.g. AK7X3Q", text: $partnerCodeInput)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.cardBackground).cornerRadius(14)
                        .padding(.horizontal)

                    if let error = cloudKit.lastError {
                        ErrorBanner(message: error).padding(.horizontal)
                    }

                    Button(action: savePartnerCode) {
                        Group {
                            if cloudKit.isSyncing {
                                HStack { ProgressView().tint(.black); Text("Looking up…") }
                            } else {
                                Text("Connect")
                            }
                        }
                        .font(.headline).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding()
                        .background(partnerCodeInput.count == 6 ? Color.leanPurple : Color.leanGray)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .disabled(partnerCodeInput.count < 6 || cloudKit.isSyncing)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCodeEntry = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func copyCode() {
        UIPasteboard.general.string = myProfile.pairCode
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { copied = false }
        }
    }

    private func savePartnerCode() {
        Task {
            let code = partnerCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if let summary = await cloudKit.fetchPartnerSummary(pairCode: code) {
                myProfile.partnerPairCode = code
                try? modelContext.save()
                showCodeEntry = false
                _ = summary
            }
        }
    }

    private func refreshPartner() async {
        guard hasSavedCode else { return }
        _ = await cloudKit.fetchPartnerSummary(pairCode: savedPartnerCode)
    }

    private func publishMySummary() async {
        // Use today's log if it exists; pass nil otherwise (buildSummary handles nil safely)
        let todayLog = myProfile.dailyLogs.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: Date())
        })
        let streak = NutritionCalculator.currentDeficitStreak(logs: myProfile.dailyLogs, calorieTarget: myProfile.dailyCalorieTarget)
        let summary = CloudKitSharingService.buildSummary(profile: myProfile, todayLog: todayLog, streak: streak)
        await cloudKit.publishSummary(summary)
    }

    private var profile: UserProfile { myProfile }
}
