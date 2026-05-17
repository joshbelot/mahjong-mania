import React from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCollections } from '../../src/hooks/useCollections';
import type { CustomHand } from '../../src/types/hands';

export default function CollectionDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { collections, isLoading } = useCollections();
  const collection = collections.find((c) => c.id === id);

  if (isLoading) {
    return (
      <View style={s.center}>
        <ActivityIndicator color="#4A6CF7" />
      </View>
    );
  }

  if (!collection) {
    return (
      <View style={s.center}>
        <Text style={s.notFound}>Collection not found.</Text>
      </View>
    );
  }

  function handleHandPress(hand: CustomHand) {
    router.push(`/hands/${hand.id}`);
  }

  return (
    <View style={s.root}>
      <View style={s.header}>
        <View>
          <Text style={s.collectionName}>{collection.name}</Text>
          {collection.description ? (
            <Text style={s.collectionDesc}>{collection.description}</Text>
          ) : null}
        </View>
        <Text style={s.handCount}>{collection.hands.length} hands</Text>
      </View>

      <FlatList
        data={collection.hands}
        keyExtractor={(h) => h.id}
        contentContainerStyle={s.list}
        renderItem={({ item }) => (
          <Pressable
            style={s.handRow}
            onPress={() => handleHandPress(item)}
            accessibilityRole="button"
          >
            <View style={s.handInfo}>
              <Text style={s.handName}>{item.name}</Text>
              <Text style={s.handLabel} numberOfLines={1}>
                {item.displayLabel}
              </Text>
            </View>
            <View style={s.handMeta}>
              {item.pointValue != null && (
                <Text style={s.handPoints}>{item.pointValue} pts</Text>
              )}
              {item.isConcealed && <Text style={s.handConcealed}>🔒</Text>}
              <Text style={s.handArrow}>›</Text>
            </View>
          </Pressable>
        )}
        ListEmptyComponent={
          <View style={s.empty}>
            <Text style={s.emptyText}>No hands yet.</Text>
            <Text style={s.emptyHint}>Tap + to add one.</Text>
          </View>
        }
      />

      {!collection.isReadOnly && (
        <Pressable
          style={s.fab}
          onPress={() => router.push(`/hands/new?collectionId=${collection.id}`)}
          accessibilityRole="button"
          accessibilityLabel="Add new hand"
        >
          <Text style={s.fabText}>+</Text>
        </Pressable>
      )}
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#0D0D1A' },
  notFound: { color: '#555', fontSize: 15 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  collectionName: { color: '#DDD', fontSize: 18, fontWeight: '700', marginBottom: 2 },
  collectionDesc: { color: '#666', fontSize: 13 },
  handCount: { color: '#4A6CF7', fontSize: 13, fontWeight: '700', marginTop: 4 },
  list: { padding: 16, paddingBottom: 100 },
  handRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#1C1C2E',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#2A2A3A',
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 8,
  },
  handInfo: { flex: 1, marginRight: 8 },
  handName: { color: '#DDD', fontSize: 14, fontWeight: '600', marginBottom: 2 },
  handLabel: { color: '#555', fontSize: 12, fontFamily: 'monospace' },
  handMeta: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  handPoints: { color: '#F7C94A', fontSize: 12, fontWeight: '700' },
  handConcealed: { fontSize: 12 },
  handArrow: { color: '#555', fontSize: 18 },
  empty: { alignItems: 'center', marginTop: 60 },
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
