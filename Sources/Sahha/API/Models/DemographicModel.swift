//

import Foundation

public struct DemographicRequest: Codable {
    var age: Int?
    var gender: String?
    var occupation: String?
    var ethnicity: String?
    var country: String?
    var industry: String?
    var incomeRange: String?
    var education: String?
    var relationship: String?
    var locale: String?
    var livingArrangement: String?
}


struct ProfileRequest: Codable {
    var id: String
    var version: Int
    var customerId: String
}

struct ProfileResponse: Decodable {
    var id: String
    var version: Int
    var customerId: String
}

struct DemographicResponse: Decodable {
    var age: Int?
    var gender: String?
    var occupation: String?
    var ethnicity: String?
    var country: String?
    var industry: String?
    var incomeRange: String?
    var education: String?
    var relationship: String?
    var locale: String?
    var livingArrangement: String?
}
