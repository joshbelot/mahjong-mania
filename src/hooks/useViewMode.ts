import { useCallback } from 'react';
import type { ViewMode } from '../types/scoring';
import { useAppContext } from '../context/AppProvider';

export function useViewMode() {
  const { state, dispatch } = useAppContext();

  const setViewMode = useCallback(
    (mode: ViewMode) => dispatch({ type: 'SET_VIEW_MODE', payload: mode }),
    [dispatch],
  );

  return { viewMode: state.viewMode, setViewMode };
}
