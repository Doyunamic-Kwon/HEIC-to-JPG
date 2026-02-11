import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers
import ImageIO

// MARK: - App Entry Point
@main
struct HEICConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

// MARK: - View Model
class ConverterViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var isConverting = false
    @Published var progress: Double = 0
    @Published var statusMessage = "HEIC 파일을 이곳에 드래그하세요"
    
    struct FileItem: Identifiable {
        let id = UUID()
        let url: URL
        var status: Status = .pending
        
        enum Status {
            case pending
            case converting
            case success
            case failed
        }
    }
    
    func addFiles(urls: [URL]) {
        DispatchQueue.main.async {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ext == "heic" || ext == "heif" {
                    if !self.files.contains(where: { $0.url == url }) {
                        self.files.append(FileItem(url: url))
                    }
                }
            }
            if !self.files.isEmpty {
                self.statusMessage = "\(self.files.count)개의 파일이 준비되었습니다."
            }
        }
    }
    
    func startConversion() {
        guard !files.isEmpty else { return }
        
        isConverting = true
        progress = 0
        statusMessage = "변환 중..."
        
        let total = Double(files.count)
        
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<self.files.count {
                DispatchQueue.main.async {
                    if i < self.files.count {
                        self.files[i].status = .converting
                    }
                }
                
                let file = self.files[i]
                let success = self.convertHEICtoJPG(url: file.url)
                
                DispatchQueue.main.async {
                    if i < self.files.count {
                        self.files[i].status = success ? .success : .failed
                    }
                    self.progress = Double(i + 1) / total
                }
            }
            
            DispatchQueue.main.async {
                self.isConverting = false
                self.statusMessage = "변환 완료!"
            }
        }
    }
    
    private func convertHEICtoJPG(url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        
        let newURL = url.deletingPathExtension().appendingPathExtension("jpg")
        
        guard let destination = CGImageDestinationCreateWithURL(newURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
        
        // JPEG 품질 설정 (0.0 ~ 1.0)
        let options: [CFString: CGFloat] = [kCGImageDestinationLossyCompressionQuality: 0.95]
        
        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }
    
    func reset() {
        files.removeAll()
        progress = 0
        statusMessage = "HEIC 파일을 이곳에 드래그하세요"
        isConverting = false
    }
}

// MARK: - UI View
struct ContentView: View {
    @StateObject private var viewModel = ConverterViewModel()
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("HEIC to JPG Converter")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 20)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovering ? Color.blue : Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .background(isHovering ? Color.blue.opacity(0.1) : Color.clear)
                
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(viewModel.statusMessage)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            .frame(height: 150)
            .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
                loadFiles(from: providers)
                return true
            }
            .padding(.horizontal)
            
            List {
                ForEach(viewModel.files) { file in
                    HStack {
                        Text(file.url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        statusIcon(for: file.status)
                    }
                }
            }
            .frame(minHeight: 100)
            
            if viewModel.isConverting {
                ProgressView(value: viewModel.progress)
                    .padding(.horizontal)
            }
            
            HStack {
                Button("목록 비우기") {
                    viewModel.reset()
                }
                .disabled(viewModel.isConverting)
                
                Spacer()
                
                Button("변환 시작") {
                    viewModel.startConversion()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.files.isEmpty || viewModel.isConverting)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func loadFiles(from providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    if let data = item as? Data {
                        if let url = URL(dataRepresentation: data, relativeTo: nil) {
                            viewModel.addFiles(urls: [url])
                        }
                    } else if let url = item as? URL {
                        viewModel.addFiles(urls: [url])
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func statusIcon(for status: ConverterViewModel.FileItem.Status) -> some View {
        switch status {
        case .pending:
            Image(systemName: "hourglass")
                .foregroundColor(.gray)
        case .converting:
            ProgressView()
                .scaleEffect(0.5)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}
