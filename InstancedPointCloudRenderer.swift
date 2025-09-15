import SwiftUI
import MetalKit
import simd

// MARK: - Metal-backed instanced point cloud renderer

struct InstancedPointCloudView: UIViewRepresentable {
    let points: [PointCloudData.PointData]
    var pointSize: Float

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.isPaused = false
        view.enableSetNeedsDisplay = false

        let renderer = InstancedPointCloudRenderer(mtkView: view, points: points, pointSize: pointSize)
        context.coordinator.renderer = renderer
        view.delegate = renderer
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        if let renderer = context.coordinator.renderer {
            renderer.update(points: points, pointSize: pointSize)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var renderer: InstancedPointCloudRenderer?
    }
}

final class InstancedPointCloudRenderer: NSObject, MTKViewDelegate {
    struct InstanceData {
        var worldPos: SIMD3<Float>
        var size: Float
        var color: SIMD4<Float>
    }

    struct Uniforms {
        var viewProj: simd_float4x4
        var cameraRight: SIMD3<Float>
        var cameraUp: SIMD3<Float>
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!              // quad vertices
    private var instanceBuffer: MTLBuffer!            // per-instance data
    private var uniformBuffer: MTLBuffer!

    private weak var view: MTKView?

    private var instanceCount: Int = 0
    private var currentPointSize: Float = 0.005

    // Simple camera
    private var angle: Float = 0

    init?(mtkView: MTKView, points: [PointCloudData.PointData], pointSize: Float) {
        guard let device = mtkView.device ?? MTLCreateSystemDefaultDevice() else { return nil }
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        self.view = mtkView
        super.init()

        buildPipeline()
        buildQuad()
        update(points: points, pointSize: pointSize)
    }

    private func buildPipeline() {
        let library = try! device.makeDefaultLibrary(bundle: .main)
        let vertex = library.makeFunction(name: "pointVertex")!
        let fragment = library.makeFunction(name: "pointFragment")!

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = view?.colorPixelFormat ?? .bgra8Unorm

        pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)

        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)
    }

    private func buildQuad() {
        // Unit quad centered at origin (billboard), two triangles
        let verts: [SIMD2<Float>] = [
            SIMD2(-0.5, -0.5), SIMD2( 0.5, -0.5), SIMD2(-0.5,  0.5),
            SIMD2( 0.5, -0.5), SIMD2( 0.5,  0.5), SIMD2(-0.5,  0.5)
        ]
        vertexBuffer = device.makeBuffer(bytes: verts, length: MemoryLayout<SIMD2<Float>>.stride * verts.count, options: .storageModeShared)
    }

    func update(points: [PointCloudData.PointData], pointSize: Float) {
        currentPointSize = pointSize
        instanceCount = points.count
        let byteLength = max(1, instanceCount) * MemoryLayout<InstanceData>.stride
        instanceBuffer = device.makeBuffer(length: byteLength, options: .storageModeShared)

        let ptr = instanceBuffer.contents().bindMemory(to: InstanceData.self, capacity: instanceCount)

        // Compute bounds for height color
        let minY = points.map { Float($0.y) }.min() ?? 0
        let maxY = points.map { Float($0.y) }.max() ?? 1
        let yRange = max(0.0001, maxY - minY)

        for i in 0..<instanceCount {
            let p = points[i]
            let world = SIMD3(Float(p.x), Float(p.y), Float(p.z))

            // Color: prefer intensity if available, else height
            let color: SIMD4<Float>
            if let intensity = p.intensity {
                let f = Float(intensity)
                color = SIMD4(f, f * 0.8, 1 - f, 1)
            } else {
                let norm = (world.y - minY) / yRange
                color = SIMD4(norm, 0.5, 1 - norm, 1)
            }

            ptr[i] = InstanceData(worldPos: world, size: pointSize, color: color)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable, let descriptor = view.currentRenderPassDescriptor else { return }

        angle += 0.002 // simple rotation so something moves

        // Build a simple view-projection and camera basis (right/up) facing origin
        let aspect = Float(view.drawableSize.width / max(1, view.drawableSize.height))
        let proj = perspective(fovy: 60 * .pi / 180, aspect: aspect, nearZ: 0.01, farZ: 1000)
        let eye = SIMD3<Float>(sin(angle) * 20, 10, cos(angle) * 20)
        let center = SIMD3<Float>(0, 0, 0)
        let up = SIMD3<Float>(0, 1, 0)
        let viewM = lookAt(eye: eye, center: center, up: up)
        let viewProj = proj * viewM

        let right = normalize(SIMD3<Float>(viewM.columns.0.x, viewM.columns.0.y, viewM.columns.0.z))
        let camUp = normalize(SIMD3<Float>(viewM.columns.1.x, viewM.columns.1.y, viewM.columns.1.z))

        // Update uniforms
        let uniformsPtr = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniformsPtr.pointee = Uniforms(viewProj: viewProj, cameraRight: right, cameraUp: camUp)

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)

        // Draw instanced quads (6 vertices per instance)
        let vertexCount = 6
        if instanceCount > 0 {
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount, instanceCount: instanceCount)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Math helpers

func perspective(fovy: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let y = 1 / tan(fovy * 0.5)
    let x = y / aspect
    let z = farZ / (nearZ - farZ)
    let X = SIMD4<Float>( x,  0,  0,  0)
    let Y = SIMD4<Float>( 0,  y,  0,  0)
    let Z = SIMD4<Float>( 0,  0,  z, -1)
    let W = SIMD4<Float>( 0,  0,  z * nearZ,  0)
    return simd_float4x4(columns: (X, Y, Z, W))
}

func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let f = normalize(center - eye)
    let s = normalize(cross(f, up))
    let u = cross(s, f)

    let X = SIMD4<Float>( s.x,  u.x, -f.x, 0)
    let Y = SIMD4<Float>( s.y,  u.y, -f.y, 0)
    let Z = SIMD4<Float>( s.z,  u.z, -f.z, 0)
    let W = SIMD4<Float>(-dot(s, eye), -dot(u, eye), dot(f, eye), 1)

    return simd_float4x4(columns: (X, Y, Z, W))
}
