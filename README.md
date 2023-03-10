# Vector graphics plugin for Godot 3

This is a prototype vector graphics and SVG import plugin written for the [Godot game engine](https://github.com/godotengine/godot). It uses a tracing shader to draw the shapes in real time, without tessellating the shape. Curve winding is calculated for every pixel.

Both SVG import and an internal vector shape editor are available as options for creating the shape. Strokes are available using a runtime stroke to fill filter node, and basic linear and radial gradients are implemented in the fill shader.

# Usage

Copy the `addons` folder to your project. Then go to `Project`->`Project Settings...`->`Plugins` and check the checkbox in the `Enable` column in the `Vector 2D Graphics` row.

Then either import an SVG normally (e.g. via drag and drop), or create a new shape using the `Vector2DShape` and `Vector2DFill` nodes. Note: It is better to first use an SVG as an example for how these nodes work.

# Limitations

While some optimizations are used, calculating winding for every pixel can be particularly slow for shapes made from a large amount of segments.

The vector shape editor is extremely bare bones, and lacks many quality of life features, like automatic smooth handles, box/lasso selection, or scale/rotate for multiple selected points. It also lacks a few necessary basic features.

There are two options to animate a shape:
- One is to animate the individual points throw the `Vector2DShape`'s properties. Since shapes are stored as resources, if a shape is used in a scene that is used multiple times, the resource must be set to be `Local to scene`, otherwise the animation would apply to all instances.
- The other is to completely replace the shape's resource associated with the `Vector2DShape`. This is useful for frame by frame animations, but doesn't allow tweening.

Due to limitations of Godot's editor, it's not possible to edit multiple shapes at once, even though aligning points between different shapes can be useful.

## SVG import limitations

- No features involving external files are supported, since only a single-file import exists.
- External resources using data URL are not currently implemented. However, it could be added for image textures.
- JavaScript obviously can't be supported, since automatically porting it to GDScript would be too complex.
- SMIL animations are not currently supported, although they can be by converting them to animation nodes.
- CSS stylesheets are not supported. But inline CSS is. Import of CSS stylesheets would necessarily be lossy (only import computed styles), since Godot can't do CSS resolution at runtime.
- Dashing strokes is not currently implemented.
- Pattern fills are not currently implemented.
- Clip shapes are not implemented, since it is difficult to implement in Godot 3. It can be done using viewports, but would become significantly simpler with native clip mask support added in Godot 4.
- Markers are not implemented. It is an extremely niche feature, and the CSS rules involved are quite complex.

# License

Released to the public domain. See [UNLICENSE](UNLICENSE). This only applies to this addon, and not to Godot itself (Obviously).

# TODO

- Implement mesh gradients.
- Improve the shape editor.
- Add a way to open or close a subpath in the shape editor.
- Add a way to rearrange subpaths and points in the shape editor.
- Add a `Vector2DTween` node to tween between two shapes without having to animate individual points.
- Add a stroke dasher.
- Add support for textures/patterns.
- Support more SVG features on import.
- Add a path length filter to allow creating an animated "path being stroked" effect.
- Binding vector points to a `Skeleton2D` for animations
- Add a remote transform to make a 2D object follow a vector path.

# Contribution

Just fork it. It's a hobby project/proof of concept, and will most likely be invalidated with the release of Godot 4.
