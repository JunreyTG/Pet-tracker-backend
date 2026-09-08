import 'api_client.dart';

class ApiPet {
  final String id;
  final String name;
  final String species;
  final String? breed;
  final int? age;
  final String? photoUrl;
  final String? deviceId;

  const ApiPet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.photoUrl,
    required this.deviceId,
  });

  factory ApiPet.fromJson(Map<String, dynamic> json) {
    return ApiPet(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      species: json['species'] as String? ?? '',
      breed: json['breed'] as String?,
      age: json['age'] as int?,
      photoUrl: json['photo_url'] as String?,
      deviceId: json['device_id'] as String?,
    );
  }
}

class PetPayload {
  final String name;
  final String species;
  final String? breed;
  final int? age;
  final String? photoUrl;

  const PetPayload({
    required this.name,
    required this.species,
    this.breed,
    this.age,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'photo_url': photoUrl,
    };
  }
}

class PetsApi {
  final ApiClient _client;

  const PetsApi(this._client);

  Future<List<ApiPet>> listPets() async {
    final json = await _client.getList('/api/v1/pets');
    return json.whereType<Map<String, dynamic>>().map(ApiPet.fromJson).toList();
  }

  Future<ApiPet> createPet(PetPayload payload) async {
    final json = await _client.postJson('/api/v1/pets', body: payload.toJson());
    return ApiPet.fromJson(json);
  }

  Future<ApiPet> updatePet(String id, PetPayload payload) async {
    final json = await _client.patchJson(
      '/api/v1/pets/$id',
      body: payload.toJson(),
    );
    return ApiPet.fromJson(json);
  }

  Future<void> deletePet(String id) async {
    await _client.delete('/api/v1/pets/$id');
  }
}
