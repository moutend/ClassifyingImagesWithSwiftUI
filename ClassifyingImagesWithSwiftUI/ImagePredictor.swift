import ImageIO
import UIKit
import Vision

extension VNClassificationObservation {
  var confidencePercentageString: String {
    let percentage = confidence * 100

    switch percentage {
    case 100.0...:
      return "100%"
    case 10.0..<100.0:
      return String(format: "%2.1f", percentage)
    case 1.0..<10.0:
      return String(format: "%2.1f", percentage)
    case ..<1.0:
      return String(format: "%1.2f", percentage)
    default:
      return String(format: "%2.1f", percentage)
    }
  }
}

extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}

class ImagePredictor {
  static func createImageClassifier() -> VNCoreMLModel {
    let defaultConfig = MLModelConfiguration()
    let imageClassifierWrapper = try? MobileNetV2FP16(configuration: defaultConfig)

    guard let imageClassifier = imageClassifierWrapper else {
      fatalError("App failed to create an image classifier model instance.")
    }

    let imageClassifierModel = imageClassifier.model

    guard let imageClassifierVisionModel = try? VNCoreMLModel(for: imageClassifierModel) else {
      fatalError("App failed to create a `VNCoreMLModel` instance.")
    }

    return imageClassifierVisionModel
  }

  private static let imageClassifier = createImageClassifier()

  struct Prediction {
    let classification: String
    let confidencePercentage: String
  }

  typealias ImagePredictionHandler = (_ predictions: [Prediction]?) -> Void

  private var predictionHandlers = [VNRequest: ImagePredictionHandler]()

  private func createImageClassificationRequest() -> VNImageBasedRequest {
    let imageClassificationRequest = VNCoreMLRequest(
      model: ImagePredictor.imageClassifier,
      completionHandler: self.visionRequestHandler)
    imageClassificationRequest.imageCropAndScaleOption = .centerCrop
    return imageClassificationRequest
  }
  private func visionRequestHandler(_ request: VNRequest, error: Error?) {
    guard let predictionHandler = self.predictionHandlers.removeValue(forKey: request) else {
      fatalError("Every request must have a prediction handler.")
    }
    var predictions: [Prediction]? = nil
    defer {
      predictionHandler(predictions)
    }
    if let error = error {
      print("Vision image classification error...\n\n\(error.localizedDescription)")
      return
    }
    if request.results == nil {
      print("Vision request had no results.")
      return
    }
    guard let observations = request.results as? [VNClassificationObservation] else {
      print("VNRequest produced the wrong result type: \(type(of: request.results)).")
      return
    }
    predictions = observations.map { observation in
      Prediction(
        classification: observation.identifier,
        confidencePercentage: observation.confidencePercentageString)
    }
  }
  func makePredictions(for photo: UIImage, completionHandler: @escaping ImagePredictionHandler)
    throws
  {
    let orientation = CGImagePropertyOrientation(photo.imageOrientation)
    guard let photoImage = photo.cgImage else {
      fatalError("Photo doesn't have underlying CGImage.")
    }
    let imageClassificationRequest = self.createImageClassificationRequest()
    self.predictionHandlers[imageClassificationRequest] = completionHandler
    let handler = VNImageRequestHandler(cgImage: photoImage, orientation: orientation)
    let requests: [VNRequest] = [imageClassificationRequest]
    try handler.perform(requests)
  }
}
