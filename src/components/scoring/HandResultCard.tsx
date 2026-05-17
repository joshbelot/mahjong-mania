import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { HandScoringResult, ProximityTier } from '../../types/scoring';
import { TILE_SHORT_LABEL } from '../../constants/tiles';
import { tileKey } from '../../utils/tileUtils';

const TIER_COLORS: Record<ProximityTier, { border: string; badge: string; badgeText: string }> = {
  COMPLETE:  { border: '#FFD700', badge: '#FFD700', badgeText: '#1A1A00' },
  ONE_AWAY:  { border: '#43A047', badge: '#43A047', badgeText: '#FFF' },
  CLOSE:     { border: '#FFA726', badge: '#FFA726', badgeText: '#FFF' },
  FAR:       { border: '#555',    badge: '#333',    badgeText: '#AAA' },
};

interface HandResultCardProps {
  result: HandScoringResult;
  handName: string;
  handDisplayLabel: string;
}

export function HandResultCard({ result, handName, handDisplayLabel }: HandResultCardProps) {
  const colors = TIER_COLORS[result.proximityTier];

  return (
    <View style={[s.card, { borderLeftColor: colors.border }]}>
      <View style={s.header}>
        <View style={s.titleBlock}>
          <Text style={s.displayLabel}>{handDisplayLabel}</Text>
          <Text style={s.name}>{handName}</Text>
        </View>
        <View style={[s.badge, { backgroundColor: colors.badge }]}>
          <Text style={[s.badgeText, { color: colors.badgeText }]}>
            {result.isComplete ? '✓' : `-${result.distanceScore}`}
          </Text>
        </View>
      </View>

      {result.tilesNeeded.length > 0 && (
        <View style={s.neededRow}>
          <Text style={s.neededLabel}>Need: </Text>
          {result.tilesNeeded.map((t, i) => (
            <View key={i} style={s.neededChip}>
              <Text style={s.neededChipText}>{TILE_SHORT_LABEL[tileKey(t)] ?? tileKey(t)}</Text>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

const s = StyleSheet.create({
  card: {
    backgroundColor: '#1C1C2E',
    borderRadius: 10,
    borderLeftWidth: 4,
    marginHorizontal: 8,
    marginVertical: 4,
    padding: 12,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  titleBlock: {
    flex: 1,
    marginRight: 8,
  },
  displayLabel: {
    color: '#E0E0FF',
    fontSize: 15,
    fontWeight: '700',
    fontFamily: 'monospace',
    letterSpacing: 1.2,
  },
  name: {
    color: '#888',
    fontSize: 11,
    marginTop: 2,
  },
  badge: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: {
    fontWeight: '800',
    fontSize: 13,
  },
  neededRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    alignItems: 'center',
    marginTop: 8,
  },
  neededLabel: {
    color: '#777',
    fontSize: 11,
    marginRight: 4,
  },
  neededChip: {
    backgroundColor: '#2C2C3E',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginRight: 4,
    marginBottom: 2,
    borderWidth: 1,
    borderColor: '#444',
  },
  neededChipText: {
    color: '#BBC',
    fontSize: 10,
    fontWeight: '600',
  },
});
