# CrackAI Android app

CrackAI is a Flutter Android application that performs crack segmentation on-device with the locally packaged YOLO26n-seg ONNX model. It has no backend, REST API, or cloud dependency. Analysis images, overlays, measurements, and recommendations are stored in the app's private SQLite database.

## Run and build

From this directory:

```powershell
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
flutter build apk --release
```

The APKs are written to `build/app/outputs/flutter-apk/`. See the parent project's [Android deployment guide](../documentation/ANDROID_DEPLOYMENT.md) for SDK requirements, signing, limitations, and offline verification.

## Model and limitations

- The segmentation model in `assets/models/crack_seg.onnx` was exported from the project's original YOLO26n-seg checkpoint. It executes locally through ONNX Runtime Mobile.
- The model detects one class, `crack`. Its confidence thresholds remain provisional.
- The separately trained MobileNet classifier's weights were not present in the source workspace. The app does not claim to run that missing model.
- Width-based severity is only shown when the user supplies a calibrated millimeters-per-original-pixel scale. Recommendations are an offline, rule-based adaptation of the existing project knowledge base.
- The result is a preliminary visual assessment, not a structural safety diagnosis.
