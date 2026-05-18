import React, { useState, useCallback } from 'react';
import { StyleSheet, View } from 'react-native';
import { useRouter } from 'expo-router';
import { useFocusEffect } from 'expo-router';
import { useCollections } from '../../src/hooks/useCollections';
import { ShareImportModal } from '../../src/components/shared/ShareImportModal';
import type { CardCollection } from '../../src/types/collections';

export default function ShareScreen() {
  const router = useRouter();
  const { collections, createCollection } = useCollections();
  const [visible, setVisible] = useState(true);

  // Re-show the modal whenever this tab comes back into focus
  useFocusEffect(
    useCallback(() => {
      setVisible(true);
    }, []),
  );

  async function handleImport(collection: CardCollection) {
    await createCollection(collection);
  }

  function handleClose() {
    setVisible(false);
    router.navigate('/(tabs)/collections');
  }

  return (
    <View style={s.root}>
      <ShareImportModal
        visible={visible}
        collections={collections}
        onImport={handleImport}
        onClose={handleClose}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
});
