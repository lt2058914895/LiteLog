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
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 10 * 1024 * 1024
    }
    
    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}