// ContentView.swift
// Main caregiver-facing screen. Three flows: text/voice journal, today's log,
// doctor visit prep. Each flow tells the router which task type it is so the
// router can pick the right Gemma 4 model size.

import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject var router: ModelRouter

    var body: some View {
        TabView {
            DailyCheckInView()
                .tabItem { Label("Daily check-in", systemImage: "heart.text.square") }

            LogView()
                .tabItem { Label("Today's log", systemImage: "list.bullet.rectangle") }

            DoctorPrepView()
                .tabItem { Label("Doctor visit prep", systemImage: "stethoscope") }
        }
    }
}

// MARK: - Daily check-in

struct DailyCheckInView: View {
    @EnvironmentObject var router: ModelRouter
    @State private var entryText: String = ""
    @State private var assistantReply: String = ""
    @State private var lastModelUsed: String = ""
    @State private var busy: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachedImage: UIImage?
    @State private var attachedImageData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tell NaniGPT what happened today")
                        .font(.headline)
                    Text("Type a quick note, attach a photo, or both. NaniGPT will log it and queue items for the doctor. Works in English, Hindi, and Spanish.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $entryText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.tertiary))

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Attach photo", systemImage: "camera.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .onChange(of: selectedPhoto) { newItem in
                            Task { await loadImage(from: newItem) }
                        }

                        if attachedImage != nil {
                            Button(role: .destructive) {
                                attachedImage = nil
                                attachedImageData = nil
                                selectedPhoto = nil
                            } label: {
                                Label("Remove", systemImage: "xmark.circle.fill")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let image = attachedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Button(action: { Task { await submit() } }) {
                        HStack {
                            if busy { ProgressView().controlSize(.small) }
                            Text(busy ? "Logging" : "Log it")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy || (entryText.trimmingCharacters(in: .whitespaces).isEmpty && attachedImage == nil))

                    if !assistantReply.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NaniGPT")
                                .font(.headline)
                            Text(assistantReply)
                                .font(.body)
                            Text("Handled by " + lastModelUsed)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("NaniGPT")
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else {
            attachedImage = nil
            attachedImageData = nil
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            return
        }
        let resized = resizeForModel(uiImage, maxDimension: 384)
        attachedImage = resized
        attachedImageData = resized.jpegData(compressionQuality: 0.8)
    }

    private func resizeForModel(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    func submit() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }

        let text = entryText.isEmpty ? "What do you see in this photo?" : entryText
        let result = await router.handleJournalEntry(text, imageData: attachedImageData)
        assistantReply = result.reply
        lastModelUsed = result.modelLabel
        entryText = ""
        attachedImage = nil
        attachedImageData = nil
        selectedPhoto = nil
    }
}

// MARK: - Today's log

struct LogView: View {
    @EnvironmentObject var router: ModelRouter

    private var shareText: String {
        let header = "NaniGPT — Today's Caregiving Log\n\(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))\n"
        let divider = String(repeating: "—", count: 30)
        let entries = router.log.entries.map { "[\($0.timeLabel)] \($0.title): \($0.body)" }
        return header + divider + "\n" + entries.joined(separator: "\n") + "\n" + divider + "\nSent from NaniGPT"
    }

    var body: some View {
        NavigationStack {
            List {
                if router.log.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No entries yet today")
                            .font(.headline)
                        Text("Log a journal entry on the Daily check-in tab.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(router.log.entries) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: entry.icon)
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title).font(.headline)
                                Text(entry.body).font(.body)
                                Text(entry.timeLabel).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Today's log")
            .toolbar {
                if !router.log.entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: shareText) {
                            Label("Send to family", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Doctor visit prep

struct DoctorPrepView: View {
    @EnvironmentObject var router: ModelRouter
    @State private var report: String = ""
    @State private var lastModelUsed: String = ""
    @State private var days: Int = 30
    @State private var busy: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generate a report for the next appointment")
                            .font(.headline)
                        Stepper("Days to include: \(days)", value: $days, in: 7...90, step: 1)
                            .padding(.vertical, 4)
                        Button(action: { Task { await generate() } }) {
                            HStack {
                                if busy { ProgressView().controlSize(.small) }
                                Image(systemName: "doc.text")
                                Text(busy ? "Generating report..." : "Generate report")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy)
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if !report.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.blue)
                                Text("Caregiver Report")
                                    .font(.title3.bold())
                                Spacer()
                                Text(Date(), style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            Text(report)
                                .font(.body)
                                .lineSpacing(4)

                            Divider()

                            HStack {
                                Image(systemName: "cpu")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Compiled by " + lastModelUsed)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                ShareLink(item: shareableReport) {
                                    Label("Send to family", systemImage: "paperplane.fill")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Doctor visit prep")
        }
    }

    private var shareableReport: String {
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        return """
        NaniGPT — Caregiver Report
        \(date) (last \(days) days)
        \(String(repeating: "—", count: 30))
        \(report)
        \(String(repeating: "—", count: 30))
        Compiled by \(lastModelUsed)
        Sent from NaniGPT
        """
    }

    func generate() async {
        busy = true
        defer { busy = false }
        let result = await router.compileDoctorReport(days: days)
        report = result.reply
        lastModelUsed = result.modelLabel
    }
}

#Preview {
    ContentView().environmentObject(ModelRouter.preview())
}
