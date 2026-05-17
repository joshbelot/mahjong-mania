import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { ViewMode } from '../../types/scoring';

const MODES: { key: ViewMode; label: string; desc: string }[] = [
  { key: 'ASSIST', label: 'Assist', desc: 'Sort by proximity' },
  { key: 'FOCUS',  label: 'Focus',  desc: 'Hide impossible' },
  { key: 'SCOUT',  label: 'Scout',  desc: 'Defensive play' },
];

interface ViewModeToggleProps {
  current: ViewMode;
  onChange: (mode: ViewMode) => void;
}

export function ViewModeToggle({ current, onChange }: ViewModeToggleProps) {
  return (
    <View style={s.container}>
      {MODES.map((m) => {
        const active = m.key === current;
        return (
          <Pressable
            key={m.key}
            style={[s.btn, active && s.btnActive]}
            onPress={() => onChange(m.key)}
            accessibilityRole="button"
            accessibilityLabel={`${m.label} mode: ${m.desc}`}
            accessibilityState={{ selected: active }}
          >
            <Text style={[s.label, active && s.labelActive]}>{m.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const s = StyleSheet.create({
  container: {
    flexDirection: 'row',
    backgroundColor: '#1A1A2E',
    borderRadius: 10,
    padding: 3,
    margin: 8,
  },
  btn: {
    flex: 1,
    paddingVertical: 7,
    alignItems: 'center',
    borderRadius: 8,
  },
  btnActive: {
    backgroundColor: '#4A6CF7',
  },
  label: {
    color: '#888',
    fontSize: 12,
    fontWeight: '600',
  },
  labelActive: {
    color: '#FFF',
  },
});
