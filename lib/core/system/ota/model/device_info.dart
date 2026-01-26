import 'dart:convert';
import 'dart:math';

// Ported from Android Kotlin: DeviceInfo.kt
class ChipInfo {
  const ChipInfo({
    required this.model,
    required this.cores,
    required this.revision,
    required this.features,
  });

  final int model;
  final int cores;
  final int revision;
  final int features;

  factory ChipInfo.fromJson(Map<String, dynamic> json) {
    return ChipInfo(
      model: json['model'] as int,
      cores: json['cores'] as int,
      revision: json['revision'] as int,
      features: json['features'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'model': model,
      'cores': cores,
      'revision': revision,
      'features': features,
    };
  }
}

// Ported from Android Kotlin: DeviceInfo.kt
class Application {
  const Application({
    required this.name,
    required this.version,
    required this.compileTime,
    required this.idfVersion,
    required this.elfSha256,
  });

  final String name;
  final String version;
  final String compileTime;
  final String idfVersion;
  final String elfSha256;

  factory Application.fromJson(Map<String, dynamic> json) {
    return Application(
      name: json['name'] as String,
      version: json['version'] as String,
      compileTime: json['compile_time'] as String,
      idfVersion: json['idf_version'] as String,
      elfSha256: json['elf_sha256'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'version': version,
      'compile_time': compileTime,
      'idf_version': idfVersion,
      'elf_sha256': elfSha256,
    };
  }
}

// Ported from Android Kotlin: DeviceInfo.kt
class Partition {
  const Partition({
    required this.label,
    required this.type,
    required this.subtype,
    required this.address,
    required this.size,
  });

  final String label;
  final int type;
  final int subtype;
  final int address;
  final int size;

  factory Partition.fromJson(Map<String, dynamic> json) {
    return Partition(
      label: json['label'] as String,
      type: json['type'] as int,
      subtype: json['subtype'] as int,
      address: json['address'] as int,
      size: json['size'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'type': type,
      'subtype': subtype,
      'address': address,
      'size': size,
    };
  }
}

// Ported from Android Kotlin: DeviceInfo.kt
class Ota {
  const Ota({required this.label});

  final String label;

  factory Ota.fromJson(Map<String, dynamic> json) {
    return Ota(label: json['label'] as String);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'label': label};
  }
}

// Ported from Android Kotlin: DeviceInfo.kt
class Board {
  const Board({
    required this.name,
    required this.revision,
    required this.features,
    required this.manufacturer,
    required this.serialNumber,
  });

  final String name;
  final String revision;
  final List<String> features;
  final String manufacturer;
  final String serialNumber;

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      name: json['name'] as String,
      revision: json['revision'] as String,
      features: (json['features'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      manufacturer: json['manufacturer'] as String,
      serialNumber: json['serial_number'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'revision': revision,
      'features': features,
      'manufacturer': manufacturer,
      'serial_number': serialNumber,
    };
  }
}

// Ported from Android Kotlin: DeviceInfo.kt
class DeviceInfo {
  const DeviceInfo({
    required this.version,
    required this.flashSize,
    required this.psramSize,
    required this.minimumFreeHeapSize,
    required this.macAddress,
    required this.uuid,
    required this.chipModelName,
    required this.chipInfo,
    required this.application,
    required this.partitionTable,
    required this.ota,
    required this.board,
  });

  final int version;
  final int flashSize;
  final int psramSize;
  final int minimumFreeHeapSize;
  final String macAddress;
  final String uuid;
  final String chipModelName;
  final ChipInfo chipInfo;
  final Application application;
  final List<Partition> partitionTable;
  final Ota ota;
  final Board board;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      version: json['version'] as int,
      flashSize: json['flash_size'] as int,
      psramSize: json['psram_size'] as int,
      minimumFreeHeapSize: json['minimum_free_heap_size'] as int,
      macAddress: json['mac_address'] as String,
      uuid: json['uuid'] as String,
      chipModelName: json['chip_model_name'] as String,
      chipInfo: ChipInfo.fromJson(json['chip_info'] as Map<String, dynamic>),
      application: Application.fromJson(
        json['application'] as Map<String, dynamic>,
      ),
      partitionTable: (json['partition_table'] as List<dynamic>)
          .map((e) => Partition.fromJson(e as Map<String, dynamic>))
          .toList(),
      ota: Ota.fromJson(json['ota'] as Map<String, dynamic>),
      board: Board.fromJson(json['board'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'flash_size': flashSize,
      'psram_size': psramSize,
      'minimum_free_heap_size': minimumFreeHeapSize,
      'mac_address': macAddress,
      'uuid': uuid,
      'chip_model_name': chipModelName,
      'chip_info': chipInfo.toJson(),
      'application': application.toJson(),
      'partition_table': partitionTable.map((e) => e.toJson()).toList(),
      'ota': ota.toJson(),
      'board': board.toJson(),
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

// Ported from Android Kotlin: DeviceInfo.kt
String deviceInfoToJson(DeviceInfo info) => info.toJsonString();

// Ported from Android Kotlin: DeviceInfo.kt
DeviceInfo fromJsonToDeviceInfo(String json) {
  final obj = jsonDecode(json) as Map<String, dynamic>;
  return DeviceInfo.fromJson(obj);
}

// Ported from Android Kotlin: DeviceInfo.kt
class DummyDataGenerator {
  static DeviceInfo generate() {
    final random = Random();
    return DeviceInfo(
      version: 2,
      flashSize: 8388608,
      psramSize: 4194304,
      minimumFreeHeapSize: random.nextInt(100000) + 200000,
      macAddress: _generateMacAddress(random),
      uuid: _generateUuidV4(random),
      chipModelName: 'esp32s3',
      chipInfo: const ChipInfo(model: 3, cores: 2, revision: 1, features: 5),
      application: Application(
        name: 'sensor-hub',
        version: '1.3.0',
        compileTime: '2025-02-28T12:34:56Z',
        idfVersion: '5.1-beta',
        elfSha256: _generateRandomSha256(random),
      ),
      partitionTable: const <Partition>[
        Partition(
          label: 'app',
          type: 1,
          subtype: 2,
          address: 65536,
          size: 2097152,
        ),
        Partition(
          label: 'nvs',
          type: 1,
          subtype: 1,
          address: 32768,
          size: 65536,
        ),
        Partition(
          label: 'phy_init',
          type: 1,
          subtype: 3,
          address: 98304,
          size: 8192,
        ),
      ],
      ota: const Ota(label: 'ota_1'),
      board: Board(
        name: 'ESP32S3-DevKitM-1',
        revision: 'v1.2',
        features: const <String>['WiFi', 'Bluetooth', 'USB-OTG', 'LCD'],
        manufacturer: 'Espressif',
        serialNumber: 'ESP32S3-${random.nextInt(9000) + 1000}',
      ),
    );
  }

  static String _generateMacAddress(Random random) {
    final values = List<int>.generate(6, (_) => random.nextInt(0x100));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  static String _generateRandomSha256(Random random) {
    const chars = '0123456789abcdef';
    return List<String>.generate(
      64,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  static String _generateUuidV4(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String byteToHex(int value) => value.toRadixString(16).padLeft(2, '0');
    final parts = <String>[
      bytes.sublist(0, 4).map(byteToHex).join(),
      bytes.sublist(4, 6).map(byteToHex).join(),
      bytes.sublist(6, 8).map(byteToHex).join(),
      bytes.sublist(8, 10).map(byteToHex).join(),
      bytes.sublist(10, 16).map(byteToHex).join(),
    ];
    return parts.join('-');
  }

  static String generateMacAddress() => _generateMacAddress(Random());

  static String generateUuidV4() => _generateUuidV4(Random());
}
