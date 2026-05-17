import React from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  View,
  Pressable,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCollections } from '../../../src/hooks/useCollections';
import type { CustomHand } from '../../../src/types/hands';

function findHand(
  collections: ReturnType<typeof useCollections>['collections'],
  handId: string,
): { hand: CustomHand; collectionId: string } | null {
  for (const col of collections) {
    const hand = col.hands.find((h) => h.id === handId);
    if (hand) return { hand, collectionId: col.id };
  }
  return null;
}

export default function HandDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { collections } = useCollections();
  const found = findHand(collections, id);

  if (!found) {
    return (
      <View style={s.center}>
        <Text style={s.notFound}>Hand not found.</Text>
      </View>
    );
  }

  const { hand, collectionId } = found;
  const collection = collections.find((c) => c.id === collectionId);
  const isReadOnly = collection?.isReadOnly ?? false;

  return (
    <View style={s.root}>
      <ScrollView contentContainerStyle={s.content}>
        <View style={s.titleRow}>
          <Text style={s.handName}>{hand.name}</Text>
          {hand.isConcealed && <Text style={s.badge}>🔒 Concealed</Text>}
          {hand.pointValue != null && (
            <Text style={s.points}>{hand.pointValue} pts</Text>
          )}
        </View>

        <Text style={s.label} selectable>
          {hand.displayLabel}
        </Text>

        <Text style={s.sectionTitle}>Slots ({hand.slots.length})</Text>
        {hand.slots.map((slot, i) => (
          <View key={slot.id} style={s.slotRow}>
            <Text style={s.slotIndex}>{i + 1}</Text>
            <Text style={s.slotKind}>{slot.kind}</Text>
            <Text style={s.slotDesc}>
              {slot.concrete
                ? `${slot.concrete.suit}:${slot.concrete.value}`
                : slot.isJokerEligible
                ? 'Joker-eligible'
                : '—'}
            </Text>
          </View>
        ))}
      </ScrollView>

      {!isReadOnly && (
        <Pressable
          style={s.editBtn}
          onPress={() => router.push(`/hands/${hand.id}/edit`)}
          accessibilityRole="button"
          accessibilityLabel="Edit hand"
        >
          <Text style={s.editBtnText}>Edit Hand</Text>
        </Pressable>
      )}
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#0D0D1A' },
  notFound: { color: '#555', fontSize: 15 },
  content: { padding: 20, paddingBottom: 100 },
  titleRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 8 },
  handName: { color: '#DDD', fontSize: 18, fontWeight: '700' },
  badge: { color: '#7C9FF7', fontSize: 12, backgroundColor: '#161630', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 10 },
  points: { color: '#F7C94A', fontSize: 13, fontWeight: '700' },
  label: { color: '#777', fontSize: 13, fontFamily: 'monospace', marginBottom: 24 },
  sectionTitle: {
    color: '#666',
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 10,
  },
  slotRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#1C1C2E',
    gap: 12,
  },
  slotIndex: { color: '#444', fontSize: 12, width: 24, textAlign: 'right' },
  slotKind: { color: '#4A6CF7', fontSize: 11, fontWeight: '700', width: 80 },
  slotDesc: { color: '#999', fontSize: 13, flex: 1 },
  editBtn: {
    margin: 20,
    backgroundColor: '#4A6CF7',
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  editBtnText: { color: '#FFF', fontWeight: '700', fontSize: 15 },
});
