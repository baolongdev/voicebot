# Flutter 타이포그래피

## Material TextTheme

| 스타일 | Dart | 기본 크기 | 용도 |
|--------|------|-----------|------|
| Display Large | `displayLarge` | 57sp | 히어로 |
| Headline Large | `headlineLarge` | 32sp | 페이지 제목 |
| Title Large | `titleLarge` | 22sp | 섹션 제목 |
| Body Large | `bodyLarge` | 16sp | 강조 본문 |
| Body Medium | `bodyMedium` | 14sp | **기본 본문** |
| Label Large | `labelLarge` | 14sp | 버튼 |

## 사용법

```dart
Text(
  '제목',
  style: Theme.of(context).textTheme.headlineMedium,
)

Text(
  '본문',
  style: Theme.of(context).textTheme.bodyMedium,
)
```

## Cupertino 타이포그래피

```dart
Text(
  'iOS 스타일',
  style: CupertinoTheme.of(context).textTheme.textStyle,
)
```

## 커스텀 TextTheme

```dart
TextTheme(
  headlineMedium: TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.bold,
  ),
)
```

## 참고
- [Material Typography](https://m3.material.io/styles/typography)
