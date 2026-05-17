import { useMemo } from 'react';
import { useAppContext } from '../context/AppProvider';
import { calculateDistance, applyViewMode } from '../services/ScoringEngine';
import type { HandScoringResult } from '../types/scoring';

/**
 * Reactive scoring hook.
 * Re-runs the scoring engine whenever activeTiles, activeCollectionId, or
 * viewMode changes. The computation is memoised so it only fires on real changes.
 */
export function useScoringEngine(): HandScoringResult[] {
  const { state } = useAppContext();
  const { activeTiles, viewMode, activeCollectionId, collections } = state;

  return useMemo(() => {
    const collection = collections.find((c) => c.id === activeCollectionId);
    if (!collection) return [];

    const rawResults = collection.hands.map((hand) =>
      calculateDistance(activeTiles, hand),
    );

    return applyViewMode(rawResults, viewMode, activeTiles, collection.hands);
  }, [activeTiles, viewMode, activeCollectionId, collections]);
}
