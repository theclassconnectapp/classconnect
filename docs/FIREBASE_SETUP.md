# Firebase setup (Android + iOS)

## 1) Create Firebase project
- Go to Firebase Console
- Create project: `ClassConnect`

## 2) Add Android app
- Android package name: `com.example.class_connect` (or your final package)
- Download `google-services.json`
- Put it in `android/app/google-services.json`

## 3) Add iOS app
- iOS bundle id: `com.example.classConnect` (or your final bundle id)
- Download `GoogleService-Info.plist`
- Put it in `ios/Runner/GoogleService-Info.plist`

## 4) Configure via FlutterFire CLI (recommended)
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and links platforms correctly.

## 5) Enable Firebase products
- Authentication -> enable Email/Password
- Firestore Database -> create in production mode
- Firebase Storage -> create bucket

## 6) Security rules (starter)
- Firestore: allow read/write only for authenticated users
- Storage: allow read/write only for authenticated users

## 7) Run app
```bash
flutter clean
flutter pub get
flutter run
```
