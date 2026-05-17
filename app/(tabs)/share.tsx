import React, { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { useCollections } from '../../src/hooks/useCollections';
import { ShareImportModal } from '../../src/components/shared/ShareImportModal';
import type { CardCollection } from '../../src/types/collections';

export default function ShareScreen() {
  const { collections, createCollection } = useCollections();

  async function handleImport(collection: CardCollection) {
    await createCollection(collection);
  }

  return (
    <View style={s.root}>
      <ShareImportModal
        visible
        collections={collections}
        onImport={handleImport}
        onClose={() => { /* intentionally no-op: tab IS the modal */ }}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
});
