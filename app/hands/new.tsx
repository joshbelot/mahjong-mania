import React from 'react';
import { StyleSheet, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCollections } from '../../src/hooks/useCollections';
import { useGroupRepository } from '../../src/db/repositories/GroupRepository';
import { NotationHandEditor } from '../../src/components/collections/NotationHandEditor';
import type { NotationSaveData } from '../../src/components/collections/NotationHandEditor';

export default function NewHandScreen() {
  const router = useRouter();
  const { collectionId } = useLocalSearchParams<{ collectionId: string }>();
  const { collections, updateCollection } = useCollections();
  const groupRepo = useGroupRepository();
  const collection = collections.find((c) => c.id === collectionId);

  if (!collection) {
    return null;
  }

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

    const newHand = {
      id: `hand_${now}_${Math.random().toString(36).slice(2, 8)}`,
      collectionId: collection!.id,
      name: data.name,
      displayLabel: data.displayLabel,
      slots: data.slots,
      groupDefs: data.groupDefs,
      alternateSlots: data.alternateSlots,
      alternateGroupDefs: data.alternateGroupDefs,
      constraintDescription: data.constraintDescription,
      isConcealed: data.isConcealed,
      pointValue: data.pointValue,
      tags: data.tags,
      groupId: resolvedGroupId,
      createdAt: now,
      updatedAt: now,
    };
    const updated = {
      ...collection!,
      groups: updatedGroups,
      hands: [...collection!.hands, newHand],
      updatedAt: now,
    };
    await updateCollection(updated);
    router.replace(`/collections/${collection!.id}`);
  }

  return (
    <View style={s.root}>
      <NotationHandEditor
        onSave={handleSave}
        onCancel={() => router.back()}
        existingGroups={collection.groups}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
});
