import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../system/update/github_updater.dart';

class UpdateCubit extends Cubit<UpdateDownloadState> {
  UpdateCubit({GithubUpdater? updater})
    : _updater = updater ?? GithubUpdater(),
      super(GithubUpdater.downloadState.value) {
    _listener = () {
      if (!isClosed) {
        emit(GithubUpdater.downloadState.value);
      }
    };
    GithubUpdater.downloadState.addListener(_listener);
  }

  final GithubUpdater _updater;
  late final VoidCallback _listener;

  Future<void> checkForUpdates() => _updater.checkAndUpdateIfNeeded();

  @override
  Future<void> close() {
    GithubUpdater.downloadState.removeListener(_listener);
    return super.close();
  }
}
