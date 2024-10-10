//
//  Prediction.swift
//  Photo Classification
//
//

import Foundation

class Prediction: Identifiable {
    
    var classification: String = ""
    var confidencePercentage: String = ""
    
    init(classification: String, confidencePercentage: String) {
        self.classification = classification
        self.confidencePercentage = confidencePercentage
    }
    
}
