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
                List {
                    ForEach(historyManager.jobs) { job in
                        HistoryRowView(job: job)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
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
            HStack(alignment: .top) {
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
                    
                    if job.status == .completed, let text = job.resultText {
                        Text(text)
                            .font(.body)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    } else if job.status == .failed || job.status == .cancelled {
                        Text(job.errorMessage ?? "Ошибка транскрибации")
                            .font(.body)
                            .foregroundColor(.red)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                            Text("Обработка...")
                                .font(.body)
                                .foregroundColor(.secondary)
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
                    } else if job.status == .running {
                        Button(action: {
                            manager.cancelJob(id: job.id)
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Отменить")
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
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        // Click on the entire row to copy if completed
        .onTapGesture {
            if job.status == .completed, let text = job.resultText {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
                
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    justCopied = false
                }
            }
        }
    }
}
