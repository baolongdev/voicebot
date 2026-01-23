# Flutter 디자인 안티패턴

## 색상

### ❌ 고정 색상
```dart
// 나쁜 예
Text('제목', style: TextStyle(color: Colors.black))

// 좋은 예
Text('제목', style: TextStyle(
  color: Theme.of(context).colorScheme.onSurface
))
```

## 타이포그래피

### ❌ 고정 크기
```dart
// 나쁜 예
Text('제목', style: TextStyle(fontSize: 24.0))

// 좋은 예
Text('제목', style: Theme.of(context).textTheme.headlineSmall)
```

## 레이아웃

### ❌ 과도한 중첩
```dart
// 나쁜 예
Container(
  child: Center(
    child: Padding(
      padding: EdgeInsets.all(16.0),
      child: Container(
        child: Text('과도한 중첩'),
      ),
    ),
  ),
)

// 좋은 예
Padding(
  padding: EdgeInsets.all(16.0),
  child: Text('간결한 트리'),
)
```

### ❌ setState 남용
```dart
// 나쁜 예: 전체 위젯 rebuild
setState(() { counter++; });

// 좋은 예: StatefulWidget 또는 상태 관리 사용
```

## 성능

### ❌ ListView 대신 Column
```dart
// 나쁜 예: 긴 리스트
SingleChildScrollView(
  child: Column(children: longList),  // 모든 아이템 빌드
)

// 좋은 예
ListView.builder(itemBuilder: ...)  // Lazy loading
```

## 참고
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf)
