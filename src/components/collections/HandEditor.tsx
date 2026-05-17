import React, { useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  Alert,
} from 'react-native';
import type { ConcreteTile } from '../../types/tiles';
import type { TileSlot } from '../../types/hands';
import { TileGrid } from '../tiles/TileGrid';
import { ActiveHandBar } from '../tiles/ActiveHandBar';
import { tileKey } from '../../utils/tileUtils';

interface HandEditorProps {
  /** Prepopulated values for edit mode */
  initialName?: string;
  initialLabel?: string;
  initialSlots?: TileSlot[];
  initialConcealed?: boolean;
  initialPoints?: number;
  onSave: (hand: {
    name: string;
    displayLabel: string;
    slots: TileSlot[];
    isConcealed: boolean;
    pointValue?: number;
  }) => void;
  onCancel: () => void;
}

/**
 * v1 Hand Editor — builds CONCRETE-kind TileSlots only.
 * The full TileSlot schema is stored, ready for v2 SUIT_FLEXIBLE / RUN_OFFSET entry.
 */
export function HandEditor({
  initialName = '',
  initialLabel = '',
  initialSlots = [],
  initialConcealed = false,
  initialPoints,
  onSave,
  onCancel,
}: HandEditorProps) {
  const [name, setName] = useState(initialName);
  const [displayLabel, setDisplayLabel] = useState(initialLabel);
  const [slots, setSlots] = useState<TileSlot[]>(initialSlots);
  const [isConcealed, setIsConcealed] = useState(initialConcealed);
  const [pointValue, setPointValue] = useState(initialPoints?.toString() ?? '');

  // Derive activeTiles from slots for the ActiveHandBar display
  const activeTiles: ConcreteTile[] = slots
    .filter((s) => s.kind === 'CONCRETE' && s.concrete)
    .map((s) => s.concrete!);

  function handleTilePress(tile: ConcreteTile) {
    if (slots.length >= 14) return;
    const newSlot: TileSlot = {
      id: `slot_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      kind: 'CONCRETE',
      concrete: tile,
      isJokerEligible: tile.suit !== 'JOKER' && tile.suit !== 'WINDS',
      count: 1,
    };
    setSlots((prev) => [...prev, newSlot]);
    // Auto-build displayLabel from tile labels
    const label = tileKey(tile);
    setDisplayLabel((prev) => (prev ? prev + ' ' + label : label));
  }

  function handleRemoveTile(index: number) {
    setSlots((prev) => {
      const next = [...prev];
      next.splice(index, 1);
      return next;
    });
  }

  function handleReset() {
    setSlots([]);
    setDisplayLabel('');
  }

  function handleSave() {
    if (!name.trim()) {
      Alert.alert('Name required', 'Please enter a name for this hand.');
      return;
    }
    if (slots.length === 0) {
      Alert.alert('No tiles', 'Please add at least one tile.');
      return;
    }
    onSave({
      name: name.trim(),
      displayLabel: displayLabel.trim() || name.trim(),
      slots,
      isConcealed,
      pointValue: pointValue ? parseInt(pointValue, 10) : undefined,
    });
  }

  return (
    <View style={s.container}>
      <ScrollView contentContainerStyle={s.form} keyboardShouldPersistTaps="handled">
        <Text style={s.sectionTitle}>Hand Name</Text>
        <TextInput
          style={s.input}
          value={name}
          onChangeText={setName}
          placeholder="e.g. Triple Pung"
          placeholderTextColor="#555"
          accessibilityLabel="Hand name input"
        />

        <Text style={s.sectionTitle}>Display Label</Text>
        <TextInput
          style={s.input}
          value={displayLabel}
          onChangeText={setDisplayLabel}
          placeholder="e.g. PPP PPP PPP DD"
          placeholderTextColor="#555"
          accessibilityLabel="Display label input"
        />

        <Text style={s.sectionTitle}>Point Value (optional)</Text>
        <TextInput
          style={s.input}
          value={pointValue}
          onChangeText={setPointValue}
          placeholder="e.g. 25"
          placeholderTextColor="#555"
          keyboardType="numeric"
          accessibilityLabel="Point value input"
        />

        <Pressable
          onPress={() => setIsConcealed((v) => !v)}
          style={[s.toggle, isConcealed && s.toggleOn]}
          accessibilityRole="switch"
          accessibilityState={{ checked: isConcealed }}
        >
          <Text style={[s.toggleText, isConcealed && s.toggleTextOn]}>
            {isConcealed ? '🔒 Concealed Hand' : '  Open Hand'}
          </Text>
        </Pressable>

        <Text style={[s.sectionTitle, { marginTop: 16 }]}>Tiles ({slots.length}/14)</Text>
        <Text style={s.hint}>Tap a tile to add it to this hand. Tap the slot bar to remove.</Text>
      </ScrollView>

      <ActiveHandBar
        tiles={activeTiles}
        onRemoveTile={handleRemoveTile}
        onReset={handleReset}
      />

      <View style={s.gridContainer}>
        <TileGrid
          onTilePress={handleTilePress}
          activeTiles={activeTiles}
          disabled={slots.length >= 14}
        />
      </View>

      <View style={s.footer}>
        <Pressable style={s.cancelBtn} onPress={onCancel} accessibilityRole="button">
          <Text style={s.cancelText}>Cancel</Text>
        </Pressable>
        <Pressable style={s.saveBtn} onPress={handleSave} accessibilityRole="button">
          <Text style={s.saveText}>Save Hand</Text>
        </Pressable>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0D0D1A' },
  form: { padding: 16, paddingBottom: 8 },
  sectionTitle: {
    color: '#888',
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 6,
  },
  input: {
    backgroundColor: '#1C1C2E',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#333',
    color: '#DDD',
    fontSize: 14,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 14,
  },
  toggle: {
    backgroundColor: '#1C1C2E',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#333',
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 4,
  },
  toggleOn: {
    borderColor: '#4A6CF7',
    backgroundColor: '#161630',
  },
  toggleText: { color: '#666', fontSize: 13, fontWeight: '600' },
  toggleTextOn: { color: '#7C9FF7' },
  hint: { color: '#555', fontSize: 11, marginBottom: 4, fontStyle: 'italic' },
  gridContainer: { flex: 1 },
  footer: {
    flexDirection: 'row',
    gap: 8,
    padding: 12,
    backgroundColor: '#0D0D1A',
    borderTopWidth: 1,
    borderTopColor: '#222',
  },
  cancelBtn: {
    flex: 1,
    padding: 12,
    borderRadius: 10,
    backgroundColor: '#1C1C2E',
    borderWidth: 1,
    borderColor: '#444',
    alignItems: 'center',
  },
  saveBtn: {
    flex: 2,
    padding: 12,
    borderRadius: 10,
    backgroundColor: '#4A6CF7',
    alignItems: 'center',
  },
  cancelText: { color: '#AAA', fontWeight: '700', fontSize: 14 },
  saveText: { color: '#FFF', fontWeight: '700', fontSize: 14 },
});
