# assets

`lyn-logo-cross.png` belongs here.

It is used twice from one file:

- the join screen mark (`lib/screens/join_screen.dart`)
- the launcher icon on both platforms, generated from it

After adding or changing it, regenerate the launcher icons:

    dart run flutter_launcher_icons

That writes into `android/app/src/main/res/mipmap-*` and
`ios/Runner/Assets.xcassets/AppIcon.appiconset`, so those are build output
from this file rather than things to edit by hand.

A square source of at least 1024x1024 gives the best result — iOS needs a
1024px icon and will not upscale for you. Transparency is fine here and is
flattened for iOS, which rejects an alpha channel in a launcher icon.
