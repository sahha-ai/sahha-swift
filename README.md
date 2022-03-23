# Sahha

## SDK

You can connect to the Sahha API via the iOS SDK.

[iOS SDK [GitHub]](https://github.com/sahha-ai/sahha-swift){:target="\_blank"}

---

## Example

You can test the features of the iOS SDK by trying the iOS Example App.

[iOS Example App [GitHub]](https://github.com/sahha-ai/sahha-example-ios){:target="\_blank"}

---

## Configure

Option A) Configure Sahha inside `onAppear` of your app's `ContentView`.

{: .no_toc }

#### SwiftUI

```swift
ContentView().onAppear {
    Sahha.configure()
}
```

Option B) Configure Sahha inside `application didFinishLaunchingWithOptions` of your app's `AppDelegate`.

{: .no_toc }

#### UIKit

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    Sahha.configure()
}
```

---

## Authenticate

```swift
Sahha.authenticate(customerId: "CUSTOMER_ID", profileId: "PROFILE_ID", token: "TOKEN")
```

---

## Profile



---

## Health Activity

Health Activity has multiple possible statuses.

### Activity Status

```swift
public enum ActivityStatus: Int {
    case pending /// Activity support is pending User permission
    case unavailable /// Activity is not supported by the User's device
    case disabled /// Activity has been disabled by the User
    case enabled /// Activity has been enabled by the User

    public var description: String {
        String(describing: self)
    }
}

public private(set) var activityStatus: ActivityStatus = .unknown
```

You can check the current activity status by calling the property `activityStatus`.

```swift
print(Sahha.health.activityStatus.description)
```

You will need to manually activate Health Activity. This method is asynchronous and will return the updated `ActivityStatus` in its callback.

### Activate

```swift
Sahha.health.activate { newStatus in
    print(newStatus.description)
}
```

---

## Motion Activity

Motion Activity has multiple possible statuses.

### Activity Status

```swift
public enum ActivityStatus: Int {
    case pending /// Activity support is pending User permission
    case unavailable /// Activity is not supported by the User's device
    case disabled /// Activity has been disabled by the User
    case enabled /// Activity has been enabled by the User

    public var description: String {
        String(describing: self)
    }
}

public private(set) var activityStatus: ActivityStatus = .pending
```

You can check the current activity status by calling the property `activityStatus`.

```swift
print(Sahha.motion.activityStatus.description)
```

You will need to manually activate Motion Activity. This method is asynchronous and will return the updated `ActivityStatus` in its callback.

### Activate

```swift
Sahha.motion.activate { newStatus in
    print(newStatus.description)
}
```

### Prompt User to Activate

It's possible for the user to decline the automated activation. You can determine this by checking `. You may choose to manually prompt the user to activate Motion Activity. We suggest calling this method inside the action block of an Alert.

```swift
Sahha.motion.promptUserToActivate { newStatus in
    print(newStatus.description)
}
```

{: .no_toc }

#### SwiftUI

```swift
if Sahha.motion.activityStatus == .disabled {

    Alert(
        title: Text("Motion & Fitness"),
        message: Text("Please enable this app to access your Motion & Fitness data"),
        dismissButton: .default(Text("Open App Settings"), action: {
            Sahha.motion.promptUserToActivate { newStatus in
                print(newStatus.description)
            }
        })
    )

}
```

{: .no_toc }

#### UIKit

```swift
if Sahha.motion.activityStatus == .disabled {

    var alert = UIAlertController(title: "Motion & Fitness", message: "Please enable this app to access your Motion & Fitness data", preferredStyle: .alert)

    let alertAction = UIAlertAction(title: "Open App Settings", style: .default, handler: { _ in
        Sahha.motion.promptUserToActivate { newStatus in
            print(newStatus.description)
        }
    })

    alert.addAction(alertAction)

    present(alert, animated: true, completion: nil)

}
```

---

# Analyze
