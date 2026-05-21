import type { CardCollection } from '../types/collections';

/**
 * Demo collection — ships with the app to satisfy App Store Guideline 2.1
 * (Utility/Completeness). Contains 5 fictional, non-copyrighted tile sequences
 * so reviewers can exercise the full scoring engine without user-created data.
 *
 * This collection is READ-ONLY and cannot be mutated by the user.
 */
export const DEMO_COLLECTION: CardCollection = {
  id: 'demo-collection-v1',
  name: 'Demo Card',
  description: 'Built-in sample collection. Create your own to replace this.',
  source: 'DEMO',
  schemaVersion: 1,
  isReadOnly: true,
  createdAt: 0,
  updatedAt: 0,
  groups: [],
  hands: [
    // ── Hand 1: Triple Pung — three pungs of the same number in three suits ──
    {
      id: 'demo-hand-1',
      collectionId: 'demo-collection-v1',
      name: 'Triple Pung',
      displayLabel: 'PPP PPP PPP',
      isConcealed: false,
      tags: ['demo', 'pungs'],
      pointValue: 25,
      createdAt: 0,
      updatedAt: 0,
      slots: [
        // Three 3-Cracks
        { id: 'd1s1', kind: 'CONCRETE', concrete: { suit: 'CRACKS', value: 3 }, isJokerEligible: true, count: 3 },
        // Three 3-Dots
        { id: 'd1s2', kind: 'CONCRETE', concrete: { suit: 'DOTS', value: 3 }, isJokerEligible: true, count: 3 },
        // Three 3-Bams
        { id: 'd1s3', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 3 }, isJokerEligible: true, count: 3 },
        // Pair of East Winds
        { id: 'd1s4', kind: 'CONCRETE', concrete: { suit: 'WINDS', value: 'E' }, isJokerEligible: false, count: 2 },
      ],
    },

    // ── Hand 2: Wind Quartet — four different winds + a pung ─────────────────
    {
      id: 'demo-hand-2',
      collectionId: 'demo-collection-v1',
      name: 'Wind Quartet',
      displayLabel: 'E S W N + PPP',
      isConcealed: false,
      tags: ['demo', 'winds'],
      pointValue: 30,
      createdAt: 0,
      updatedAt: 0,
      slots: [
        { id: 'd2s1', kind: 'CONCRETE', concrete: { suit: 'WINDS', value: 'E' }, isJokerEligible: false, count: 1 },
        { id: 'd2s2', kind: 'CONCRETE', concrete: { suit: 'WINDS', value: 'S' }, isJokerEligible: false, count: 1 },
        { id: 'd2s3', kind: 'CONCRETE', concrete: { suit: 'WINDS', value: 'W' }, isJokerEligible: false, count: 1 },
        { id: 'd2s4', kind: 'CONCRETE', concrete: { suit: 'WINDS', value: 'N' }, isJokerEligible: false, count: 1 },
        // Pung of Green Dragons
        { id: 'd2s5', kind: 'CONCRETE', concrete: { suit: 'DRAGONS', value: 'GREEN' }, isJokerEligible: true, count: 3 },
        // Pair of Red Dragons
        { id: 'd2s6', kind: 'CONCRETE', concrete: { suit: 'DRAGONS', value: 'RED' }, isJokerEligible: false, count: 2 },
      ],
    },

    // ── Hand 3: Dragon Straight — all three dragons as singles + remaining ────
    {
      id: 'demo-hand-3',
      collectionId: 'demo-collection-v1',
      name: 'Dragon Straight',
      displayLabel: 'RD WD GD + KKKK PP',
      isConcealed: true,
      tags: ['demo', 'dragons', 'concealed'],
      pointValue: 35,
      createdAt: 0,
      updatedAt: 0,
      slots: [
        { id: 'd3s1', kind: 'CONCRETE', concrete: { suit: 'DRAGONS', value: 'RED' }, isJokerEligible: false, count: 1 },
        { id: 'd3s2', kind: 'CONCRETE', concrete: { suit: 'DRAGONS', value: 'WHITE' }, isJokerEligible: false, count: 1 },
        { id: 'd3s3', kind: 'CONCRETE', concrete: { suit: 'DRAGONS', value: 'GREEN' }, isJokerEligible: false, count: 1 },
        // Kong of 7-Dots
        { id: 'd3s4', kind: 'CONCRETE', concrete: { suit: 'DOTS', value: 7 }, isJokerEligible: true, count: 4 },
        // Pair of 7-Bams
        { id: 'd3s5', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 7 }, isJokerEligible: false, count: 2 },
        // Singles
        { id: 'd3s6', kind: 'CONCRETE', concrete: { suit: 'CRACKS', value: 7 }, isJokerEligible: false, count: 1 },
        { id: 'd3s7', kind: 'CONCRETE', concrete: { suit: 'CRACKS', value: 8 }, isJokerEligible: false, count: 1 },
        { id: 'd3s8', kind: 'CONCRETE', concrete: { suit: 'CRACKS', value: 9 }, isJokerEligible: false, count: 1 },
      ],
    },

    // ── Hand 4: Full Run — consecutive 1-9 in a single suit ──────────────────
    {
      id: 'demo-hand-4',
      collectionId: 'demo-collection-v1',
      name: 'Full Run',
      displayLabel: '1 2 3 4 5 6 7 8 9 + PPPPP',
      isConcealed: false,
      tags: ['demo', 'run'],
      pointValue: 50,
      createdAt: 0,
      updatedAt: 0,
      slots: [
        { id: 'd4s1', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 1 }, isJokerEligible: false, count: 1 },
        { id: 'd4s2', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 2 }, isJokerEligible: false, count: 1 },
        { id: 'd4s3', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 3 }, isJokerEligible: false, count: 1 },
        { id: 'd4s4', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 4 }, isJokerEligible: false, count: 1 },
        { id: 'd4s5', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 5 }, isJokerEligible: false, count: 1 },
        { id: 'd4s6', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 6 }, isJokerEligible: false, count: 1 },
        { id: 'd4s7', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 7 }, isJokerEligible: false, count: 1 },
        { id: 'd4s8', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 8 }, isJokerEligible: false, count: 1 },
        { id: 'd4s9', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 9 }, isJokerEligible: false, count: 1 },
        // Pair + pung filler to reach 14
        { id: 'd4s10', kind: 'CONCRETE', concrete: { suit: 'CRACKS', value: 1 }, isJokerEligible: true, count: 3 },
        { id: 'd4s11', kind: 'CONCRETE', concrete: { suit: 'DOTS', value: 1 }, isJokerEligible: false, count: 2 },
      ],
    },

    // ── Hand 5: Joker Heaven — heavy joker-eligible hand ─────────────────────
    {
      id: 'demo-hand-5',
      collectionId: 'demo-collection-v1',
      name: 'Joker Heaven',
      displayLabel: 'KKKK KKKK PP JJ (JKR eligible)',
      isConcealed: false,
      tags: ['demo', 'jokers', 'kongs'],
      pointValue: 75,
      createdAt: 0,
      updatedAt: 0,
      slots: [
        // Kong of 5-Cracks (joker-eligible)
        { id: 'd5s1', kind: 'CONCRETE', concrete: { suit: 'CRACKS', value: 5 }, isJokerEligible: true, count: 4 },
        // Kong of 5-Dots (joker-eligible)
        { id: 'd5s2', kind: 'CONCRETE', concrete: { suit: 'DOTS', value: 5 }, isJokerEligible: true, count: 4 },
        // Pair (NOT joker-eligible — pairs cannot use jokers in standard rules)
        { id: 'd5s3', kind: 'CONCRETE', concrete: { suit: 'BAMS', value: 5 }, isJokerEligible: false, count: 2 },
        // Two Jokers (literal)
        { id: 'd5s4', kind: 'JOKER', isJokerEligible: false, count: 2 },
        // Pair of North Winds
        { id: 'd5s5', kind: 'CONCRETE', concrete: { suit: 'WINDS', value: 'N' }, isJokerEligible: false, count: 2 },
      ],
    },
  ],
};
