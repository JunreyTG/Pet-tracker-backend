part of '../main.dart';

class NotificationSettingsPage extends StatelessWidget {
  final List<PushToken> tokens;
  final ValueChanged<PushToken> onSave;

  const NotificationSettingsPage({
    super.key,
    required this.tokens,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notifications')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTokenDialog(context, onSave: onSave),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: tokens
            .map(
              (token) => AppCard(
                child: ListTile(
                  leading: Icon(
                    token.platform == NotificationPlatform.android
                        ? Icons.android
                        : Icons.phone_iphone,
                    color: const Color(0xFF5B5FEF),
                  ),
                  title: Text(token.deviceName ?? 'Unnamed device'),
                  subtitle: Text(
                    '${token.platform.name} • ${token.active ? 'active' : 'inactive'}',
                  ),
                  trailing: Switch(
                    value: token.active,
                    onChanged: (value) {
                      token.active = value;
                      onSave(token);
                    },
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
