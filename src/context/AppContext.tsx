import type { CardCollection, GameMode } from '../types/collections';
import type { ConcreteTile } from '../types/tiles';
import type { ViewMode } from '../types/scoring';

export type { GameMode };

// ── State shape ───────────────────────────────────────────────────────────────

export interface AppState {
  /** All loaded collections (excludes demo unless no user collections exist). */
  collections: CardCollection[];
  /** The collection currently selected for scoring. */
  activeCollectionId: string | null;
  /** The 0–14 tiles currently placed in the tracker. */
  activeTiles: ConcreteTile[];
  viewMode: ViewMode;
  /** True while collections are being loaded from SQLite. */
  isLoading: boolean;
  /** Whether to use American (NMJL-style) or Chinese rules. */
  gameMode: GameMode;
}

export const INITIAL_STATE: AppState = {
  collections: [],
  activeCollectionId: null,
  activeTiles: [],
  viewMode: 'ASSIST',
  isLoading: true,
  gameMode: 'AMERICAN',
};

// ── Action union ──────────────────────────────────────────────────────────────

export type AppAction =
  | { type: 'SET_COLLECTIONS'; payload: CardCollection[] }
  | { type: 'SET_ACTIVE_COLLECTION'; payload: string | null }
  | { type: 'ADD_TILE'; payload: ConcreteTile }
  | { type: 'REMOVE_TILE'; payload: number } // index
  | { type: 'RESET_TILES' }
  | { type: 'SET_VIEW_MODE'; payload: ViewMode }
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'ADD_COLLECTION'; payload: CardCollection }
  | { type: 'UPDATE_COLLECTION'; payload: CardCollection }
  | { type: 'DELETE_COLLECTION'; payload: string } // id
  | { type: 'SET_GAME_MODE'; payload: GameMode };

// ── Reducer ───────────────────────────────────────────────────────────────────

export const MAX_ACTIVE_TILES = 14;

export function appReducer(state: AppState, action: AppAction): AppState {
  switch (action.type) {
    case 'SET_COLLECTIONS':
      return { ...state, collections: action.payload };

    case 'SET_ACTIVE_COLLECTION':
      return { ...state, activeCollectionId: action.payload };

    case 'ADD_TILE':
      if (state.activeTiles.length >= MAX_ACTIVE_TILES) return state;
      return { ...state, activeTiles: [...state.activeTiles, action.payload] };

    case 'REMOVE_TILE': {
      const next = [...state.activeTiles];
      next.splice(action.payload, 1);
      return { ...state, activeTiles: next };
    }

    case 'RESET_TILES':
      return { ...state, activeTiles: [] };

    case 'SET_VIEW_MODE':
      return { ...state, viewMode: action.payload };

    case 'SET_LOADING':
      return { ...state, isLoading: action.payload };

    case 'ADD_COLLECTION':
      return { ...state, collections: [...state.collections, action.payload] };

    case 'UPDATE_COLLECTION':
      return {
        ...state,
        collections: state.collections.map((c) =>
          c.id === action.payload.id ? action.payload : c,
        ),
      };

    case 'DELETE_COLLECTION': {
      const remaining = state.collections.filter((c) => c.id !== action.payload);
      const nextActiveId =
        state.activeCollectionId === action.payload
          ? (remaining[0]?.id ?? null)
          : state.activeCollectionId;
      return { ...state, collections: remaining, activeCollectionId: nextActiveId };
    }

    case 'SET_GAME_MODE':
      return { ...state, gameMode: action.payload };

    default:
      return state;
  }
}
