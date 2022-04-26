//

import Foundation

public struct SahhaDemographic: Codable {
    public var age: Int?
    public var gender: String?
    public var country: String?
    public var birthCountry: String?
    /*
     // Coming Soon
    public var ethnicity: String?
    public var occupation: String?
    public var industry: String?
    public var incomeRange: String?
    public var education: String?
    public var relationship: String?
    public var locale: String?
    public var livingArrangement: String?
     */
    
    public init(age: Int? = nil, gender: String? = nil, country: String? = nil, birthCountry: String? = nil) {
        self.age = age
        self.gender = gender
        self.country = country
        self.birthCountry = birthCountry
    }
}
