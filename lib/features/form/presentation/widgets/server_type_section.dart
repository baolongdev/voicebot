import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../domain/models/server_form_data.dart';

class ServerTypeSection extends StatelessWidget {
  const ServerTypeSection({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    required this.sectionGap,
  });

  final ServerType selectedType;
  final ValueChanged<ServerType> onTypeSelected;
  final double sectionGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Loại máy chủ', style: context.theme.typography.xl),
        SizedBox(height: sectionGap),
        FocusTraversalOrder(
          order: const NumericFocusOrder(1.0),
          child: FSelectGroup<ServerType>(
            control: FMultiValueControl.lifted(
              value: {selectedType},
              onChange: (value) {
                final next = _resolveNext(value, selectedType);
                if (next != selectedType) {
                  onTypeSelected(next);
                }
              },
            ),
            children: ServerType.values.map((type) {
              return FSelectGroupItemMixin.radio<ServerType>(
                value: type,
                label: Text(_labelFor(type)),
                semanticsLabel: _labelFor(type),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _labelFor(ServerType type) {
    return switch (type) {
      ServerType.xiaoZhi => 'XiaoZhi',
      ServerType.selfHost => 'SelfHost',
    };
  }

  ServerType _resolveNext(Set<ServerType> value, ServerType current) {
    if (value.isEmpty) {
      return current;
    }
    if (value.length == 1) {
      return value.first;
    }
    return value.firstWhere((entry) => entry != current, orElse: () => current);
  }
}
