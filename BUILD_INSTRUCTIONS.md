# Flutter Build Instructions for Windows (.exe) and Android (.apk)

This document explains how to set up the build environment and compile the application binaries for **Windows 11** and **Android**.

---

## 1. Prerequisites Installation

### For Windows (.exe)
1. **Flutter SDK**:
   - Download the Flutter SDK from [flutter.dev](https://docs.flutter.dev/get-started/install/windows).
   - Extract to `C:\flutter` and add `C:\flutter\bin` to your Windows user `PATH`.
2. **Visual Studio 2022**:
   - Install **Visual Studio Community 2022**.
   - Under Workloads, select **"Desktop development with C++"** (required by Flutter for Windows builds).

### For Android (.apk)
1. **Android Studio / Command Line Tools**:
   - Install Android Studio or Android SDK Command Line Tools.
   - Install the **Android SDK Platform-Tools** and **Android SDK Build-Tools (API 34)**.
2. **Java Development Kit**:
   - JDK 17 (Microsoft OpenJDK 17 is already present on your machine at `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin`).

---

## 2. Generate Drift Database Code

Before building, generate the Drift SQLite schema classes (`app_database.g.dart`):

```powershell
cd "c:\Users\Navaneethan J\Downloads\New folder"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Build Windows Executable (.exe)

Run:

```powershell
flutter build windows --release
```

**Output location:**
`build\windows\x64\runner\Release\workshop_notes.exe`

---

## 4. Build Android Application Package (.apk)

Run:

```powershell
flutter build apk --release
```

**Output location:**
`build\app\outputs\flutter-apk\app-release.apk`

---

## 5. Local LM Studio Setup

1. Open **LM Studio** on your Windows laptop.
2. Load your model (e.g., `qwen2.5-7b-instruct`).
3. Under the **Local Server** tab (`<->`), turn the server **ON** (Port `1234`).
4. **For Android Testing**: Ensure **"Serve on Local Network"** is enabled in LM Studio, and ensure your Android phone is connected to the same Wi-Fi network. In `lib/main.dart`, set `androidHost` to your laptop's Wi-Fi IP (e.g. `192.168.1.15`).
