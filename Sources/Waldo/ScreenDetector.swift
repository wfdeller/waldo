import CoreGraphics
import Foundation
import Vision
import CoreImage
import Accelerate

class ScreenDetector {
    
    // MARK: - Public Interface
    
    static func detectAndCorrectScreen(from image: CGImage, verbose: Bool = false) -> CGImage? {
        if verbose { print("Starting screen detection and perspective correction...") }
        
        // First try rectangle detection using Vision framework
        if let correctedImage = detectScreenWithVision(image: image, verbose: verbose) {
            if verbose { print("Screen detected and corrected using Vision framework") }
            return correctedImage
        }
        
        if verbose { print("Vision detection failed, trying Canny edge detection...") }
        
        // Fallback to custom edge detection
        if let correctedImage = detectScreenWithEdgeDetection(image: image, verbose: verbose) {
            if verbose { print("Screen detected and corrected using edge detection") }
            return correctedImage
        }
        
        if verbose { print("Edge detection failed, trying Hough line detection...") }
        
        // Final fallback to Hough line detection
        if let correctedImage = detectScreenWithHoughLines(image: image, verbose: verbose) {
            if verbose { print("Screen detected and corrected using Hough lines") }
            return correctedImage
        }
        
        if verbose { print("All screen detection methods failed") }
        return nil
    }
    
    // MARK: - Vision Framework Rectangle Detection
    
    private static func detectScreenWithVision(image: CGImage, verbose: Bool) -> CGImage? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 10
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 3.0
        request.minimumSize = 0.1
        request.minimumConfidence = 0.5
        
        let handler = VNImageRequestHandler(cgImage: image)
        
        do {
            try handler.perform([request])
            
            guard let results = request.results, !results.isEmpty else {
                if verbose { print("No rectangles detected by Vision framework") }
                return nil
            }
            
            if verbose { print("Vision detected \(results.count) rectangles") }
            
            // Find the best rectangle (largest, most screen-like)
            let bestRectangle = findBestScreenRectangle(results, imageSize: CGSize(width: image.width, height: image.height), verbose: verbose)
            
            guard let rectangle = bestRectangle else {
                if verbose { print("No suitable screen rectangle found") }
                return nil
            }
            
            // Apply perspective correction
            return applyPerspectiveCorrection(to: image, rectangle: rectangle, verbose: verbose)
            
        } catch {
            if verbose { print("Vision rectangle detection failed: \(error)") }
            return nil
        }
    }
    
    private static func findBestScreenRectangle(_ rectangles: [VNRectangleObservation], imageSize: CGSize, verbose: Bool) -> VNRectangleObservation? {
        var bestRectangle: VNRectangleObservation?
        var bestScore: Float = 0
        
        for (index, rectangle) in rectangles.enumerated() {
            let corners = [
                CGPoint(x: rectangle.topLeft.x * imageSize.width, y: (1 - rectangle.topLeft.y) * imageSize.height),
                CGPoint(x: rectangle.topRight.x * imageSize.width, y: (1 - rectangle.topRight.y) * imageSize.height),
                CGPoint(x: rectangle.bottomRight.x * imageSize.width, y: (1 - rectangle.bottomRight.y) * imageSize.height),
                CGPoint(x: rectangle.bottomLeft.x * imageSize.width, y: (1 - rectangle.bottomLeft.y) * imageSize.height)
            ]
            
            let area = calculatePolygonArea(corners)
            let aspectRatio = calculateAspectRatio(corners)
            let rectangularity = calculateRectangularity(corners)
            
            // Score based on area, aspect ratio, and rectangularity
            let areaScore = Float(area / (imageSize.width * imageSize.height))
            let aspectScore = Float(getAspectRatioScore(aspectRatio))
            let rectangularityScore = rectangularity
            
            let areaWeight: Float = 0.4
            let aspectWeight: Float = 0.3
            let rectangularityWeight: Float = 0.3
            let totalScore = areaScore * areaWeight + aspectScore * aspectWeight + rectangularityScore * rectangularityWeight
            
            if verbose {
                print("Rectangle \(index): area=\(String(format: "%.3f", areaScore)), aspect=\(String(format: "%.2f", aspectRatio)) (score=\(String(format: "%.3f", aspectScore))), rect=\(String(format: "%.3f", rectangularityScore)), total=\(String(format: "%.3f", totalScore))")
            }
            
            if totalScore > bestScore {
                bestScore = totalScore
                bestRectangle = rectangle
            }
        }
        
        if verbose && bestRectangle != nil {
            print("Best rectangle score: \(String(format: "%.3f", bestScore))")
        }
        
        return bestScore > 0.2 ? bestRectangle : nil
    }
    
    // MARK: - Canny Edge Detection
    
    private static func detectScreenWithEdgeDetection(image: CGImage, verbose: Bool) -> CGImage? {
        // Convert to grayscale
        guard let grayImage = convertToGrayscale(image) else {
            if verbose { print("Failed to convert image to grayscale") }
            return nil
        }
        
        // Extract pixel data
        guard let pixelData = extractPixelData(from: grayImage) else {
            if verbose { print("Failed to extract pixel data") }
            return nil
        }
        
        let width = grayImage.width
        let height = grayImage.height
        
        // Apply Gaussian blur to reduce noise
        let blurredData = applyGaussianBlur(pixelData, width: width, height: height, verbose: verbose)
        
        // Calculate gradients using Sobel operators
        let (gradientMagnitude, gradientDirection) = calculateGradients(blurredData, width: width, height: height, verbose: verbose)
        
        // Apply non-maximum suppression
        let suppressedEdges = applyNonMaximumSuppression(gradientMagnitude, gradientDirection, width: width, height: height, verbose: verbose)
        
        // Apply double threshold and edge tracking
        let edges = applyDoubleThreshold(suppressedEdges, width: width, height: height, verbose: verbose)
        
        // Find contours and detect rectangular shapes
        let rectangles = findRectangularContours(edges, width: width, height: height, verbose: verbose)
        
        guard !rectangles.isEmpty else {
            if verbose { print("No rectangular contours found") }
            return nil
        }
        
        // Find the best screen rectangle
        let bestRectangle = findBestScreenContour(rectangles, imageSize: CGSize(width: width, height: height), verbose: verbose)
        
        guard let screenCorners = bestRectangle else {
            if verbose { print("No suitable screen contour found") }
            return nil
        }
        
        // Apply perspective correction
        return applyPerspectiveCorrection(to: image, corners: screenCorners, verbose: verbose)
    }
    
    // MARK: - Hough Line Detection
    
    private static func detectScreenWithHoughLines(image: CGImage, verbose: Bool) -> CGImage? {
        // Convert to grayscale and detect edges first
        guard let grayImage = convertToGrayscale(image),
              let pixelData = extractPixelData(from: grayImage) else {
            if verbose { print("Failed to prepare image for Hough detection") }
            return nil
        }
        
        let width = grayImage.width
        let height = grayImage.height
        
        // Simple edge detection (gradient-based)
        let edges = detectEdgesSimple(pixelData, width: width, height: height, verbose: verbose)
        
        // Detect lines using Hough transform
        let lines = detectLines(edges, width: width, height: height, verbose: verbose)
        
        guard lines.count >= 4 else {
            if verbose { print("Insufficient lines detected for screen rectangle: \(lines.count)") }
            return nil
        }
        
        // Find screen rectangle from detected lines
        let screenCorners = findScreenRectangleFromLines(lines, imageSize: CGSize(width: width, height: height), verbose: verbose)
        
        guard let corners = screenCorners else {
            if verbose { print("Could not form screen rectangle from detected lines") }
            return nil
        }
        
        // Apply perspective correction
        return applyPerspectiveCorrection(to: image, corners: corners, verbose: verbose)
    }
    
    // MARK: - Perspective Correction
    
    private static func applyPerspectiveCorrection(to image: CGImage, rectangle: VNRectangleObservation, verbose: Bool) -> CGImage? {
        let imageSize = CGSize(width: image.width, height: image.height)
        
        // Convert normalized coordinates to pixel coordinates
        let corners = [
            CGPoint(x: rectangle.topLeft.x * imageSize.width, y: (1 - rectangle.topLeft.y) * imageSize.height),
            CGPoint(x: rectangle.topRight.x * imageSize.width, y: (1 - rectangle.topRight.y) * imageSize.height),
            CGPoint(x: rectangle.bottomRight.x * imageSize.width, y: (1 - rectangle.bottomRight.y) * imageSize.height),
            CGPoint(x: rectangle.bottomLeft.x * imageSize.width, y: (1 - rectangle.bottomLeft.y) * imageSize.height)
        ]
        
        return applyPerspectiveCorrection(to: image, corners: corners, verbose: verbose)
    }
    
    private static func applyPerspectiveCorrection(to image: CGImage, corners: [CGPoint], verbose: Bool) -> CGImage? {
        guard corners.count == 4 else {
            if verbose { print("Invalid number of corners for perspective correction: \(corners.count)") }
            return nil
        }
        
        if verbose { print("Applying perspective correction with corners: \(corners)") }
        
        // Calculate output dimensions based on corner distances
        let width1 = distance(corners[0], corners[1])
        let width2 = distance(corners[2], corners[3])
        let height1 = distance(corners[0], corners[3])
        let height2 = distance(corners[1], corners[2])
        
        let outputWidth = Int(max(width1, width2))
        let outputHeight = Int(max(height1, height2))
        
        if verbose { print("Output dimensions: \(outputWidth)x\(outputHeight)") }
        
        // Set up perspective transform
        let sourceQuad = corners
        
        // Apply perspective transformation using Core Image
        let ciImage = CIImage(cgImage: image)
        let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection")!
        
        perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(CGPoint: sourceQuad[0]), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(CGPoint: sourceQuad[1]), forKey: "inputTopRight")  
        perspectiveFilter.setValue(CIVector(CGPoint: sourceQuad[2]), forKey: "inputBottomRight")
        perspectiveFilter.setValue(CIVector(CGPoint: sourceQuad[3]), forKey: "inputBottomLeft")
        
        guard let outputCIImage = perspectiveFilter.outputImage else {
            if verbose { print("Perspective correction filter failed") }
            return nil
        }
        
        let ciContext = CIContext()
        guard let correctedImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            if verbose { print("Failed to create corrected CGImage") }
            return nil
        }
        
        if verbose { print("Perspective correction completed successfully") }
        return correctedImage
    }
    
    // MARK: - Helper Functions
    
    private static func extractPixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let ctx = context else { return nil }
        
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pixelData
    }
    
    private static func convertToGrayscale(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let ctx = context else { return nil }
        
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return ctx.makeImage()
    }
    
    private static func applyGaussianBlur(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        if verbose { print("Applying Gaussian blur...") }
        
        var blurredData = data
        let kernel: [Float] = [1, 2, 1, 2, 4, 2, 1, 2, 1]
        let kernelSum: Float = 16
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = (y * width + x) * 4
                if index + 3 < data.count {
                    var sum: Float = 0
                    var kernelIndex = 0
                    
                    for ky in -1...1 {
                        for kx in -1...1 {
                            let sampleIndex = ((y + ky) * width + (x + kx)) * 4
                            if sampleIndex + 3 < data.count {
                                sum += Float(data[sampleIndex]) * kernel[kernelIndex]
                            }
                            kernelIndex += 1
                        }
                    }
                    
                    blurredData[index] = UInt8(sum / kernelSum)
                    blurredData[index + 1] = blurredData[index]
                    blurredData[index + 2] = blurredData[index]
                }
            }
        }
        
        return blurredData
    }
    
    private static func calculateGradients(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> ([Float], [Float]) {
        if verbose { print("Calculating gradients...") }
        
        var gradientMagnitude = [Float](repeating: 0, count: width * height)
        var gradientDirection = [Float](repeating: 0, count: width * height)
        
        let sobelX: [Float] = [-1, 0, 1, -2, 0, 2, -1, 0, 1]
        let sobelY: [Float] = [-1, -2, -1, 0, 0, 0, 1, 2, 1]
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                
                var gx: Float = 0
                var gy: Float = 0
                var kernelIndex = 0
                
                for ky in -1...1 {
                    for kx in -1...1 {
                        let sampleIndex = ((y + ky) * width + (x + kx)) * 4
                        if sampleIndex < data.count {
                            let pixelValue = Float(data[sampleIndex])
                            gx += pixelValue * sobelX[kernelIndex]
                            gy += pixelValue * sobelY[kernelIndex]
                        }
                        kernelIndex += 1
                    }
                }
                
                gradientMagnitude[index] = sqrt(gx * gx + gy * gy)
                gradientDirection[index] = atan2(gy, gx)
            }
        }
        
        return (gradientMagnitude, gradientDirection)
    }
    
    private static func applyNonMaximumSuppression(_ magnitude: [Float], _ direction: [Float], width: Int, height: Int, verbose: Bool) -> [Float] {
        if verbose { print("Applying non-maximum suppression...") }
        
        var suppressed = [Float](repeating: 0, count: width * height)
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                let angle = direction[index] * 180 / Float.pi
                let normalizedAngle = angle < 0 ? angle + 180 : angle
                
                var neighbor1Index = index
                var neighbor2Index = index
                
                // Determine neighbors based on gradient direction
                if (normalizedAngle >= 0 && normalizedAngle < 22.5) || (normalizedAngle >= 157.5 && normalizedAngle <= 180) {
                    neighbor1Index = index - 1
                    neighbor2Index = index + 1
                } else if normalizedAngle >= 22.5 && normalizedAngle < 67.5 {
                    neighbor1Index = (y - 1) * width + (x + 1)
                    neighbor2Index = (y + 1) * width + (x - 1)
                } else if normalizedAngle >= 67.5 && normalizedAngle < 112.5 {
                    neighbor1Index = (y - 1) * width + x
                    neighbor2Index = (y + 1) * width + x
                } else if normalizedAngle >= 112.5 && normalizedAngle < 157.5 {
                    neighbor1Index = (y - 1) * width + (x - 1)
                    neighbor2Index = (y + 1) * width + (x + 1)
                }
                
                if magnitude[index] >= magnitude[neighbor1Index] && magnitude[index] >= magnitude[neighbor2Index] {
                    suppressed[index] = magnitude[index]
                }
            }
        }
        
        return suppressed
    }
    
    private static func applyDoubleThreshold(_ edges: [Float], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        if verbose { print("Applying double threshold...") }
        
        var result = [UInt8](repeating: 0, count: width * height)
        let maxVal = edges.max() ?? 0
        let lowThreshold = maxVal * 0.1
        let highThreshold = maxVal * 0.3
        
        // Apply thresholds
        for i in 0..<edges.count {
            if edges[i] >= highThreshold {
                result[i] = 255
            } else if edges[i] >= lowThreshold {
                result[i] = 128
            }
        }
        
        // Edge tracking (connect weak edges to strong edges)
        var changed = true
        while changed {
            changed = false
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let index = y * width + x
                    if result[index] == 128 {
                        // Check if connected to strong edge
                        var hasStrongNeighbor = false
                        for dy in -1...1 {
                            for dx in -1...1 {
                                let neighborIndex = (y + dy) * width + (x + dx)
                                if neighborIndex >= 0 && neighborIndex < result.count && result[neighborIndex] == 255 {
                                    hasStrongNeighbor = true
                                    break
                                }
                            }
                            if hasStrongNeighbor { break }
                        }
                        
                        if hasStrongNeighbor {
                            result[index] = 255
                            changed = true
                        }
                    }
                }
            }
        }
        
        // Convert weak edges to background
        for i in 0..<result.count {
            if result[i] == 128 {
                result[i] = 0
            }
        }
        
        return result
    }
    
    private static func findRectangularContours(_ edges: [UInt8], width: Int, height: Int, verbose: Bool) -> [[CGPoint]] {
        if verbose { print("Finding rectangular contours...") }
        
        var contours: [[CGPoint]] = []
        var visited = [Bool](repeating: false, count: width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                if !visited[index] && edges[index] == 255 {
                    let contour = traceContour(edges, width: width, height: height, startX: x, startY: y, visited: &visited)
                    if contour.count >= 4 {
                        let simplified = simplifyContour(contour, epsilon: 3.0)
                        if simplified.count == 4 {
                            contours.append(simplified)
                        }
                    }
                }
            }
        }
        
        if verbose { print("Found \(contours.count) rectangular contours") }
        return contours
    }
    
    private static func traceContour(_ edges: [UInt8], width: Int, height: Int, startX: Int, startY: Int, visited: inout [Bool]) -> [CGPoint] {
        var contour: [CGPoint] = []
        var stack: [(Int, Int)] = [(startX, startY)]
        
        while !stack.isEmpty {
            let (x, y) = stack.removeLast()
            let index = y * width + x
            
            if x >= 0 && x < width && y >= 0 && y < height && !visited[index] && edges[index] == 255 {
                visited[index] = true
                contour.append(CGPoint(x: x, y: y))
                
                // Add neighbors
                for dy in -1...1 {
                    for dx in -1...1 {
                        if dx != 0 || dy != 0 {
                            stack.append((x + dx, y + dy))
                        }
                    }
                }
            }
        }
        
        return contour
    }
    
    private static func simplifyContour(_ contour: [CGPoint], epsilon: Double) -> [CGPoint] {
        guard contour.count > 2 else { return contour }
        
        // Douglas-Peucker algorithm for contour simplification
        func douglasPeucker(_ points: [CGPoint], epsilon: Double) -> [CGPoint] {
            guard points.count > 2 else { return points }
            
            var maxDistance: Double = 0
            var maxIndex = 0
            let end = points.count - 1
            
            for i in 1..<end {
                let distance = perpendicularDistance(points[i], lineStart: points[0], lineEnd: points[end])
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = i
                }
            }
            
            if maxDistance > epsilon {
                let left = Array(points[0...maxIndex])
                let right = Array(points[maxIndex...end])
                
                let leftSimplified = douglasPeucker(left, epsilon: epsilon)
                let rightSimplified = douglasPeucker(right, epsilon: epsilon)
                
                return leftSimplified + Array(rightSimplified.dropFirst())
            } else {
                return [points[0], points[end]]
            }
        }
        
        return douglasPeucker(contour, epsilon: epsilon)
    }
    
    private static func findBestScreenContour(_ contours: [[CGPoint]], imageSize: CGSize, verbose: Bool) -> [CGPoint]? {
        var bestContour: [CGPoint]?
        var bestScore: Double = 0
        
        for contour in contours {
            let area = calculatePolygonArea(contour)
            let aspectRatio = calculateAspectRatio(contour)
            let rectangularity = calculateRectangularity(contour)
            
            let areaScore = area / (imageSize.width * imageSize.height)
            let aspectScore = getAspectRatioScore(aspectRatio)
            let rectangularityScore = Double(rectangularity)
            
            let totalScore = areaScore * 0.4 + aspectScore * 0.3 + rectangularityScore * 0.3
            
            if verbose {
                print("Contour: area=\(String(format: "%.3f", areaScore)), aspect=\(String(format: "%.2f", aspectRatio)), rect=\(String(format: "%.3f", rectangularityScore)), total=\(String(format: "%.3f", totalScore))")
            }
            
            if totalScore > bestScore {
                bestScore = totalScore
                bestContour = contour
            }
        }
        
        return bestScore > 0.2 ? bestContour : nil
    }
    
    private static func detectEdgesSimple(_ data: [UInt8], width: Int, height: Int, verbose: Bool) -> [UInt8] {
        if verbose { print("Detecting edges with simple gradient...") }
        
        var edges = [UInt8](repeating: 0, count: width * height)
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = (y * width + x) * 4
                
                let current = Int(data[index])
                let right = Int(data[index + 4])
                let bottom = Int(data[((y + 1) * width + x) * 4])
                
                let gx = abs(right - current)
                let gy = abs(bottom - current)
                let gradient = gx + gy
                
                edges[y * width + x] = gradient > 30 ? 255 : 0
            }
        }
        
        return edges
    }
    
    private static func detectLines(_ edges: [UInt8], width: Int, height: Int, verbose: Bool) -> [HoughLine] {
        if verbose { print("Detecting lines with Hough transform...") }
        
        let thetaRes = 180
        let rhoRes = Int(sqrt(Double(width * width + height * height)))
        var accumulator = [[Int]](repeating: [Int](repeating: 0, count: rhoRes), count: thetaRes)
        
        // Hough transform
        for y in 0..<height {
            for x in 0..<width {
                if edges[y * width + x] == 255 {
                    for theta in 0..<thetaRes {
                        let thetaRad = Double(theta) * Double.pi / 180.0
                        let rho = Double(x) * cos(thetaRad) + Double(y) * sin(thetaRad)
                        let rhoIndex = Int(rho + Double(rhoRes) / 2)
                        
                        if rhoIndex >= 0 && rhoIndex < rhoRes {
                            accumulator[theta][rhoIndex] += 1
                        }
                    }
                }
            }
        }
        
        // Find peaks in accumulator
        var lines: [HoughLine] = []
        let threshold = 50
        
        for theta in 0..<thetaRes {
            for rho in 0..<rhoRes {
                if accumulator[theta][rho] > threshold {
                    let thetaRad = Double(theta) * Double.pi / 180.0
                    let rhoValue = Double(rho) - Double(rhoRes) / 2
                    lines.append(HoughLine(rho: rhoValue, theta: thetaRad, votes: accumulator[theta][rho]))
                }
            }
        }
        
        // Sort by votes and return top lines
        lines.sort { $0.votes > $1.votes }
        let maxLines = min(20, lines.count)
        
        if verbose { print("Detected \(maxLines) lines") }
        return Array(lines.prefix(maxLines))
    }
    
    private static func findScreenRectangleFromLines(_ lines: [HoughLine], imageSize: CGSize, verbose: Bool) -> [CGPoint]? {
        if verbose { print("Finding screen rectangle from \(lines.count) lines...") }
        
        // Group lines into horizontal and vertical
        var horizontalLines: [HoughLine] = []
        var verticalLines: [HoughLine] = []
        
        for line in lines {
            let angle = abs(line.theta * 180 / Double.pi)
            if (angle < 30 || angle > 150) {
                horizontalLines.append(line)
            } else if angle > 60 && angle < 120 {
                verticalLines.append(line)
            }
        }
        
        if verbose { print("Grouped into \(horizontalLines.count) horizontal and \(verticalLines.count) vertical lines") }
        
        guard horizontalLines.count >= 2 && verticalLines.count >= 2 else {
            if verbose { print("Insufficient horizontal or vertical lines") }
            return nil
        }
        
        // Find intersections to form rectangle corners
        var corners: [CGPoint] = []
        
        for h in 0..<min(2, horizontalLines.count) {
            for v in 0..<min(2, verticalLines.count) {
                if let intersection = lineIntersection(horizontalLines[h], verticalLines[v]) {
                    if intersection.x >= 0 && intersection.x <= imageSize.width &&
                       intersection.y >= 0 && intersection.y <= imageSize.height {
                        corners.append(intersection)
                    }
                }
            }
        }
        
        guard corners.count == 4 else {
            if verbose { print("Could not find 4 valid corners: \(corners.count)") }
            return nil
        }
        
        // Sort corners to form proper rectangle
        return sortRectangleCorners(corners)
    }
    
    // MARK: - Utility Functions
    
    private static func calculatePolygonArea(_ points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0 }
        
        var area: Double = 0
        let n = points.count
        
        for i in 0..<n {
            let j = (i + 1) % n
            area += Double(points[i].x * points[j].y)
            area -= Double(points[j].x * points[i].y)
        }
        
        return abs(area) / 2.0
    }
    
    private static func calculateAspectRatio(_ corners: [CGPoint]) -> Double {
        guard corners.count == 4 else { return 0 }
        
        let width1 = distance(corners[0], corners[1])
        let width2 = distance(corners[2], corners[3])
        let height1 = distance(corners[0], corners[3])
        let height2 = distance(corners[1], corners[2])
        
        let avgWidth = (width1 + width2) / 2
        let avgHeight = (height1 + height2) / 2
        
        return avgWidth / avgHeight
    }
    
    private static func calculateRectangularity(_ corners: [CGPoint]) -> Float {
        guard corners.count == 4 else { return 0 }
        
        // Calculate internal angles
        var angleSum: Double = 0
        let n = corners.count
        
        for i in 0..<n {
            let prev = corners[(i - 1 + n) % n]
            let curr = corners[i]
            let next = corners[(i + 1) % n]
            
            let angle = calculateAngle(prev, curr, next)
            angleSum += abs(angle - Double.pi / 2) // Deviation from 90 degrees
        }
        
        // Higher score means more rectangular (closer to 90-degree angles)
        let maxDeviation = Double.pi / 2 * 4 // Max possible deviation
        return Float(1.0 - (angleSum / maxDeviation))
    }
    
    private static func getAspectRatioScore(_ aspectRatio: Double) -> Double {
        // Common screen aspect ratios: 16:9, 4:3, 16:10, 21:9
        let commonRatios = [16.0/9.0, 4.0/3.0, 16.0/10.0, 21.0/9.0]
        
        var bestScore: Double = 0
        for ratio in commonRatios {
            let score = 1.0 / (1.0 + abs(aspectRatio - ratio))
            bestScore = max(bestScore, score)
        }
        
        return bestScore
    }
    
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(Double(dx * dx + dy * dy))
    }
    
    private static func calculateAngle(_ p1: CGPoint, _ center: CGPoint, _ p2: CGPoint) -> Double {
        let v1x = p1.x - center.x
        let v1y = p1.y - center.y
        let v2x = p2.x - center.x
        let v2y = p2.y - center.y
        
        let dot = Double(v1x * v2x + v1y * v2y)
        let cross = Double(v1x * v2y - v1y * v2x)
        
        return atan2(cross, dot)
    }
    
    private static func perpendicularDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        if dx == 0 && dy == 0 {
            return distance(point, lineStart)
        }
        
        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy)
        let projectionX = lineStart.x + t * dx
        let projectionY = lineStart.y + t * dy
        
        return distance(point, CGPoint(x: projectionX, y: projectionY))
    }
    
    private static func lineIntersection(_ line1: HoughLine, _ line2: HoughLine) -> CGPoint? {
        let cos1 = cos(line1.theta)
        let sin1 = sin(line1.theta)
        let cos2 = cos(line2.theta)
        let sin2 = sin(line2.theta)
        
        let det = cos1 * sin2 - sin1 * cos2
        
        guard abs(det) > 1e-10 else { return nil } // Lines are parallel
        
        let x = (line1.rho * sin2 - line2.rho * sin1) / det
        let y = (line2.rho * cos1 - line1.rho * cos2) / det
        
        return CGPoint(x: x, y: y)
    }
    
    private static func sortRectangleCorners(_ corners: [CGPoint]) -> [CGPoint] {
        guard corners.count == 4 else { return corners }
        
        // Find center point
        let centerX = corners.map { $0.x }.reduce(0, +) / CGFloat(corners.count)
        let centerY = corners.map { $0.y }.reduce(0, +) / CGFloat(corners.count)
        let center = CGPoint(x: centerX, y: centerY)
        
        // Sort by angle from center
        let sorted = corners.sorted { corner1, corner2 in
            let angle1 = atan2(corner1.y - center.y, corner1.x - center.x)
            let angle2 = atan2(corner2.y - center.y, corner2.x - center.x)
            return angle1 < angle2
        }
        
        return sorted
    }
}

// MARK: - Supporting Types

struct HoughLine {
    let rho: Double
    let theta: Double
    let votes: Int
}

extension CIVector {
    convenience init(CGPoint point: CGPoint) {
        self.init(x: point.x, y: point.y)
    }
}