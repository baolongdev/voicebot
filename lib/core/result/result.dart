import '../errors/failure.dart';

class Result<T> {
  const Result._({this.data, this.failure});

  final T? data;
  final Failure? failure;

  bool get isSuccess => data != null;

  factory Result.success(T data) => Result._(data: data);
  factory Result.failure(Failure failure) => Result._(failure: failure);
}
