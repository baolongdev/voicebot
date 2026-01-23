# Flutter 색상 시스템

## Material Theme

Flutter는 Material Design 색상 시스템을 기본으로 사용합니다.

### ColorScheme

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  ),
)
```

### 색상 사용

```dart
// Primary
color: Theme.of(context).colorScheme.primary

// On Surface
color: Theme.of(context).colorScheme.onSurface

// Surface
color: Theme.of(context).colorScheme.surface
```

## Cupertino 색상

```dart
CupertinoThemeData(
  primaryColor: CupertinoColors.systemBlue,
  brightness: Brightness.light,
)
```

## 다크 모드

```dart
// 자동 다크 모드
MaterialApp(
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: ThemeMode.system,  // 시스템 설정 따름
)
```

## 금지 사항

❌ 고정 색상: `Colors.black`, `Colors.white` 직접 사용
❌ 다크 모드 미지원

## 참고
- [Material Color System](https://m3.material.io/styles/color)
