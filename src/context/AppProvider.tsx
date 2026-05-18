import React, { createContext, useContext, useEffect, useReducer, type ReactNode } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { appReducer, INITIAL_STATE, type AppState, type AppAction, type GameMode } from './AppContext';

const GAME_MODE_KEY = '@mahjong/gameMode';

interface AppContextValue {
  state: AppState;
  dispatch: React.Dispatch<AppAction>;
  setGameMode: (mode: GameMode) => Promise<void>;
}

const AppContext = createContext<AppContextValue | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(appReducer, INITIAL_STATE);

  useEffect(() => {
    AsyncStorage.getItem(GAME_MODE_KEY).then((stored) => {
      if (stored === 'AMERICAN' || stored === 'CHINESE') {
        dispatch({ type: 'SET_GAME_MODE', payload: stored });
      }
    });
  }, []);

  async function setGameMode(mode: GameMode): Promise<void> {
    dispatch({ type: 'SET_GAME_MODE', payload: mode });
    await AsyncStorage.setItem(GAME_MODE_KEY, mode);
  }

  return (
    <AppContext.Provider value={{ state, dispatch, setGameMode }}>
      {children}
    </AppContext.Provider>
  );
}

export function useAppContext(): AppContextValue {
  const ctx = useContext(AppContext);
  if (!ctx) {
    throw new Error('useAppContext must be used within <AppProvider>');
  }
  return ctx;
}
