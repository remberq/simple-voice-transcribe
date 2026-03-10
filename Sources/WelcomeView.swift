import SwiftUI
import AVFoundation

struct WelcomeView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var microphoneStatus = PermissionsCoordinator.shared.microphoneAuthorizationStatus
    @State private var showPermissionError = false
    
    let onRequestMicrophone: (@escaping (AVAuthorizationStatus) -> Void) -> Void
    let onStart: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Добро пожаловать в Voice Overlay")
                        .font(.title2)
                        .bold()
                    Text("Приложение запускается из меню-бара и записывает голос в текст по горячей клавише.")
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    GroupBox("Микрофон") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(microphoneStatusColor)
                                    .frame(width: 8, height: 8)
                                Text(microphoneStatusText)
                                    .font(.subheadline)
                            }
                            Text("Разрешение запрашивается только после явного нажатия кнопки.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button(microphoneButtonTitle) {
                                showPermissionError = false
                                onRequestMicrophone { newStatus in
                                    microphoneStatus = newStatus
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                    
                    GroupBox("Горячая клавиша") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("По умолчанию: Cmd+Shift+Space")
                                .font(.subheadline)
                            Text("Эта комбинация показывает или скрывает overlay и запускает запись.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            Text("Пауза записи: \(HotkeyFormatter.format(keyCode: settings.pauseHotkeyKeyCode, modifiers: settings.pauseHotkeyModifiers))")
                                .font(.subheadline)
                            Text("Во время записи нажмите эту клавишу, чтобы поставить запись на паузу. Клавишу можно изменить в настройках.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Divider()

                            Text("Отмена записи: \(HotkeyFormatter.format(keyCode: settings.cancelHotkeyKeyCode, modifiers: settings.cancelHotkeyModifiers))")
                                .font(.subheadline)
                            Text("Во время записи или паузы нажмите эту клавишу, чтобы отменить запись без отправки в транскрибацию.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }

                    GroupBox("Хранение API-ключей") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Хранить API-ключи в Keychain", isOn: $settings.storeAPIKeyInKeychain)
                            Text("Если выключено, ключи хранятся только в памяти до закрытия приложения.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()

            HStack {
                if showPermissionError && microphoneStatus != .authorized {
                    Text("Для работы приложения разрешите доступ к микрофону.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
                Button("Закрыть", action: onClose)
                Button("Начать") {
                    if microphoneStatus == .authorized {
                        onStart()
                    } else {
                        showPermissionError = true
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560)
        .frame(minHeight: 470)
        .onAppear {
            microphoneStatus = PermissionsCoordinator.shared.microphoneAuthorizationStatus
        }
    }
    
    private var microphoneStatusText: String {
        switch microphoneStatus {
        case .authorized:
            return "Доступ к микрофону уже разрешен"
        case .notDetermined:
            return "Разрешение к микрофону еще не запрошено"
        case .denied:
            return "Доступ отклонен. Откройте настройки macOS"
        case .restricted:
            return "Доступ ограничен политикой системы"
        @unknown default:
            return "Неизвестный статус микрофона"
        }
    }
    
    private var microphoneButtonTitle: String {
        switch microphoneStatus {
        case .authorized:
            return "Проверить статус"
        case .notDetermined:
            return "Запросить доступ к микрофону"
        case .denied, .restricted:
            return "Открыть настройки микрофона"
        @unknown default:
            return "Проверить микрофон"
        }
    }
    
    private var microphoneStatusColor: Color {
        switch microphoneStatus {
        case .authorized:
            return .green
        case .notDetermined:
            return .orange
        case .denied, .restricted:
            return .red
        @unknown default:
            return .secondary
        }
    }
}
