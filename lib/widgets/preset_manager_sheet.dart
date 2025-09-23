import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ApplyPreset = Future<void> Function(String name);

class PresetManagerSheet extends StatelessWidget {
  final List<String> presetNames;
  final Map<String, Map<String, dynamic>> presets;
  final ApplyPreset onApply;
  final String storageKey; // 'f_presets_json'
  final String? selectedPresetName;

  const PresetManagerSheet({
    super.key,
    required this.presetNames,
    required this.presets,
    required this.onApply,
    required this.storageKey,
    required this.selectedPresetName,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('保存した検索（プリセット）', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            if (presetNames.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('保存されたプリセットはありません'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: presetNames.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final name = presetNames[i];
                    return ListTile(
                      title: Text(name),
                      onTap: () {
                        Navigator.pop(ctx);
                        onApply(name);
                      },
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: '名前変更',
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _renamePreset(ctx, name);
                            },
                          ),
                          IconButton(
                            tooltip: '削除',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _deletePreset(ctx, name);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _renamePreset(BuildContext context, String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プリセット名を変更'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '新しい名前'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('変更')),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == oldName) return;
    if (!presets.containsKey(oldName)) return;

    final p = await SharedPreferences.getInstance();
    final value = presets.remove(oldName)!;
    presets[newName] = value;
    await p.setString(storageKey, jsonEncode(presets));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$oldName」を「$newName」に変更しました')),
      );
    }
  }

  Future<void> _deletePreset(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プリセットを削除しますか？'),
        content: Text('「$name」を削除します。元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok != true) return;

    final p = await SharedPreferences.getInstance();
    presets.remove(name);
    await p.setString(storageKey, jsonEncode(presets));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プリセット「$name」を削除しました')),
      );
    }
  }
}