part of '../main.dart';

class PetsPage extends StatelessWidget {
  final List<Pet> pets;
  final TrackerDevice? Function(Pet pet) deviceForPet;
  final Future<void> Function(Pet pet) onSave;
  final Future<void> Function(Pet pet) onDelete;
  final Future<void> Function() onLoadPets;
  final bool isSyncingPets;
  final String petsStatus;
  final String petsMessage;

  const PetsPage({
    super.key,
    required this.pets,
    required this.deviceForPet,
    required this.onSave,
    required this.onDelete,
    required this.onLoadPets,
    required this.isSyncingPets,
    required this.petsStatus,
    required this.petsMessage,
  });

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'My Pets',
      subtitle: 'Create, update, and remove pet profiles',
      trailing: _CircleButton(
        icon: Icons.add_rounded,
        onTap: () => showPetDialog(context, onSave: onSave),
      ),
      children: [
        PetsSyncCard(
          status: petsStatus,
          message: petsMessage,
          loading: isSyncingPets,
          onLoadPets: onLoadPets,
        ),
        ...pets.map(
          (pet) => PetCard(
            pet: pet,
            device: deviceForPet(pet),
            onTap: () => showPetDialog(context, pet: pet, onSave: onSave),
            onDelete: () => onDelete(pet),
          ),
        ),
        InfoPanel(
          icon: Icons.info_outline_rounded,
          text:
              'Pets now use /api/v1/pets when you are signed in. Tracker assignment still stays local until the devices step.',
        ),
      ],
    );
  }
}
