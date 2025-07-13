//
//  SCNVector3+Transform.swift
//  Pulto3
//
//  Created by Assistant on 1/29/25.
//

import SceneKit

extension SCNVector3 {
    func transformed(by matrix: SCNMatrix4) -> SCNVector3 {
        let x = self.x * matrix.m11 + self.y * matrix.m21 + self.z * matrix.m31 + matrix.m41
        let y = self.x * matrix.m12 + self.y * matrix.m22 + self.z * matrix.m32 + matrix.m42
        let z = self.x * matrix.m13 + self.y * matrix.m23 + self.z * matrix.m33 + matrix.m43
        
        return SCNVector3(x, y, z)
    }
}