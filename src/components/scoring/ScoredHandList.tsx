import React from 'react';
import { FlatList, StyleSheet, Text, View } from 'react-native';
import type { HandScoringResult } from '../../types/scoring';
import type { CardCollection } from '../../types/collections';
import { HandResultCard } from './HandResultCard';

interface ScoredHandListProps {
  results: HandScoringResult[];
  collection: CardCollection | null;
}

export function ScoredHandList({ results, collection }: ScoredHandListProps) {
  if (!collection) {
    return (
      <View style={s.empty}>
        <Text style={s.emptyText}>No collection selected.{'\n'}Create or import one in Collections.</Text>
      </View>
    );
  }

  if (results.length === 0) {
    return (
      <View style={s.empty}>
        <Text style={s.emptyText}>No hands match in this mode.{'\n'}Try switching to Assist mode.</Text>
      </View>
    );
  }

  const handMap = new Map(collection.hands.map((h) => [h.id, h]));

  return (
    <FlatList
      data={results}
      keyExtractor={(r) => r.handId}
      renderItem={({ item }) => {
        const hand = handMap.get(item.handId);
        if (!hand) return null;
        return (
          <HandResultCard
            result={item}
            handName={hand.name}
            handDisplayLabel={hand.displayLabel}
          />
        );
      }}
      contentContainerStyle={s.list}
      showsVerticalScrollIndicator={false}
    />
  );
}

const s = StyleSheet.create({
  list: {
    paddingBottom: 16,
  },
  empty: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
  },
  emptyText: {
    color: '#666',
    textAlign: 'center',
    fontSize: 14,
    lineHeight: 22,
  },
});
