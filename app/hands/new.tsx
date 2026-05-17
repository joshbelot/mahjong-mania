import React from 'react';
import { Alert, StyleSheet, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCollections } from '../../src/hooks/useCollections';
import { HandEditor } from '../../src/components/collections/HandEditor';
import type { TileSlot } from '../../src/types/hands';

export default function NewHandScreen() {
  const router = useRouter();
  const { collectionId } = useLocalSearchParams<{ collectionId: string }>();
  const { collections, updateCollection } = useCollections();
  const collection = collections.find((c) => c.id === collectionId);

  if (!collection) {
    return null;
  }

  async function handleSave(data: {
    name: string;
    displayLabel: string;
    slots: TileSlot[];
    isConcealed: boolean;
    pointValue?: number;
  }) {
    const now = Date.now();
    const newHand = {
      id: `hand_${now}_${Math.random().toString(36).slice(2, 8)}`,
      collectionId: collection!.id,
      name: data.name,
      displayLabel: data.displayLabel,
      slots: data.slots,
      isConcealed: data.isConcealed,
      pointValue: data.pointValue,
      tags: [],
      createdAt: now,
      updatedAt: now,
    };
    const updated = {
      ...collection!,
      hands: [...collection!.hands, newHand],
      updatedAt: now,
    };
    await updateCollection(updated);
    router.replace(`/collections/${collection!.id}`);
  }

  return (
    <View style={s.root}>
      <HandEditor
        onSave={handleSave}
        onCancel={() => router.back()}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
});
