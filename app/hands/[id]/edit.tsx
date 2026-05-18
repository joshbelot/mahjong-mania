import React from 'react';
import { StyleSheet, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCollections } from '../../../src/hooks/useCollections';
import { NotationHandEditor } from '../../../src/components/collections/NotationHandEditor';
import type { NotationSaveData } from '../../../src/components/collections/NotationHandEditor';
import type { CustomHand } from '../../../src/types/hands';

export default function EditHandScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { collections, updateCollection } = useCollections();

  // Find the hand and its parent collection
  let hand: CustomHand | null = null;
  let collectionId: string | null = null;
  for (const col of collections) {
    const found = col.hands.find((h) => h.id === id);
    if (found) {
      hand = found;
      collectionId = col.id;
      break;
    }
  }
  const collection = collections.find((c) => c.id === collectionId);

  if (!hand || !collection) return null;

  async function handleSave(data: NotationSaveData) {
    const now = Date.now();
    const updatedHand: CustomHand = {
      ...hand!,
      name: data.name,
      displayLabel: data.displayLabel,
      slots: data.slots,
      isConcealed: data.isConcealed,
      pointValue: data.pointValue,
      tags: data.tags.length > 0 ? data.tags : hand!.tags,
      updatedAt: now,
    };
    const updatedCollection = {
      ...collection!,
      hands: collection!.hands.map((h) => (h.id === hand!.id ? updatedHand : h)),
      updatedAt: now,
    };
    await updateCollection(updatedCollection);
    router.replace(`/hands/${hand!.id}`);
  }

  return (
    <View style={s.root}>
      <NotationHandEditor
        existingHand={hand}
        onSave={handleSave}
        onCancel={() => router.back()}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
});
