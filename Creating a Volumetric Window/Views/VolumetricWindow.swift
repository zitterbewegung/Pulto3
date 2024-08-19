/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A RealityView window that will spawn a volumetric window that contains a 3D Object.
*/

import SwiftUI
import RealityKit

/// A view that loads in a 3D model and sets the dimensions of the volumetric window to the same size as the model.
struct VolumetricWindow: View {
    /// The length of each side of the cubic volumetric window in meters.
    static let size: CGFloat = 1000

    var body: some View {
        // Get the height, width, and depth information
        // of the view with a geometry reader.
        GeometryReader3D { geometry in
            RealityView { content in
                /// The name of the model to load in.
                let fileName: String = "cup_saucer_set"

                /// Attempt to load the entity that uses the file name as a source.
                guard let model = try? await ModelEntity(named: fileName) else {
                    return
                }

                /// The visual bounds of the model.
                let modelBounds = model.visualBounds(relativeTo: nil)

                /// The entity's dimensions in local coordinates.
                let viewBounds = content.convert(
                    geometry.frame(in: .local),
                    from: .local,
                    to: .scene
                )

                /// The scale of the model for the bounds of the volumetric window.
                let scale = (viewBounds.extents / modelBounds.extents).min()

                // Apply the scale to the model to fill the full size of the window.
                model.scale *= SIMD3(repeating: scale)

                // Set the model's position to the bottom of the visual bounding box.
                model.position.y -= model.visualBounds(relativeTo: nil).min.y

                // Adjust the model's position on the y-axis to align with the view bounds.
                model.position.y += viewBounds.min.y

                // Add the model to the `RealityView`.
                content.add(model)
            }
        }
    }
}

#Preview (windowStyle: .volumetric) {
    VolumetricWindow()
}
