import Foundation

public enum BrandFile {
    public static func url(_ name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png")
    }
}
