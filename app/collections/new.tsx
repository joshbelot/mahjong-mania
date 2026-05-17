import React, { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useCollections } from '../../src/hooks/useCollections';
import type { CardCollection } from '../../src/types/collections';

export default function NewCollectionScreen() {
  const router = useRouter();
  const { createCollection } = useCollections();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  async function handleSave() {
    if (!name.trim()) {
      Alert.alert('Name required', 'Please enter a collection name.');
      return;
    }
    setIsSaving(true);
    try {
      const now = Date.now();
      const collection: CardCollection = {
        id: `col_${now}_${Math.random().toString(36).slice(2, 8)}`,
        name: name.trim(),
        description: description.trim() || undefined,
        source: 'USER_CREATED',
        schemaVersion: 1,
        isReadOnly: false,
        hands: [],
        createdAt: now,
        updatedAt: now,
      };
      await createCollection(collection);
      router.replace(`/collections/${collection.id}`);
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <ScrollView style={s.root} contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
      <Text style={s.label}>Collection Name *</Text>
      <TextInput
        style={s.input}
        value={name}
        onChangeText={setName}
        placeholder="e.g. 2024 National Card"
        placeholderTextColor="#555"
        autoFocus
        accessibilityLabel="Collection name"
      />

      <Text style={s.label}>Description</Text>
      <TextInput
        style={[s.input, s.textArea]}
        value={description}
        onChangeText={setDescription}
        placeholder="Optional notes…"
        placeholderTextColor="#555"
        multiline
        accessibilityLabel="Collection description"
      />

      <Pressable
        style={[s.saveBtn, isSaving && s.saveBtnDisabled]}
        onPress={handleSave}
        disabled={isSaving}
        accessibilityRole="button"
      >
        {isSaving ? <ActivityIndicator color="#FFF" /> : <Text style={s.saveBtnText}>Create Collection</Text>}
      </Pressable>

      <Pressable style={s.cancelBtn} onPress={() => router.back()} accessibilityRole="button">
        <Text style={s.cancelText}>Cancel</Text>
      </Pressable>
    </ScrollView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
  content: { padding: 20 },
  label: {
    color: '#888',
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 8,
  },
  input: {
    backgroundColor: '#1C1C2E',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    color: '#DDD',
    fontSize: 15,
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 20,
  },
  textArea: { height: 100, textAlignVertical: 'top' },
  saveBtn: {
    backgroundColor: '#4A6CF7',
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
    marginBottom: 12,
  },
  saveBtnDisabled: { opacity: 0.6 },
  saveBtnText: { color: '#FFF', fontWeight: '700', fontSize: 15 },
  cancelBtn: {
    padding: 14,
    alignItems: 'center',
  },
  cancelText: { color: '#666', fontSize: 14 },
});
