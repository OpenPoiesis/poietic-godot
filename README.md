# Poietic Godot

[Godot game engine](http://godotengine.org) extension that wraps
[Poietic Flows](https://github.com/OpenPoiesis/poietic-flows) library
to create systems/causal modelling and simulation applications.

Uses [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot).

## Build and Use

Follow instructions at the [SwiftGodot page](https://github.com/migueldeicaza/SwiftGodot).

```
swift build
```

Copy the `*.dylib` files from the `.build` directory into your Godot project.

Add the following extension file, preferably named `Poietic.gdextension` to your Godot project:

```
[configuration]
entry_symbol = "swift_entry_point"
compatibility_minimum = 4.2


[libraries]
macos.debug = "res://bin/libPoieticGodot.dylib"


[dependencies]
macos.debug = {"res://bin/libSwiftGodot.dylib" : ""}
```

## Development Notes

- Godot API (callables and variable names) should follow Godot naming conventions, not Swift.

## Author

- [Stefan Urbanek](mailto:stefan.urbanek@gmail.com)
