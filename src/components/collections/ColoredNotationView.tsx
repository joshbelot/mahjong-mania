import React from 'react';
import { Platform, StyleSheet, Text, View } from 'react-native';
import type { TextStyle } from 'react-native';
import type { GroupDef, ColorLabel } from '../../types/hands';

// ── Color map ─────────────────────────────────────────────────────────────────
// Maps the notation color labels to distinct display colors that mirror the card:
// RED and GREEN are the two primary suit-group colors on the official card;
// BLUE is a third option; GRAY means freely independent / no suit constraint.

const COLOR_MAP: Record<ColorLabel, string> = {
  RED: '#E74C3C',
  GREEN: '#27AE60',
  BLUE: '#4A6CF7',
  GRAY: '#888888',
};

interface ColoredNotationViewProps {
  /** Primary notation tokens with color annotations. */
  groupDefs: GroupDef[];
  /** Alternate notation tokens for -or- hands. */
  altGroupDefs?: GroupDef[];
  /** Fallback plain string shown if groupDefs is empty. */
  fallbackLabel?: string;
  style?: TextStyle;
}

export function ColoredNotationView({
  groupDefs,
  altGroupDefs,
  fallbackLabel,
  style,
}: ColoredNotationViewProps) {
  if (!groupDefs || groupDefs.length === 0) {
    return (
      <Text style={[s.base, style]} numberOfLines={2}>
        {fallbackLabel ?? ''}
      </Text>
    );
  }

  return (
    <Text style={[s.base, style]}>
      {groupDefs.map((g, i) => (
        <Text key={i} style={{ color: COLOR_MAP[g.colorLabel] }}>
          {g.token.toUpperCase()}
          {i < groupDefs.length - 1 ? ' ' : ''}
        </Text>
      ))}
      {altGroupDefs && altGroupDefs.length > 0 && (
        <>
          <Text style={s.orSeparator}> -or- </Text>
          {altGroupDefs.map((g, i) => (
            <Text key={`alt-${i}`} style={{ color: COLOR_MAP[g.colorLabel] }}>
              {g.token.toUpperCase()}
              {i < altGroupDefs.length - 1 ? ' ' : ''}
            </Text>
          ))}
        </>
      )}
    </Text>
  );
}

const s = StyleSheet.create({
  base: {
    fontSize: 14,
    fontWeight: '700',
    fontFamily: Platform.OS === 'ios' ? 'Courier New' : 'monospace',
    letterSpacing: 1,
  },
  orSeparator: {
    color: '#777',
    fontWeight: '400',
    letterSpacing: 0,
  },
});
