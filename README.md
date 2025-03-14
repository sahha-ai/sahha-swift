# Sahha SDK for iOS Apps

The Sahha SDK provides a convenient way for iOS apps to connect to the Sahha API.

Sahha lets your project seamlessly collect health and lifestyle data from smartphones and wearables via Apple Health, Google Health Connect, and a variety of other sources.

For more information on Sahha please visit https://sahha.ai.

---

## Docs

The Sahha Docs provide detailed instructions for installation and usage of the Sahha SDK.

[Sahha Docs](https://docs.sahha.ai)

---

## Example

The Sahha Demo App provides a convenient way to try the features of the Sahha SDK.

[Sahha Demo App](https://github.com/sahha-ai/sahha-demo-ios)

---

## Health Data Source Integrations

Sahha supports integration with the following health data sources:

- [Apple Health Kit](https://sahha.notion.site/Apple-Health-HealthKit-13cb2f553bbf80c0b117cb662e04c257?pvs=25)
- [Google Fit](https://sahha.notion.site/Google-Fit-131b2f553bbf804a8ee6fef7bc1f4edb?pvs=25)
- [Google Health Connect](https://sahha.notion.site/Health-Connect-Android-13cb2f553bbf806d9d64e79fe9d07d9e?pvs=25)
- [Samsung Health](https://sahha.notion.site/Samsung-Health-d3f76840fad142469f5e724a54c24ead?pvs=25)
- [Garmin Connect](https://sahha.notion.site/Garmin-12db2f553bbf80afb916d04a62e857e6?pvs=25)
- [Polar Flow](https://sahha.notion.site/Polar-12db2f553bbf80c3968eeeab55b484a2?pvs=25)
- [Withings Health Mate](https://sahha.notion.site/Withings-12db2f553bbf80a38d31f80ab083613f?pvs=25)
- [Oura Ring](https://sahha.notion.site/Oura-12db2f553bbf80cf96f2dfd8343b4f06?pvs=25)
- [Whoop](https://sahha.notion.site/WHOOP-12db2f553bbf807192a5c69071e888f4?pvs=25)
- [Strava](https://sahha.notion.site/Strava-12db2f553bbf80c48312c2bf6aa5ac65?pvs=25)

& many more! Please visit our [integrations](https://sahha.notion.site/data-integrations?v=17eb2f553bbf80e0b0b3000c0983ab01) page for more information.

---

## Install

In the `Podfile`:

```
platform :ios, '10.0'
target 'YourProjectName' do
  use_frameworks!
  pod 'sahha-swift', '1.1.3'
end
```

#### Enable HealthKit

- Open your project in Xcode and select your `App Target` in the Project panel.
- Navigate to the `Signing & Capabilities` tab.
- Click the `+` button (or choose `Editor > Add Capability`) to open the Capabilities library.
- Locate and select `HealthKit`; double-click it to add it to your project.

#### Background Delivery

- Select your project in the Project navigator and choose your app’s target.
- In the `Signing & Capabilities` tab, find the HealthKit capability.
- Enable the nested `Background Delivery` option to allow passive health data collection.

#### Add Usage Descriptions

- Select your `App Target` and navigate to the `Info` tab.
- Click the `+` button to add a new key and choose `Privacy - Health Share Usage Description`.
- Provide a clear description, such as: "*This app needs your health info to deliver mood
  predictions*."

For more detailed instructions, refer to
our [setup guide](https://docs.sahha.ai/docs/data-flow/sdk/setup#minimum-requirements).

---

## API

<docgen-index>

* [`configure(...)`](#configure)
* [`isAuthenticated`](#isauthenticated)
* [`authenticate()`](#authenticate)
* [`deauthenticate()`](#deauthenticate)
* [`profileToken`](#profiletoken)
* [`getDemographic()`](#getdemographic)
* [`postDemographic(...)`](#postdemographic)
* [`getSensorStatus(...)`](#getsensorstatus)
* [`enableSensors(...)`](#enablesensors)
* [`getScores(...)`](#getscores)
* [`getBiomarkers(...)`](#getbiomarkers)
* [`getStats(...)`](#getstats)
* [`getSamples(...)`](#getsamples)
* [`openAppSettings()`](#openappsettings)
* [Interfaces](#interfaces)
* [Enums](#enums)

</docgen-index>

<docgen-api>

### configure(...)

```swift
public static func configure(_ settings: SahhaSettings, callback: (() -> Void)? = nil)
```

**Example usage**:

```swift
let settings = SahhaSettings(environment: .sandbox)
Sahha.configure(settings)
```

---

### isAuthenticated

```swift
public static var isAuthenticated: Bool
```

**Example usage**:

```swift
if (Sahha.isAuthenticated == false) {
    // E.g. Authenticate the user
}
```

---

### authenticate(...)

```swift
public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping (String?, Bool) -> Void)
```

**Example usage**:

```swift
Sahha.authenticate(
    appId: APP_ID,
    appSecret: APP_SECRET,
    externalId: EXTERNAL_ID // Some unique identifier for the user
) { error, success in
    if let error = error {
        print(error)
    } else if success {
        print(success)
    }
}
```

---

### deauthenticate()

```swift
public static func deauthenticate(callback: @escaping (String?, Bool) -> Void)
```

**Example usage**:

```swift
Sahha.deauthenticate { error, success in
    if let error = error {
        print(error)
    } else if success {
        print(success)
    }
}
```

---

### profileToken

```swift
public static var profileToken: String?
```

**Example usage**:

```swift
if let profileToken = Sahha.profileToken {
    // Do something with the token
}
```

---

### getDemographic()

```swift
public static func getDemographic(callback: @escaping (String?, SahhaDemographic?) -> Void)
```

**Example usage**:

```swift
Sahha.getDemographic { error, value in
    if let error = error {
        print(error)
    }
    else if let value = value {
        print(value)
    }
}
```

---

### postDemographic(...)

```swift
public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping (String?, Bool) -> Void)
```

**Example usage**:

```swift
Sahha.postDemographic(demographic) { error, success in
    if let error = error {
        print(error)
    }
    print(success)
}
```

---

### getSensorStatus(...)

```swift
public static func getSensorStatus(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus)->Void)
```

**Example usage**:

```swift
let sensors: Set<SahhaSensor> = [.steps, .sleep]

Sahha.getSensorStatus(sensors) { error, status in
    if let error = error {
        print(error)
    }
    
    print(status)
}
```

---

### enableSensors(...)

```swift
public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus)->Void)
```

**Example usage**:

```swift
let sensors: Set<SahhaSensor> = [.steps, .sleep]

Sahha.enableSensors(sensors) { error, status in
    if let error = error {
        print(error)
    } 
    
    print(status)
}
```

---

### getScores(...)

```swift
public static func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, String?) -> Void)
```

**Example usage**:

```swift
let today = Date()
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? Date()

let types: Set<SahhaScoreType> = [.activity]

Sahha.getScores(types: types, startDateTime: sevenDaysAgo, endDateTime: today) { error, json in
    if let error = error {
        print(error)
    } else if let json = json {
        print(json)
    }
}
```

---

### getBiomarkers(...)

```swift
public static func getBiomarkers(
    categories: Set<SahhaBiomarkerCategory>,
    types: Set<SahhaBiomarkerType>,
    startDateTime: Date,
    endDateTime: Date,
    callback: @escaping (String?, String?) -> Void
)
```

**Example usage**:

```swift
let today = Date()
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? Date()

let categories: Set<SahhaBiomarkerCategory> = [.activity, .sleep, .vitals]
let types: Set<SahhaBiomarkerType> = [.steps, .sleep_duration, .heart_rate_sleep, .heart_rate_resting]

Sahha.getBiomarkers(
    categories: categories,
    types: types,
    startDateTime: sevenDaysAgo, endDateTime: today
) { error, json in
    if let error = error {
        print(error)
    } else if let json = json {
        print(json)
    }
}
```

---

### getStats(...)

```swift
public static func getStats(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [SahhaStat])->Void)
```

**Example usage**:

```swift
let today = Date()
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? Date()

Sahha.getStats(sensor: .steps, startDateTime: sevenDaysAgo, endDateTime: today) { error, newStats in
    if let error = error {
        print(error)
    }
    
    print(newStats)
}
```

---

### getSamples(...)

```swift
public static func getSamples(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [SahhaSample])->Void)
```

**Example usage**:

```swift
let today = Date()
let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? Date()

Sahha.getSamples(sensor: .steps, startDateTime: sevenDaysAgo, endDateTime: today) { error, newSamples in
    if let error = error {
        print(error)
    }
    
    print(newSamples)
}
```

---

### openAppSettings()

```swift
public static func openAppSettings()
```

**Example usage**:

```swift
// This method is useful when the user denies permissions multiple times -- where the prompt will no longer show
if status == SahhaSensorStatus.disabled {
    Sahha.openAppSettings()
}
```

---

### Interfaces

#### SahhaSettings

```swift
public struct SahhaSettings {
    public let environment: SahhaEnvironment /// sandbox or production
    public var framework: SahhaFramework = .ios_swift /// automatically set by sdk
}
```

#### SahhaDemographic

```swift
public struct SahhaDemographic: Codable, Equatable {
    public var age: Int?
    public var gender: String?
    public var country: String?
    public var birthCountry: String?
    public var ethnicity: String?
    public var occupation: String?
    public var industry: String?
    public var incomeRange: String?
    public var education: String?
    public var relationship: String?
    public var locale: String?
    public var livingArrangement: String?
    public var birthDate: String?
}
```

#### SahhaStat

```swift
public struct SahhaStat: Comparable, Codable {
    public var id: String
    public var category: String
    public var type: String
    public var value: Double
    public var unit: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var sources: [String]
}
```

#### SahhaSample

```swift
public struct SahhaSample: Comparable, Codable {
    public var id: String
    public var category: String
    public var type: String
    public var value: Double
    public var unit: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var recordingMethod: String
    public var source: String
    public var stats: [SahhaStat]
}
```

### Enums

#### SahhaEnvironment

```swift
public enum SahhaEnvironment: String {
    case sandbox
    case production
}
```

#### SahhaSensor

```swift
public enum SahhaSensor: String, CaseIterable {
    case gender
    case date_of_birth
    case sleep
    case steps
    case floors_climbed
    case heart_rate
    case resting_heart_rate
    case walking_heart_rate_average
    case heart_rate_variability_sdnn
    case heart_rate_variability_rmssd
    case blood_pressure_systolic
    case blood_pressure_diastolic
    case blood_glucose
    case vo2_max
    case oxygen_saturation
    case respiratory_rate
    case active_energy_burned
    case basal_energy_burned
    case total_energy_burned
    case basal_metabolic_rate
    case time_in_daylight
    case body_temperature
    case basal_body_temperature
    case sleeping_wrist_temperature
    case height
    case weight
    case lean_body_mass
    case body_mass_index
    case body_fat
    case body_water_mass
    case bone_mass
    case waist_circumference
    case stand_time
    case move_time
    case exercise_time
    case activity_summary
    case device_lock
    case exercise
}
```

#### SahhaSensorStatus

```swift
public enum SahhaSensorStatus: Int {
    case pending /// Sensor data is pending User permission
    case unavailable /// Sensor data is not supported by the User's device
    case disabled /// Sensor data has been disabled by the User
    case enabled /// Sensor data has been enabled by the User
}
```

#### SahhaScoreType

```swift
public enum SahhaScoreType: String {
    case wellbeing
    case activity
    case sleep
    case readiness
    case mental_wellbeing
}
```

#### SahhaBiomarkerCategory

```swift
public enum SahhaBiomarkerCategory: String {
    case activity
    case body
    case characteristic
    case reproductive
    case sleep
    case vitals
    case exercise
    case device
}
```

#### SahhaBiomarkerType

```swift
public enum SahhaBiomarkerType: String {
    case steps
    case floors_climbed
    case active_hours
    case active_duration
    case activity_low_intensity_duration
    case activity_mid_intensity_duration
    case activity_high_intensity_duration
    case activity_sedentary_duration
    case active_energy_burned
    case total_energy_burned
    case height
    case weight
    case body_mass_index
    case body_fat
    case fat_mass
    case lean_mass
    case waist_circumference
    case resting_energy_burned
    case age
    case biological_sex
    case date_of_birth
    case menstrual_cycle_length
    case menstrual_cycle_start_date
    case menstrual_cycle_end_date
    case menstrual_phase
    case menstrual_phase_start_date
    case menstrual_phase_end_date
    case menstrual_phase_length
    case sleep_start_time
    case sleep_end_time
    case sleep_duration
    case sleep_debt
    case sleep_interruptions
    case sleep_in_bed_duration
    case sleep_awake_duration
    case sleep_light_duration
    case sleep_rem_duration
    case sleep_deep_duration
    case sleep_regularity
    case sleep_latency
    case sleep_efficiency
    case heart_rate_resting
    case heart_rate_sleep
    case heart_rate_variability_sdnn
    case heart_rate_variability_rmssd
    case respiratory_rate
    case respiratory_rate_sleep
    case oxygen_saturation
    case oxygen_saturation_sleep
    case vo2_max
    case blood_glucose
    case blood_pressure_systolic
    case blood_pressure_diastolic
    case body_temperature_basal
    case skin_temperature_sleep
}
```


</docgen-api>

---

Copyright © 2022 Sahha. All rights reserved.
