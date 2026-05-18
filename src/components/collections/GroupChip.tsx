import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { GroupDef, ColorLabel } from '../../utils/notationParser';
import { detectIsConsecutive } from '../../utils/notationParser';
import type { DragonValue } from '../../types/tiles';

// ── Config ────────────────────────────────────────────────────────────────────

const COLOR_OPTIONS: { label: ColorLabel; bg: string; border: string }[] = [
  { label: 'RED',   bg: '#E84545', border: '#E84545' },
  { label: 'GREEN', bg: '#2ECC71', border: '#2ECC71' },
  { label: 'BLUE',  bg: '#4A6CF7', border: '#4A6CF7' },
  { label: 'GRAY',  bg: '#666',    border: '#888' },
];

const DRAGON_OPTIONS: { value: DragonValue; label: string; color: string }[] = [
  { value: 'RED',   label: 'Red',   color: '#E84545' },
  { value: 'WHITE', label: 'White', color: '#DDD' },
  { value: 'GREEN', label: 'Green', color: '#2ECC71' },
];

// ── Token kind detection ──────────────────────────────────────────────────────

type TokenKind = 'number' | 'dragon' | 'wind' | 'joker' | 'mixed';

function getTokenKind(token: string): TokenKind {
  const u = token.toUpperCase();
  const hasDigits   = /[1-9]/.test(u);
  const hasDragons  = /D/.test(u);
  const hasWinds    = /[NESW]/.test(u);
  const hasJokers   = /[JF]/.test(u);
  if (hasDigits  && !hasDragons && !hasWinds && !hasJokers) return 'number';
  if (hasDragons && !hasDigits  && !hasWinds && !hasJokers) return 'dragon';
  if (hasWinds   && !hasDigits  && !hasDragons && !hasJokers) return 'wind';
  if (hasJokers  && !hasDigits  && !hasDragons && !hasWinds) return 'joker';
  return 'mixed';
}

// ── Component ─────────────────────────────────────────────────────────────────

interface GroupChipProps {
  group: GroupDef;
  groupIndex: number;
  onChange: (updated: GroupDef) => void;
}

export function GroupChip({ group, onChange }: GroupChipProps) {
  const kind = getTokenKind(group.token);
  const isConsec = detectIsConsecutive(group.token);
  const showColorSwatches = kind === 'number' || kind === 'mixed';
  const showConsecToggle  = kind === 'number' && isConsec;
  const showDragonPicker  = kind === 'dragon';
  const kindLabel =
    kind === 'wind'  ? 'Winds' :
    kind === 'joker' ? 'Joker/Flower' : null;

  const activeBorder =
    COLOR_OPTIONS.find((c) => c.label === group.colorLabel)?.border ?? '#4A6CF7';

  return (
    <View style={[s.chip, showColorSwatches && { borderColor: activeBorder }]}>
      {/* Token label */}
      <Text style={s.tokenText}>{group.token.toUpperCase()}</Text>

      {/* Color swatches */}
      {showColorSwatches && (
        <View style={s.swatchRow}>
          {COLOR_OPTIONS.map((opt) => (
            <Pressable
              key={opt.label}
              style={[
                s.swatch,
                { backgroundColor: opt.bg },
                group.colorLabel === opt.label && s.swatchSelected,
              ]}
              onPress={() => onChange({ ...group, colorLabel: opt.label })}
              accessibilityLabel={opt.label}
            />
          ))}
        </View>
      )}

      {/* Any-run / Fixed toggle */}
      {showConsecToggle && (
        <Pressable
          style={[s.togglePill, group.isConsecRun && s.togglePillActive]}
          onPress={() => onChange({ ...group, isConsecRun: !group.isConsecRun })}
        >
          <Text style={[s.togglePillText, group.isConsecRun && s.togglePillTextActive]}>
            {group.isConsecRun ? 'Any Run ↕' : 'Fixed ⎟'}
          </Text>
        </Pressable>
      )}

      {/* Dragon type picker */}
      {showDragonPicker && (
        <View style={s.dragonRow}>
          {DRAGON_OPTIONS.map((opt) => (
            <Pressable
              key={opt.value}
              style={[
                s.dragonPill,
                group.dragonType === opt.value && { backgroundColor: opt.color + '33', borderColor: opt.color },
              ]}
              onPress={() => onChange({ ...group, dragonType: opt.value })}
            >
              <Text style={[s.dragonText, group.dragonType === opt.value && { color: opt.color }]}>
                {opt.label}
              </Text>
            </Pressable>
          ))}
        </View>
      )}

      {/* Wind / Joker informational label */}
      {kindLabel && (
        <Text style={s.kindLabel}>{kindLabel}</Text>
      )}
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────

const s = StyleSheet.create({
  chip: {
    backgroundColor: '#141428',
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#333',
    padding: 10,
    marginRight: 10,
    minWidth: 80,
    alignItems: 'center',
    gap: 8,
  },
  tokenText: {
    fontSize: 16,
    fontWeight: '800',
    color: '#F0F0F0',
    letterSpacing: 1,
  },
  swatchRow: {
    flexDirection: 'row',
    gap: 6,
  },
  swatch: {
    width: 18,
    height: 18,
    borderRadius: 9,
    opacity: 0.5,
  },
  swatchSelected: {
    opacity: 1,
    transform: [{ scale: 1.25 }],
  },
  togglePill: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 20,
    backgroundColor: '#1E1E35',
    borderWidth: 1,
    borderColor: '#444',
  },
  togglePillActive: {
    backgroundColor: '#4A6CF733',
    borderColor: '#4A6CF7',
  },
  togglePillText: {
    fontSize: 11,
    color: '#888',
    fontWeight: '600',
  },
  togglePillTextActive: {
    color: '#4A6CF7',
  },
  dragonRow: {
    flexDirection: 'row',
    gap: 4,
  },
  dragonPill: {
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: 8,
    backgroundColor: '#1E1E35',
    borderWidth: 1,
    borderColor: '#444',
  },
  dragonText: {
    fontSize: 11,
    color: '#888',
    fontWeight: '600',
  },
  kindLabel: {
    fontSize: 11,
    color: '#4A6CF7',
    fontWeight: '600',
  },
});
