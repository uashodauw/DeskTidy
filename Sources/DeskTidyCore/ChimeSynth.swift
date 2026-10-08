import Foundation

/// 用代码合成清理提示音：两个上行的清脆音（像 iOS 的"完成"提示），不依赖任何音频文件。
/// 不直接用 iOS 的系统音效：那是苹果的版权素材，不能放进自己的应用。
public enum ChimeSynth {
    public static let sampleRate = 44_100
    public static let duration: Double = 0.45
    /// 最大音量（满分 1.0）。比系统"啵"声柔和一点，连续清理也不吵。
    public static let peakLevel: Double = 0.5

    private struct Note {
        let frequency: Double
        let start: Double
        let decay: Double
        let level: Double
    }

    /// C6 → G6：上行五度，听起来是"完成了"的感觉
    private static let notes = [
        Note(frequency: 1046.50, start: 0.00, decay: 16, level: 0.8),
        Note(frequency: 1567.98, start: 0.075, decay: 9, level: 1.0)
    ]

    private static let attack = 0.004
    /// 结尾淡出：声音在最后几毫秒归零，避免播放结束时"咔哒"一声
    private static let fadeOut = 0.03

    /// 合成后的声音样本，取值在 -1...1 之间。
    public static func samples() -> [Double] {
        let count = Int(duration * Double(sampleRate))
        var mixed = [Double](repeating: 0, count: count)
        for note in notes {
            let firstSample = Int(note.start * Double(sampleRate))
            for index in firstSample..<count {
                let t = Double(index - firstSample) / Double(sampleRate)
                let envelope = min(t / attack, 1) * exp(-t * note.decay)
                let phase = 2 * Double.pi * note.frequency * t
                // 少量泛音让声音像钟片一样亮，但不刺耳
                let tone = sin(phase) + 0.22 * sin(2 * phase) + 0.06 * sin(3 * phase)
                mixed[index] += note.level * envelope * tone
            }
        }

        let fadeSamples = Int(fadeOut * Double(sampleRate))
        for offset in 0..<fadeSamples {
            mixed[count - 1 - offset] *= Double(offset) / Double(fadeSamples)
        }

        let loudest = mixed.map(abs).max() ?? 1
        return mixed.map { $0 / loudest * peakLevel }
    }

    /// 标准 WAV 格式（16 位、单声道），可以直接交给系统播放。
    public static func wavData() -> Data {
        let pcm = samples().map { Int16(($0 * Double(Int16.max)).rounded()) }
        let dataSize = pcm.count * MemoryLayout<Int16>.size

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(UInt32(dataSize))
        for sample in pcm {
            data.appendLittleEndian(UInt16(bitPattern: sample))
        }
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
