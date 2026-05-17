import React from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useCollections } from '../../src/hooks/useCollections';
import { CollectionCard } from '../../src/components/collections/CollectionCard';
import type { CardCollection } from '../../src/types/collections';

export default function CollectionsScreen() {
  const router = useRouter();
  const {
    collections,
    isLoading,
    activeCollectionId,
    setActiveCollection,
    deleteCollection,
  } = useCollections();

  function handleEdit(collection: CardCollection) {
    router.push(`/collections/${collection.id}`);
  }

  function handleDelete(collection: CardCollection) {
    deleteCollection(collection.id);
  }

  function handleSelect(collection: CardCollection) {
    setActiveCollection(collection.id);
  }

  if (isLoading) {
    return (
      <View style={s.center}>
        <ActivityIndicator color="#4A6CF7" />
      </View>
    );
  }

  return (
    <View style={s.root}>
      <FlatList
        data={collections}
        keyExtractor={(c) => c.id}
        contentContainerStyle={s.list}
        renderItem={({ item }) => (
          <CollectionCard
            collection={item}
            isActive={item.id === activeCollectionId}
            onPress={(id) => handleSelect(collections.find((c) => c.id === id)!)}
            onEdit={(id) => handleEdit(collections.find((c) => c.id === id)!)}
            onDelete={(id) => handleDelete(collections.find((c) => c.id === id)!)}
          />
        )}
        ListEmptyComponent={
          <View style={s.empty}>
            <Text style={s.emptyText}>No collections yet.</Text>
            <Text style={s.emptyHint}>Tap + to create one.</Text>
          </View>
        }
      />

      {/* FAB */}
      <Pressable
        style={s.fab}
        onPress={() => router.push('/collections/new')}
        accessibilityRole="button"
        accessibilityLabel="Create new collection"
      >
        <Text style={s.fabText}>+</Text>
      </Pressable>
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
  list: { padding: 16, paddingBottom: 100 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#0D0D1A' },
  empty: { alignItems: 'center', marginTop: 80 },
  emptyText: { color: '#555', fontSize: 16, marginBottom: 4 },
  emptyHint: { color: '#3A3A4A', fontSize: 13 },
  fab: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#4A6CF7',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 6,
    shadowColor: '#4A6CF7',
    shadowOpacity: 0.5,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
  },
  fabText: { color: '#FFF', fontSize: 28, fontWeight: '300', marginTop: -2 },
});
