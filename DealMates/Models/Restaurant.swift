import Foundation

struct Restaurant: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var cuisine: String
    var address: String
    var imageUrl: String?
    var latitude: Double?
    var longitude: Double?

    init(id: String, name: String, cuisine: String, address: String, imageUrl: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.address = address
        self.imageUrl = imageUrl
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension Restaurant {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cuisine
        case address
        case imageUrl = "image_url"
        case latitude
        case longitude
    }
}
