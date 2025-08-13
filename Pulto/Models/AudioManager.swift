import AVFoundation
import Foundation

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func playStartupSound() {
        // Create a pleasant startup sound using a simple tone
        let frequency: Float = 800.0
        let duration: TimeInterval = 0.5
        
        playTone(frequency: frequency, duration: duration)
    }
    
    private func playTone(frequency: Float, duration: TimeInterval) {
        guard audioEngine == nil else { return } // Prevent multiple sounds at once
        
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        
        let buffer = generateToneBuffer(frequency: frequency, duration: duration)
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: {
            DispatchQueue.main.async {
                self.cleanupAudioEngine()
            }
        })
        
        do {
            try engine.start()
            player.play()
        } catch {
            print("Failed to start audio engine: \(error)")
            cleanupAudioEngine()
        }
    }
    
    private func generateToneBuffer(frequency: Float, duration: TimeInterval) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let sampleRate = format.sampleRate
        let frameCount = UInt32(duration * sampleRate)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let channelData = buffer.floatChannelData!
        let leftChannel = channelData[0]
        let rightChannel = channelData[1]
        
        // Generate a pleasant startup sound with fade in/out
        for frame in 0..<Int(frameCount) {
            let time = Float(frame) / Float(sampleRate)
            let sample = sin(2.0 * Float.pi * frequency * time)
            
            // Apply fade in/out to avoid clicking
            let fadeDuration = 0.05
            let fadeInFrames = Int(fadeDuration * sampleRate)
            let fadeOutFrames = Int(fadeDuration * sampleRate)
            let totalFrames = Int(frameCount)
            
            var envelope: Float = 1.0
            if frame < fadeInFrames {
                envelope = Float(frame) / Float(fadeInFrames)
            } else if frame > (totalFrames - fadeOutFrames) {
                envelope = Float(totalFrames - frame) / Float(fadeOutFrames)
            }
            
            let finalSample = sample * envelope * 0.3 // 30% volume
            leftChannel[frame] = finalSample
            rightChannel[frame] = finalSample
        }
        
        return buffer
    }
    
    private func cleanupAudioEngine() {
        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil
    }
}