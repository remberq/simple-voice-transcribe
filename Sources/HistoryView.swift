import SwiftUI
import AppKit

struct HistoryView: View {
    @ObservedObject var historyManager = TranscriptionHistoryManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if historyManager.jobs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("История пуста")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(historyManager.jobs) { job in
                            HistoryRowView(job: job)
                                .id(job.id) // Needed for scroll
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .onChangeCompat(of: historyManager.jobs.first?.id) { newId in
                        if let id = newId {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }
            }
            
            // Hidden button to close window on Escape
            Button("") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .frame(width: 450, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct HistoryRowView: View {
    let job: TranscriptionJob
    @ObservedObject var manager = TranscriptionHistoryManager.shared
    @State private var justCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(job.relativeTimeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(job.formattedSize) \(job.fileFormat)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(job.providerName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ZStack(alignment: .leading) {
                        // Hidden placeholder to force consistent 2-line height
                        Text("A\nB")
                            .font(.body)
                            .hidden()
                        
                        Group {
                            if job.status == .completed, let text = job.resultText {
                                let displayText = text.count > 100 ? String(text.prefix(100)) + "..." : text
                                Text(displayText)
                                    .font(.body)
                                    .lineLimit(2)
                                    .foregroundColor(.primary)
                            } else if job.status == .failed || job.status == .cancelled {
                                Text(job.errorMessage ?? "Ошибка транскрибации")
                                    .font(.body)
                                    .lineLimit(2)
                                    .foregroundColor(.red)
                            } else if job.status == .uploading {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 10, height: 10)
                                    Text("Отправка файла...")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            } else if job.status == .processing {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 10, height: 10)
                                    Text("Распознавание...")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Actions (Copy / Cancel / Delete)
                HStack(spacing: 12) {
                    if job.status == .completed {
                        Button(action: {
                            if let text = job.resultText {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(text, forType: .string)
                                
                                manager.copiedJobId = job.id
                                
                                justCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    justCopied = false
                                }
                            }
                        }) {
                            Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                                .foregroundColor(justCopied ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Скопировать текст")
                    } else if job.status == .uploading || job.status == .processing {
                        Button(action: {
                            manager.cancelJob(id: job.id)
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Отменить")
                    }
                    
                    if job.status == .failed || job.status == .cancelled || job.status == .completed {
                        Button(action: {
                            OverlayController.shared.retryTranscription(id: job.id)
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Повторить транскрибацию")
                    }
                    
                    Button(action: {
                        manager.deleteJob(id: job.id)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Удалить")
                }
            }
        }
        .padding(12)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(manager.copiedJobId == job.id ? Color.orange.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                
                if job.status == .uploading && job.uploadProgress > 0 {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: geo.size.width * CGFloat(job.uploadProgress))
                            .animation(.linear(duration: 0.2), value: job.uploadProgress)
                    }
                }
            }
        )
        // Click on the entire row to copy if completed
        .onTapGesture {
            if job.status == .completed, let text = job.resultText {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
                
                manager.copiedJobId = job.id
                
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    justCopied = false
                }
            }
        }
    }
}
