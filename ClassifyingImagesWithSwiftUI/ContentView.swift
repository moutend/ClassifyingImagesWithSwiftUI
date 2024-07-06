import SwiftUI
import UIKit

struct ContentView: View {
  @State private var isShowingCamera = false
  @State private var image: UIImage?
  @State private var label = ""

  var body: some View {
    VStack {
      if let image = self.image {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
        Text(self.label)
          .font(.body)
          .padding()
      } else {
        Text("No Image")
          .font(.title)
          .padding()
      }
      Button(action: {
        self.isShowingCamera = true
      }) {
        Text("Take Photo")
          .padding()
          .foregroundColor(Color.white)
          .background(Color.indigo)
      }
      .sheet(isPresented: self.$isShowingCamera) {
        CameraView(isShowing: self.$isShowingCamera, image: self.$image, label: self.$label)
      }
    }
  }
}

struct CameraView: UIViewControllerRepresentable {
  @Binding var isShowing: Bool
  @Binding var image: UIImage?
  @Binding var label: String

  class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var parent: CameraView

    let imagePredictor = ImagePredictor()
    let predictionsToShow = 3

    init(parent: CameraView) {
      self.parent = parent
    }
    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      guard let originalImage = info[UIImagePickerController.InfoKey.originalImage] else {
        fatalError("Picker didn't have an original image.")
      }
      guard let photo = originalImage as? UIImage else {
        fatalError("The image is not able to retrieve as a UIImage.")
      }

      userSelectedPhoto(photo)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      self.parent.isShowing = false
    }
    private func userSelectedPhoto(_ photo: UIImage) {
      self.parent.label = "Making predictions for the photo..."
      self.parent.image = photo
      self.parent.isShowing = false

      DispatchQueue.global(qos: .userInitiated).async {
        self.classifyImage(photo)
      }
    }
    private func classifyImage(_ image: UIImage) {
      do {
        try self.imagePredictor.makePredictions(
          for: image,
          completionHandler: self.imagePredictionHandler)
      } catch {
        fatalError("Unable to make a prediction.")
      }
    }
    private func imagePredictionHandler(_ predictions: [ImagePredictor.Prediction]?) {
      guard let predictions = predictions else {
        self.parent.label = "No predictions."
        return
      }

      let formattedPredictions = formatPredictions(predictions)
      let predictionString = formattedPredictions.joined(separator: "\n")

      self.parent.label = predictionString
    }
    private func formatPredictions(_ predictions: [ImagePredictor.Prediction]) -> [String] {
      let topPredictions: [String] = predictions.prefix(predictionsToShow).map { prediction in
        var name = prediction.classification
        if let firstComma = name.firstIndex(of: ",") {
          name = String(name.prefix(upTo: firstComma))
        }
        return "\(name) - \(prediction.confidencePercentage)%"
      }
      return topPredictions
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()

    picker.delegate = context.coordinator
    picker.sourceType = .camera

    return picker
  }
  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    // Do nothing
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
