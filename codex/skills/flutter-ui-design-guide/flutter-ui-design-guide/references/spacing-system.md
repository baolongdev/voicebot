# Flutter 간격 시스템

## 8dp 그리드

Flutter도 8의 배수 간격 권장:

| 값 | Dart | 용도 |
|----|------|------|
| 4.0 | 4.0 | 최소 간격 |
| 8.0 | 8.0 | 작은 간격 |
| 16.0 | 16.0 | **기본 간격** |
| 24.0 | 24.0 | 중간 간격 |
| 32.0 | 32.0 | 큰 간격 |
| 48.0 | 48.0 | 터치 타겟 최소 |

## Padding

```dart
// 모든 방향
Padding(padding: EdgeInsets.all(16.0), child: ...)

// 방향별
Padding(
  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  child: ...
)

// 개별
Padding(
  padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
  child: ...
)
```

## SizedBox (간격)

```dart
Column(
  children: [
    Text('A'),
    SizedBox(height: 16.0),
    Text('B'),
  ],
)
```

## 터치 타겟

최소 48x48dp:

```dart
IconButton(
  iconSize: 24.0,
  padding: EdgeInsets.all(12.0),  // 총 48x48
  icon: Icon(Icons.add),
  onPressed: () {},
)
```

## 참고
- [Material Layout](https://m3.material.io/foundations/layout)
