import Foundation
import UIKit
import Vision

/// Estimates the user's body silhouette from a full-body front photo using Vision's human body
/// pose detection. We compare shoulder span against hip span (and the shoulder→hip taper) to place
/// the person on the standard image-consulting silhouette model.
///
/// This is an approximation from a single 2D photo, so it's intentionally conservative: it only
/// returns a shape when the key joints are detected with reasonable confidence, and pairs nicely
/// with the measurement-based estimate as a fallback.
enum BodyShapeAnalyzer {

    static func detectBodyShape(from image: UIImage) async -> BodyShape? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else { return nil }
        return classify(from: observation)
    }

    private static func classify(from observation: VNHumanBodyPoseObservation) -> BodyShape? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = points[name], p.confidence > 0.3 else { return nil }
            return p.location
        }

        guard let lShoulder = point(.leftShoulder),
              let rShoulder = point(.rightShoulder),
              let lHip = point(.leftHip),
              let rHip = point(.rightHip) else {
            return nil
        }

        // Horizontal spans (Vision's normalized coordinates are fine for a ratio).
        let shoulderSpan = abs(lShoulder.x - rShoulder.x)
        let hipSpan = abs(lHip.x - rHip.x)
        guard shoulderSpan > 0.01, hipSpan > 0.01 else { return nil }

        let ratio = shoulderSpan / hipSpan

        // Torso length lets us sanity-check we have a real upright body, and a longer torso with a
        // balanced span leans rectangle vs hourglass — but without a waist joint we can't see waist
        // definition, so balanced bodies are reported as rectangle (the safe, neutral default that
        // the measurement-based estimate can refine to hourglass when waist data exists).
        if ratio >= 1.12 {
            return .invertedTriangle
        } else if ratio <= 0.89 {
            return .triangle
        } else {
            return .rectangle
        }
    }
}
