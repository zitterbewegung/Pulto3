import AVFoundation
import Foundation

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            // Changed from .playback to .ambient to allow mixing with other audio
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func playStartupSound() {
        // Try to play a sound file first, fallback to generated tone
        if !playSoundFile(named: "startup_sound", type: "mp3") {
            // Fallback to generated tone if sound file not found
            playTone(frequency: 800.0, duration: 0.5)
        }
    }
    
    /// Plays a sound file from the app bundle
    /// - Parameters:
    ///   - name: The name of the sound file (without extension)
    ///   - type: The file extension (e.g., "mp3", "wav", "m4a", "aiff", "aac")
    /// - Returns: true if the file was found and playback started, false otherwise
    func playSoundFile(named name: String, type: String) -> Bool {
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else {
            print("Audio file not found: \(name).\(type)")
            return false
        }
        
        do {
            // Clean up any existing audio engine
            cleanupAudioEngine()
            
            // Create new audio engine and player node
            audioEngine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            
            guard let engine = audioEngine, let player = playerNode else { return false }
            
            // Load audio file
            audioFile = try AVAudioFile(forReading: url)
            
            // Attach nodes and connect them
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: audioFile?.processingFormat)
            
            // Schedule the file for playback
            player.scheduleFile(audioFile!, at: nil, completionHandler: {
                DispatchQueue.main.async {
                    self.cleanupAudioEngine()
                }
            })
            
            // Start the engine and play
            try engine.start()
            player.play()
            
            print("Successfully playing startup sound: \(name).\(type)")
            return true
        } catch {
            print("Failed to play audio file: \(error)")
            cleanupAudioEngine()
            return false
        }
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
            print("Playing fallback tone")
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
            let fadeDuration = 0.15
            let fadeInFrames = Int(fadeDuration * sampleRate)
            let fadeOutFrames = Int(fadeDuration * sampleRate)
            let totalFrames = Int(frameCount)
            
            var envelope: Float = 1.0
            if frame < fadeInFrames {
                envelope = Float(frame) / Float(fadeInFrames)
            } else if frame > (totalFrames - fadeOutFrames) {
                envelope = Float(totalFrames - frame) / Float(fadeOutFrames)
            }
            
            let finalSample = sample * envelope * 0.1 // 10% volume
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
        audioFile = nil
    }
}
