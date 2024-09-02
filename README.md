# DENNetworking Swift


## Installation
### Swift Package Manager (SPM)

#### Option 1: Using Xcode UI

1. In Xcode, go to File > Add Packages...
2. Enter: `https://github.com/yaffiazmidev/DENNetworking.git`
3. Select the desired version/branch
4. Choose your target(s)
5. Click "Add Package"

#### Option 2: Using Package.swift

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yaffiazmidev/DENNetworking", .upToNextMajor(from: "1.0.0"))
]
```

Then, include "Installations" as a dependency for your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "DENNetworking", package: "DENNetworking"),
        ]),
]
```
