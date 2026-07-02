# FloatingMenuApp

An Android application featuring a floating menu/action button implementation.

## Features

- Floating action menu with customizable options
- Smooth animations and transitions
- Easy to integrate into existing Android projects

## Getting Started

### Prerequisites

- Android Studio Arctic Fox or later
- Android SDK 21+
- Gradle 7.0+

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/beyondbday69/FloatingMenuApp.git
   ```

2. Open the project in Android Studio

3. Build and run the project on an emulator or physical device

## Project Structure

```
app/
├── src/
│   ├── main/
│   │   ├── java/           # Main source code
│   │   ├── res/            # Resources (layouts, drawables, values)
│   │   └── AndroidManifest.xml
│   └── test/               # Unit tests
└── build.gradle            # App-level build configuration
```

## Usage

Add the floating menu to your layout:

```xml
<com.example.floatingmenu.FloatingMenu
    android:id="@+id/floatingMenu"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:layout_gravity="bottom|end"
    android:layout_margin="16dp" />
```

## Building

```bash
# Debug build
./gradlew assembleDebug

# Release build
./gradlew assembleRelease
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request