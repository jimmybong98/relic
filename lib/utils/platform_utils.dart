import 'package:flutter/foundation.dart';

/// Returns true if the current platform is a desktop platform.
bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Returns true if the current platform is Android.
bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
