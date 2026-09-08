import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import 'api_client.dart';

final apiConfigProvider = Provider<ApiConfig>((ref) => const ApiConfig());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(config: ref.watch(apiConfigProvider));
});
