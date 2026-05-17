import { useCallback } from 'react';
import type { ConcreteTile } from '../types/tiles';
import { useAppContext } from '../context/AppProvider';
import { MAX_ACTIVE_TILES } from '../context/AppContext';

export function useActiveTiles() {
  const { state, dispatch } = useAppContext();

  const addTile = useCallback(
    (tile: ConcreteTile) => {
      if (state.activeTiles.length < MAX_ACTIVE_TILES) {
        dispatch({ type: 'ADD_TILE', payload: tile });
      }
    },
    [state.activeTiles.length, dispatch],
  );

  const removeTile = useCallback(
    (index: number) => dispatch({ type: 'REMOVE_TILE', payload: index }),
    [dispatch],
  );

  const resetHand = useCallback(
    () => dispatch({ type: 'RESET_TILES' }),
    [dispatch],
  );

  return {
    activeTiles: state.activeTiles,
    addTile,
    removeTile,
    resetHand,
    isFull: state.activeTiles.length >= MAX_ACTIVE_TILES,
    count: state.activeTiles.length,
  };
}
