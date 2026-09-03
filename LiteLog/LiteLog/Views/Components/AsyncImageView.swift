import SwiftUI

struct AsyncImageView: View {
    let url: URL?
    let placeholder: () -> AnyView
    let errorPlaceholder: () -> AnyView
    let contentMode: ContentMode
    let cacheKey: String?
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    
    init(
        url: URL?,
        placeholder: @escaping () -> AnyView = { AnyView(Image(systemName: "person.circle.fill")) },
        errorPlaceholder: @escaping () -> AnyView = { AnyView(Image(systemName: "person.circle.fill")) },
        contentMode: ContentMode = .fill,
        cacheKey: String? = nil
    ) {
        self.url = url
        self.placeholder = placeholder
        self.errorPlaceholder = errorPlaceholder
        self.contentMode = contentMode
        self.cacheKey = cacheKey
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if error != nil {
                errorPlaceholder()
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            error = NSError(domain: "AsyncImageView", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL is nil"])
            return
        }
        
        if let cacheKey = cacheKey, let cached = ImageCache.shared.image(forKey: cacheKey) {
            image = cached
            return
        }
        
        isLoading = true
        error = nil
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let data = data, let uiImage = UIImage(data: data) else {
                    self.error = NSError(domain: "AsyncImageView", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])
                    return
                }
                
                self.image = uiImage
                
                if let cacheKey = self.cacheKey {
                    ImageCache.shared.setImage(uiImage, forKey: cacheKey)
                }
            }
        }.resume()
    }
}

class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    
    private init() {
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 10 * 1024 * 1024
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        diskCacheURL = documentsDir.appendingPathComponent("ImageCache")
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    private func diskFilename(_ key: String) -> String {
        key.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: ".", with: "_")
    }
    
    func image(forKey key: String) -> UIImage? {
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        let fileURL = diskCacheURL.appendingPathComponent(diskFilename(key))
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
                memoryCache.setObject(image, forKey: key as NSString)
                return image
            }
        }
        return nil
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
        let fileURL = diskCacheURL.appendingPathComponent(diskFilename(key))
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }
    
    func removeImage(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        let fileURL = diskCacheURL.appendingPathComponent(diskFilename(key))
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func clear() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}