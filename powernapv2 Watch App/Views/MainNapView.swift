import SwiftUI

struct MainNapView: View {
    @EnvironmentObject var viewModel: PowerNapViewModel

    var body: some View {
        VStack {
            // Content changes based on state
            switch viewModel.napState {
            case .idle:
                ReadyView()
            case .detecting:
                MonitoringView()
            case .napping:
                CountdownView()
            case .paused:
                Text("已暫停")
                // TODO: Add Resume/Stop buttons
            case .finished:
                Text("小睡完成！")
                // TODO: Add summary or back button
            case .error(let message):
                 Text("發生錯誤: \(message)")
                 // TODO: Add a way to dismiss or retry?
            }
        }
        .environmentObject(viewModel)
    }
}

// MARK: - Subviews for Different States

struct ReadyView: View {
    @EnvironmentObject var viewModel: PowerNapViewModel
    @State private var displayedDuration: Int = 15 // Local state for picker initially

    var body: some View {
        VStack(spacing: 15) {
            Spacer()
            Text("設定時長: \(viewModel.selectedNapDuration) 分鐘")
                .font(.title2)
            
            Button("開始休息") {
                viewModel.startNap(duration: TimeInterval(viewModel.selectedNapDuration * 60))
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
         .onAppear {
             displayedDuration = viewModel.selectedNapDuration
         }
    }
}

struct MonitoringView: View {
    @EnvironmentObject var viewModel: PowerNapViewModel
    @State private var breathingOpacity: Double = 0.1

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(breathingOpacity))
                .scaleEffect(1.5)
                .animation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: breathingOpacity)
                .onAppear { breathingOpacity = 0.4 }

            VStack(spacing: 20) {
                Text("監測中")
                    .font(.headline)
                Text("等待入睡...")
                    .font(.body)
                    .foregroundColor(.gray)

                Button("取消") {
                    viewModel.stopNap()
                }
                .tint(.red)
            }
        }
    }
}

struct CountdownView: View {
    @EnvironmentObject var viewModel: PowerNapViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(viewModel.timeRemainingFormatted)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 15) {
                Button("取消") {
                    viewModel.stopNap()
                }
                .tint(.red)

                Button("完成/醒來") {
                    viewModel.completeNapEarly()
                }
                .tint(.green)
            }
            Spacer()
        }
    }
}

// Add Previews if desired 