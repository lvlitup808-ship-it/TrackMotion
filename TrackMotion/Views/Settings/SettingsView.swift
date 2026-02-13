import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @AppStorage("voiceFeedbackEnabled") var voiceFeedbackEnabled: Bool = true
    @AppStorage("autoPhaseDetection") var autoPhaseDetection: Bool = true
    @AppStorage("kalmanFilterEnabled") var kalmanFilterEnabled: Bool = true
    @AppStorage("processingFPS") var processingFPS: Int = 15
    @AppStorage("defaultCamera") var defaultCamera: String = "back"
    @AppStorage("biometricLockEnabled") var biometricLockEnabled: Bool = false
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled: Bool = false
    @AppStorage("analyticsOptIn") var analyticsOptIn: Bool = false
    @AppStorage("autoDeleteDays") var autoDeleteDays: Int = 0
    @AppStorage("watermarkEnabled") var watermarkEnabled: Bool = true
    @AppStorage("appTheme") var appTheme: String = "dark"

    @State private var showingExportData = false
    @State private var showingDeleteAlert = false
    @State private var showingAbout = false
    @State private var showingCalibration = false

    var body: some View {
        NavigationStack {
            List {
                // Analysis settings
                Section("Analysis") {
                    Toggle("Voice Feedback", isOn: $voiceFeedbackEnabled)

                    Toggle("Auto Phase Detection", isOn: $autoPhaseDetection)

                    Toggle("Kalman Filtering (Smoothing)", isOn: $kalmanFilterEnabled)

                    Stepper(
                        "Processing: \(processingFPS) fps",
                        value: $processingFPS,
                        in: 5...30,
                        step: 5
                    )

                    NavigationLink("Camera Calibration") {
                        CalibrationView()
                    }
                }

                // Video settings
                Section("Video & Recording") {
                    Picker("Default Camera", selection: $defaultCamera) {
                        Text("Back Camera").tag("back")
                        Text("Front Camera").tag("front")
                    }

                    Toggle("Watermark on Exports", isOn: $watermarkEnabled)
                }

                // Privacy & Security
                Section("Privacy & Security") {
                    Toggle("Biometric Lock (Face ID / Touch ID)", isOn: $biometricLockEnabled)
                        .onChange(of: biometricLockEnabled) { _, enabled in
                            if enabled { authenticateBiometric() }
                        }

                    Toggle("iCloud Sync (Pro Feature)", isOn: $iCloudSyncEnabled)

                    Toggle("Anonymous Usage Analytics", isOn: $analyticsOptIn)

                    Picker("Auto-Delete Old Videos", selection: $autoDeleteDays) {
                        Text("Never").tag(0)
                        Text("After 30 Days").tag(30)
                        Text("After 60 Days").tag(60)
                        Text("After 90 Days").tag(90)
                    }
                }

                // Data management
                Section("Data") {
                    Button {
                        showingExportData = true
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink {
                        SessionDetailExportView()
                    } label: {
                        Label("Export Sessions to CSV", systemImage: "tablecells")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash.fill")
                    }
                }

                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                }

                // App info
                Section("About") {
                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TrackMotion")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Version 1.0.0")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link("Privacy Policy", destination: URL(string: "https://trackmotion.app/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://trackmotion.app/terms")!)
                    Link("Contact Support", destination: URL(string: "mailto:support@trackmotion.app")!)

                    Button("Rate TrackMotion") {
                        requestAppStoreReview()
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .alert("Delete All Data", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all athlete profiles, sessions, and videos. This cannot be undone.")
        }
        .sheet(isPresented: $showingExportData) {
            DataExportView()
        }
    }

    private func authenticateBiometric() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricLockEnabled = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Enable biometric lock for athlete profiles"
        ) { success, _ in
            DispatchQueue.main.async {
                if !success { biometricLockEnabled = false }
            }
        }
    }

    private func deleteAllData() {
        AthleteStore.shared.deleteAll()
    }

    private func requestAppStoreReview() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Camera Calibration View
struct CalibrationView: View {
    @State private var calibrationState: CalibrationState = .initial
    @State private var realWorldDistance: String = "10"
    @State private var pixelsPerMeter: Double = 200
    @AppStorage("pixelsPerMeter") var savedPixelsPerMeter: Double = 200

    enum CalibrationState {
        case initial, tapFirst, tapSecond, calculating, complete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera Calibration")
                        .font(.title2.weight(.bold))

                    Text("Calibrate the camera to improve split time accuracy. You'll need a known distance visible in your recording setup (e.g., lane lines at 10m intervals).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))

                // Method selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Known Distance")
                        .font(.headline)

                    HStack {
                        TextField("Distance (meters)", text: $realWorldDistance)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        Text("meters")
                            .foregroundStyle(.secondary)
                    }

                    Text("Enter the distance you can identify in frame (e.g., 10 for a 10m lane segment)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))

                // Current calibration
                VStack(spacing: 8) {
                    Text("Current Calibration")
                        .font(.headline)

                    Text("\(Int(savedPixelsPerMeter)) pixels/meter")
                        .font(.system(.title, design: .monospaced).weight(.bold))
                        .foregroundStyle(.brandOrange)

                    Text("Used for split time and velocity estimates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))

                // Calibration button
                Button {
                    performCalibration()
                } label: {
                    Label("Record Calibration Video", systemImage: "camera.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brandOrange, in: RoundedRectangle(cornerRadius: 14))
                }

                // Accuracy estimate
                VStack(alignment: .leading, spacing: 8) {
                    Label("Expected Accuracy", systemImage: "target")
                        .font(.subheadline.weight(.semibold))

                    VStack(spacing: 4) {
                        AccuracyRow(label: "10m splits", accuracy: "±0.05-0.10s")
                        AccuracyRow(label: "100m total", accuracy: "±0.2-0.5s")
                        AccuracyRow(label: "Peak velocity", accuracy: "±0.3 m/s")
                    }

                    Text("Accuracy improves with stationary camera and proper calibration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(16)
        }
        .navigationTitle("Calibration")
        .background(Color.backgroundPrimary)
    }

    private func performCalibration() {
        // In full implementation: open camera, let user tap two points,
        // measure pixel distance, divide by real-world distance
        guard let dist = Double(realWorldDistance), dist > 0 else { return }
        // Placeholder: assume user tapped 2000px apart for 10m = 200 px/m
        let assumedPixelDistance: Double = 2000
        savedPixelsPerMeter = assumedPixelDistance / dist
        BiomechanicsCalculator.shared.pixelsPerMeter = savedPixelsPerMeter
    }
}

struct AccuracyRow: View {
    let label: String
    let accuracy: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(accuracy)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .foregroundStyle(.formSuccess)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.brandOrange.gradient)
                            .frame(width: 100, height: 100)
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 4) {
                        Text("TrackMotion")
                            .font(.largeTitle.weight(.bold))
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("AI-powered sprint analysis for track and field athletes. Real-time biomechanical feedback to help coaches and athletes reach elite performance.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Technology")
                            .font(.headline)
                        TechRow(icon: "brain.head.profile", name: "Vision Framework", detail: "Pose estimation")
                        TechRow(icon: "cpu.fill", name: "CoreML", detail: "Form classification")
                        TechRow(icon: "video.fill", name: "AVFoundation", detail: "Video capture & processing")
                        TechRow(icon: "chart.bar.fill", name: "Swift Charts", detail: "Data visualization")
                        TechRow(icon: "icloud.fill", name: "CloudKit", detail: "Optional sync")
                    }
                    .padding()
                    .background(Color.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    Text("Built with ❤️ for coaches and athletes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct TechRow: View {
    let icon: String
    let name: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.brandOrange)
                .frame(width: 24)
            Text(name)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Placeholder views for export/calibration sheets
struct SessionDetailExportView: View {
    var body: some View {
        Text("CSV Export")
            .navigationTitle("Export CSV")
    }
}

struct DataExportView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.brandOrange)

                Text("Export Your Data")
                    .font(.title2.weight(.bold))

                Text("Export all athlete profiles, session data, and metrics as a ZIP archive.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    exportData()
                } label: {
                    Label("Export ZIP Archive", systemImage: "archivebox.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brandOrange, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
            }
            .navigationTitle("Export Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func exportData() {
        // Implementation: serialize AthleteStore to JSON, zip with videos, share
        dismiss()
    }
}
