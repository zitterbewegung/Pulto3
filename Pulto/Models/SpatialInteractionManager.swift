import Foundation
import RealityKit
import SwiftUI
import Combine
import AVFoundation

// MARK: - Enhanced Spatial Interaction Manager for visionOS

class SpatialInteractionManager: ObservableObject {
    @Published var isEyeTrackingEnabled = false
    @Published var currentGazeTarget: Entity?
    @Published var interactionFeedback: InteractionFeedback?
    
    // visionOS spatial interaction management
    private var eyeTrackingEnabled = false
    
    enum InteractionFeedback {
        case gazeEntered(Entity)
        case gazeExited(Entity)
        case gazeSelected(Entity)
        case spatialTap(Entity, SIMD3<Float>)
    }

    // MARK: - Eye Tracking Setup
    
    func startEyeTracking() {
        eyeTrackingEnabled = true
        isEyeTrackingEnabled = true
        
        // visionOS eye tracking would be handled differently
        // This is a placeholder for future visionOS eye tracking APIs
    }
    
    func stopEyeTracking() {
        eyeTrackingEnabled = false
        isEyeTrackingEnabled = false
        currentGazeTarget = nil
    }
    
    // MARK: - Gaze-based Interaction
    
    func processGazeIntersection(with entities: [Entity]) {
        guard isEyeTrackingEnabled else { return }
        
        let gazeRay = createGazeRay()
        var closestEntity: Entity?
        var minDistance: Float = Float.greatestFiniteMagnitude
        
        for entity in entities {
            if let distance = rayIntersectionDistance(ray: gazeRay, entity: entity) {
                if distance < minDistance {
                    minDistance = distance
                    closestEntity = entity
                }
            }
        }
        
        if currentGazeTarget != closestEntity {
            // Trigger gaze exit on previous target
            if let previousTarget = currentGazeTarget {
                interactionFeedback = InteractionFeedback.gazeExited(previousTarget)
                previousTarget.components[InteractionComponent.self]?.onHover?(previousTarget)
            }
            
            // Trigger gaze enter on new target
            currentGazeTarget = closestEntity
            if let target = currentGazeTarget {
                interactionFeedback = InteractionFeedback.gazeEntered(target)
                target.components[InteractionComponent.self]?.onHover?(target)
            }
        }
    }
    
    private func createGazeRay() -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        // Create ray from gaze position and direction
        // This would be implemented with actual eye tracking data
        return (origin: [0, 0, 0], direction: [0, 0, -1])
    }
    
    private func rayIntersectionDistance(ray: (origin: SIMD3<Float>, direction: SIMD3<Float>), entity: Entity) -> Float? {
        // Simplified ray-entity intersection
        // In a real implementation, this would use RealityKit's collision detection
        let entityPosition = entity.position
        let toEntity = entityPosition - ray.origin
        let distance = length(toEntity)
        
        // Simple distance-based intersection for demo
        return distance < 0.1 ? distance : nil
    }
    
    // MARK: - Spatial Input Handling
    
    func handleSpatialInput(at location: SIMD3<Float>, in entity: Entity) {
        // Handle spatial input for visionOS
        let feedback = InteractionFeedback.spatialTap(entity, location)
        interactionFeedback = feedback
        
        // Trigger spatial audio feedback
        playInteractionSound(for: entity, at: location)
    }
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    
    func setupSpatialAudio() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let playerNode = audioPlayerNode else { return }
        
        engine.attach(playerNode)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func playInteractionSound(for entity: Entity, at location: SIMD3<Float>) {
        guard let engine = audioEngine, let playerNode = audioPlayerNode else { return }
        
        // Create spatial audio effect
        let spatialMixer = AVAudioEnvironmentNode()
        engine.attach(spatialMixer)
        
        // Set 3D position
        let position = AVAudio3DPoint(x: location.x, y: location.y, z: location.z)
        spatialMixer.listenerPosition = position
        spatialMixer.renderingAlgorithm = .HRTF
        
        // Connect audio nodes
        engine.connect(playerNode, to: spatialMixer, format: nil)
        engine.connect(spatialMixer, to: engine.mainMixerNode, format: nil)
        
        // Play interaction sound
        playInteractionFeedbackSound()
    }
    
    private func playInteractionFeedbackSound() {
        // Generate simple beep sound
        guard let engine = audioEngine, let playerNode = audioPlayerNode else { return }
        
        let buffer = generateBeepBuffer()
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        playerNode.play()
    }
    
    private func generateBeepBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount = AVAudioFrameCount(format.sampleRate * 0.1) // 0.1 second beep
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        // Generate simple sine wave
        let sampleRate = Float(format.sampleRate)
        let frequency: Float = 800.0
        
        for frame in 0..<Int(frameCount) {
            let value = sin(2.0 * Float.pi * frequency * Float(frame) / sampleRate)
            buffer.floatChannelData![0][frame] = value * 0.3 // 30% volume
        }
        
        return buffer
    }
}

// MARK: - Spatial Audio Manager

class SpatialAudioManager: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var audioFiles: [UUID: AVAudioFile] = [:]
    
    init() {
        audioEngine = AVAudioEngine()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Failed to setup audio engine: \(error)")
        }
    }
    
    // MARK: - Startup Sound
    func playStartupSound() {
        playSpatialTone(frequency: 800, position: [0, 0, 0], duration: 0.3)
    }
    
    // MARK: - Spatial Audio for Data Points
    
    func playDataPointSound(for entity: Entity, dataValue: Double) {
        guard entity.components[DataPointComponent.self] != nil else { return }
        
        let frequency = mapDataValueToFrequency(dataValue)
        let position = entity.position
        
        playSpatialTone(frequency: frequency, position: position, duration: 0.5)
    }
    
    private func mapDataValueToFrequency(_ value: Double) -> Float {
        // Map data value to audible frequency range (200-2000 Hz)
        let normalizedValue = Float(max(0, min(1, value)))
        return 200 + (normalizedValue * 1800)
    }
    
    private func playSpatialTone(frequency: Float, position: SIMD3<Float>, duration: TimeInterval) {
        let playerNode = AVAudioPlayerNode()
        let audioBuffer = generateToneBuffer(frequency: frequency, duration: duration)
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioBuffer.format)
        
        // Set 3D position
        playerNode.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
        playerNode.renderingAlgorithm = .HRTF
        
        playerNode.scheduleBuffer(audioBuffer, completionHandler: {
            DispatchQueue.main.async {
                self.audioEngine.detach(playerNode)
            }
        })
        
        playerNode.play()
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
        
        for frame in 0..<Int(frameCount) {
            let time = Float(frame) / Float(sampleRate)
            let sample = sin(2.0 * Float.pi * frequency * time) * 0.3 // 30% volume
            leftChannel[frame] = sample
            rightChannel[frame] = sample
        }
        
        return buffer
    }
    
    // MARK: - Multi-modal Feedback
    
    func provideDataFeedback(for entity: Entity) {
        guard let dataComponent = entity.components[DataPointComponent.self] else { return }
        
        // Spatial audio feedback
        playDataPointSound(for: entity, dataValue: dataComponent.value)
        
        // Haptic feedback (would need additional implementation)
        // triggerHapticFeedback(intensity: Float(dataComponent.value))
    }
}