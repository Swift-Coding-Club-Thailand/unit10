//
//  ContentView.swift
//  Photo Classification
//
//

import SwiftUI
import PhotosUI
import CoreML
import Vision

struct ContentView: View {
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showResetImageAlert = false
    
    @State var predictions: [Prediction] = []
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height / 2)
                        .clipped()
                    
                    List(predictions) { prediction in
                        HStack {
                            Text(prediction.classification)
                            Spacer()
                            Text(prediction.confidencePercentage)
                                .foregroundStyle(.gray)
                        }
                        .listRowBackground(Color(#colorLiteral(red: 0.9066124558, green: 0.9066124558, blue: 0.9066124558, alpha: 1)))
                    }
                    .scrollContentBackground(.hidden)
                    
                    Button("Reset Picture") {
                        showResetImageAlert = true
                    }
                    .buttonStyle(.bordered)
                    .alert("Reset Picture", isPresented: $showResetImageAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Reset", role: .destructive) {
                            selectedItem = nil
                            selectedImage = nil
                            predictions = []
                        }
                    } message: {
                        Text("This action will clear the selected picture and its predictions.")
                    }
                    
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ContentUnavailableView("No Picture", systemImage: "photo.badge.plus", description: Text("Tap to select a picture from your Photo Library"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        processImageClassification(uiImage)
                    }
                }
            }
            .onAppear(perform: {
                requestPhotoLibraryAccess()
            })
        }
    }
    
    private func requestPhotoLibraryAccess() {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    print("Access granted.")
                } else {
                    print("Access denied.")
                }
            }
        case .restricted, .denied:
            print("Access denied or restricted.")
        case .authorized:
            print("Access already granted.")
        case .limited:
            print("Access limited.")
        @unknown default:
            print("Unknown authorization status.")
        }
    }
    
    private func processImageClassification(_ image: UIImage) {
        
        // Use a default model configuration.
        let defaultConfig = MLModelConfiguration()
        
        // Create an instance of the image classifier's wrapper class.
        let imageClassifierWrapper = try? MobileNetV2(configuration: defaultConfig)
        
        guard let imageClassifier = imageClassifierWrapper else {
            fatalError("App failed to create an image classifier model instance.")
        }
        
        // Get the underlying model instance.
        let imageClassifierModel = imageClassifier.model
        
        // Create a Vision instance using the image classifier's model instance.
        guard let model = try? VNCoreMLModel(for: imageClassifierModel) else {
            fatalError("App failed to create a `VNCoreMLModel` instance.")
        }
        
        let imageClassificationRequest = VNCoreMLRequest(model: model) { (request, error) in
            guard let results = request.results as? [VNClassificationObservation] else {
                print("Failed to classify image")
                return
            }
            
            results.forEach { result in
                if result.confidence > 0.01 {
                    let condidence = String(format: "%.2f", result.confidence*100)
                    let prediction = Prediction(classification: result.identifier,
                                                confidencePercentage: "\(condidence)%")
                    predictions.append(prediction)
                }
            }
        }
        
        guard let cgImage = image.cgImage else {
            print("Failed to get cgImage data")
            return
        }
        
        let requests: [VNRequest] = [imageClassificationRequest]
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        try? handler.perform(requests)
    }
}

#Preview {
    ContentView()
}
