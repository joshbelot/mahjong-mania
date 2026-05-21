import React from 'react';
import { StyleSheet, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCollections } from '../../../src/hooks/useCollections';
import { useGroupRepository } from '../../../src/db/repositories/GroupRepository';
import { NotationHandEditor } from '../../../src/components/collections/NotationHandEditor';
import type { NotationSaveData } from '../../../src/components/collections/NotationHandEditor';
import type { CustomHand } from '../../../src/types/hands';

export default function EditHandScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { collections, updateCollection } = useCollections();
  const groupRepo = useGroupRepository();

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

    // Resolve groupId: create new group if needed
    let resolvedGroupId = data.groupId;
    const updatedGroups = [...collection!.groups];
    if (data.newGroupName) {
      const newGroup = {
        id: `group_${now}_${Math.random().toString(36).slice(2, 8)}`,
        collectionId: collection!.id,
        name: data.newGroupName,
        sortOrder: collection!.groups.length,
        createdAt: now,
        updatedAt: now,
      };
      await groupRepo.save(newGroup);
      updatedGroups.push(newGroup);
      resolvedGroupId = newGroup.id;
    }

    const updatedHand: CustomHand = {
      ...hand!,
      name: data.name,
      displayLabel: data.displayLabel,
      slots: data.slots,
      groupDefs: data.groupDefs,
      alternateSlots: data.alternateSlots,
      alternateGroupDefs: data.alternateGroupDefs,
      constraintDescription: data.constraintDescription,
      isConcealed: data.isConcealed,
      pointValue: data.pointValue,
      tags: data.tags.length > 0 ? data.tags : hand!.tags,
      groupId: resolvedGroupId,
      updatedAt: now,
    };
    const updatedCollection = {
      ...collection!,
      groups: updatedGroups,
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
        existingGroups={collection.groups}
        initialGroupId={hand.groupId}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
});
