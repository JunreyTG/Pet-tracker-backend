import 'api_client.dart';
export '../features/auth/models/current_user.dart';

import '../features/auth/models/current_user.dart';

class AuthApi {
  final ApiClient _client;

  const AuthApi(this._client);

  Future<CurrentUser> me() async {
    final json = await _client.getJson('/api/v1/auth/me');
    return CurrentUser.fromJson(json);
  }
}
