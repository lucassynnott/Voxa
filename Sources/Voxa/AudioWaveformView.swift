import SwiftUI

/// A view that displays audio samples as a waveform visualization
/// Shows amplitude over time with color coding for level
struct AudioWaveformView: View {
    let samples: [Float]
    let sampleRate: Double
    
    /// Number of bars to display in the waveform
    var barCount: Int = 100
    
    /// Height of the waveform view
    var height: CGFloat = 80
    
    /// Whether to show time labels
    var showTimeLabels: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Waveform visualization
            GeometryReader { geometry in
                let barWidth = geometry.size.width / CGFloat(barCount)
                let samplesPerBar = max(1, samples.count / barCount)
                
                HStack(alignment: .center, spacing: 0) {
                    ForEach(0..<barCount, id: \.self) { barIndex in
                        let startSample = barIndex * samplesPerBar
                        let endSample = min(startSample + samplesPerBar, samples.count)
                        let barSamples = Array(samples[startSample..<endSample])
                        let amplitude = calculatePeakAmplitude(barSamples)
                        let normalizedHeight = CGFloat(amplitude) * (height / 2)
                        
                        // Bar color based on amplitude
                        let barColor = colorForAmplitude(amplitude)
                        
                        Rectangle()
                            .fill(barColor)
                            .frame(width: max(1, barWidth - 1), height: max(2, normalizedHeight * 2))
                    }
                }
                .frame(height: height, alignment: .center)
            }
            .frame(height: height)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
            
            // Time labels
            if showTimeLabels && !samples.isEmpty {
                HStack {
                    Text("0:00")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDuration(Double(samples.count) / sampleRate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    /// Calculate peak amplitude from samples (0.0 to 1.0)
    private func calculatePeakAmplitude(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        
        var peak: Float = 0
        for sample in samples {
            let abs = Swift.abs(sample)
            if abs > peak {
                peak = abs
            }
        }
        return min(1.0, peak)
    }
    
    /// Get color based on amplitude level
    private func colorForAmplitude(_ amplitude: Float) -> Color {
        if amplitude < 0.1 {
            return .gray.opacity(0.6)
        } else if amplitude < 0.3 {
            return .green
        } else if amplitude < 0.6 {
            return .yellow
        } else if amplitude < 0.9 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// Format duration as MM:SS
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Compact waveform view for inline display
struct CompactWaveformView: View {
    let samples: [Float]
    let sampleRate: Double
    
    var body: some View {
        AudioWaveformView(
            samples: samples,
            sampleRate: sampleRate,
            barCount: 50,
            height: 40,
            showTimeLabels: false
        )
    }
}


