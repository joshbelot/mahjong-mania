import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useAppContext } from '../../src/context/AppProvider';
import type { GameMode } from '../../src/types/collections';

// ── Rules content ─────────────────────────────────────────────────────────────

const AMERICAN_RULES: Section[] = [
  {
    heading: 'Overview',
    body: 'American Mah Jongg follows the National Mah Jongg League (NMJL) style. A new card of valid winning hands is published each year. Players must complete a hand that exactly matches one of the hands on the current card.',
  },
  {
    heading: 'Tiles (152 total)',
    body: [
      '• Suits: Cracks, Dots, and Bams — values 1 through 9',
      '• Honors: 4 Winds (N, S, E, W) and 3 Dragons (Red, White, Green)',
      '• Jokers: 8 wild tiles that can substitute for any numbered tile',
      '• Flowers: also used as wild tiles in some variants',
    ].join('\n'),
  },
  {
    heading: 'The Charleston',
    body: 'Before play begins, each player passes unwanted tiles to neighbors in three rounds — right, across, then left. An optional courtesy pass may follow. This is a key part of the American game not found in Chinese Mah Jongg.',
  },
  {
    heading: 'Jokers',
    body: [
      '• Can substitute for any tile in a group of 3 or more (pungs, kongs, quints)',
      '• Cannot be used in pairs or single-tile positions',
      '• An opponent may swap a joker on the table for the tile it represents on their turn',
      '• You may not declare Mah Jongg if you need only a joker to complete your hand',
    ].join('\n'),
  },
  {
    heading: 'Winning',
    body: 'Call "Mah Jongg!" when you complete a hand from the card, either by drawing a tile or claiming a discard. The winning hand must match the card exactly — same tiles, same quantities, same suits as indicated. Each hand shows its point value on the card.',
  },
  {
    heading: 'Scoring',
    body: 'The point value is printed on the card next to each hand. A "C" prefix means the hand must be entirely concealed (no exposed melds from discards). Settling is based on who wins (single payment from each remaining player) at the printed value.',
  },
  {
    heading: 'How the App Helps',
    body: 'Add the hands from your current NMJL card to a Collection. The Tracker tab then shows how close your current tiles are to each hand, sorted by fewest tiles needed.',
  },
];

const CHINESE_RULES: Section[] = [
  {
    heading: 'Overview',
    body: 'Standard Chinese Mah Jongg (also called Classic or Traditional) is played with 144 tiles. Unlike American Mah Jongg, there is no fixed card — any valid hand wins. Scoring is based on the content of your winning hand.',
  },
  {
    heading: 'Tiles (144 total)',
    body: [
      '• Suits: Characters (Cracks), Circles (Dots), and Bamboo (Bams) — values 1 through 9',
      '• Honors: 4 Winds (N, S, E, W) and 3 Dragons (Red/Green/White)',
      '• Bonus: 4 Flowers and 4 Seasons (drawn immediately; draw a replacement)',
      '• No Jokers',
    ].join('\n'),
  },
  {
    heading: 'Winning Hand Structure',
    body: [
      'A standard winning hand consists of 4 melds + 1 pair:',
      '• Chow: 3 consecutive tiles of the same suit (e.g. 3-4-5 Bams)',
      '• Pung: 3 identical tiles (e.g. three East Winds)',
      '• Kong: 4 identical tiles (draw an extra tile when declaring)',
      '• Pair: 2 identical tiles (the "head" of the hand)',
    ].join('\n'),
  },
  {
    heading: 'Special Hands',
    body: [
      'Certain hands score extra or are required to be fully concealed:',
      '• All Pungs: no chows in the winning hand',
      '• Seven Pairs: seven pairs instead of 4 melds + 1 pair',
      '• All Honors: hand contains only winds and dragons',
      '• Thirteen Orphans: one each of 1-9 Man, 1-9 Bam, 1-9 Dot plus duplicate of any',
    ].join('\n'),
  },
  {
    heading: 'Scoring',
    body: 'Base scores are awarded for self-draw (tsumo), concealed hand, specific meld types (pung of honors, terminals), and winning conditions. Exact scoring varies by regional rules (Cantonese, Shanghainese, Hong Kong Old Style, etc.).',
  },
  {
    heading: 'Key Differences from American',
    body: [
      '• No Jokers — every tile in your hand is a specific real tile',
      '• No fixed card — flexible winning conditions',
      '• Chows are allowed (consecutive-suit melds)',
      '• No Charleston tile-passing ritual',
      '• Flowers/Seasons are bonus tiles, not part of your hand',
      '• Scoring rewards the structure of your melds, not a specific preset hand',
    ].join('\n'),
  },
];

interface Section {
  heading: string;
  body: string;
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function SettingsScreen() {
  const { state, setGameMode } = useAppContext();
  const mode = state.gameMode;
  const rules = mode === 'AMERICAN' ? AMERICAN_RULES : CHINESE_RULES;

  return (
    <ScrollView style={s.root} contentContainerStyle={s.content}>
      <Text style={s.screenTitle}>Settings</Text>

      {/* Game mode toggle */}
      <View style={s.card}>
        <Text style={s.cardTitle}>Game Mode</Text>
        <Text style={s.cardSubtitle}>
          Controls which rules are displayed below. Does not affect your collections.
        </Text>
        <View style={s.toggle}>
          {(['AMERICAN', 'CHINESE'] as GameMode[]).map((m) => (
            <Pressable
              key={m}
              style={[s.toggleBtn, mode === m && s.toggleBtnActive]}
              onPress={() => setGameMode(m)}
            >
              <Text style={[s.toggleLabel, mode === m && s.toggleLabelActive]}>
                {m === 'AMERICAN' ? '🀄 American' : '🎴 Chinese'}
              </Text>
            </Pressable>
          ))}
        </View>
      </View>

      {/* Rules */}
      <Text style={s.rulesHeader}>
        {mode === 'AMERICAN' ? 'American Mah Jongg Rules' : 'Chinese Mah Jongg Rules'}
      </Text>

      {rules.map((section) => (
        <View key={section.heading} style={s.section}>
          <Text style={s.sectionHeading}>{section.heading}</Text>
          <Text style={s.sectionBody}>{section.body}</Text>
        </View>
      ))}

      <View style={s.bottomPad} />
    </ScrollView>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────

const s = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#0D0D1A',
  },
  content: {
    padding: 20,
  },
  screenTitle: {
    fontSize: 28,
    fontWeight: '800',
    color: '#F0F0F0',
    marginBottom: 24,
  },
  card: {
    backgroundColor: '#141428',
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: '#222',
    marginBottom: 28,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#F0F0F0',
    marginBottom: 4,
  },
  cardSubtitle: {
    fontSize: 13,
    color: '#888',
    marginBottom: 16,
    lineHeight: 18,
  },
  toggle: {
    flexDirection: 'row',
    gap: 10,
  },
  toggleBtn: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
    backgroundColor: '#1E1E35',
    borderWidth: 1,
    borderColor: '#333',
  },
  toggleBtnActive: {
    backgroundColor: '#4A6CF7',
    borderColor: '#4A6CF7',
  },
  toggleLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
  },
  toggleLabelActive: {
    color: '#FFF',
  },
  rulesHeader: {
    fontSize: 18,
    fontWeight: '700',
    color: '#4A6CF7',
    marginBottom: 16,
  },
  section: {
    backgroundColor: '#141428',
    borderRadius: 12,
    padding: 14,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#1E1E35',
  },
  sectionHeading: {
    fontSize: 14,
    fontWeight: '700',
    color: '#F0F0F0',
    marginBottom: 8,
  },
  sectionBody: {
    fontSize: 13,
    color: '#AAA',
    lineHeight: 20,
  },
  bottomPad: {
    height: 40,
  },
});
