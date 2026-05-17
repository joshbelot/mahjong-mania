import React, { useEffect, useRef } from 'react';
import { StatusBar } from 'expo-status-bar';
import { Stack } from 'expo-router';
import { SQLiteProvider, type SQLiteDatabase } from 'expo-sqlite';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AppProvider } from '../src/context/AppProvider';
import { runMigrations } from '../src/db/migrations';
import { CollectionRepository } from '../src/db/repositories/CollectionRepository';
import { DEMO_COLLECTION } from '../src/constants/demo';

const DB_NAME = 'mahjong.db';
const DEMO_SEEDED_KEY = 'demo_seeded_v1';

async function initDatabase(db: SQLiteDatabase) {
  await runMigrations(db);
  // Seed demo collection once on first launch
  try {
    const flag = await AsyncStorage.getItem(DEMO_SEEDED_KEY);
    if (!flag) {
      const repo = CollectionRepository.create(db);
      await repo.save(DEMO_COLLECTION);
      await AsyncStorage.setItem(DEMO_SEEDED_KEY, '1');
    }
  } catch {
    // Non-fatal — demo seed failure should not block the app
  }
}

export default function RootLayout() {
  return (
    <SQLiteProvider databaseName={DB_NAME} onInit={initDatabase}>
      <AppProvider>
        <StatusBar style="light" />
        <Stack
          screenOptions={{
            headerStyle: { backgroundColor: '#0D0D1A' },
            headerTintColor: '#DDD',
            headerTitleStyle: { fontWeight: '700' },
            contentStyle: { backgroundColor: '#0D0D1A' },
          }}
        >
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen
            name="collections/new"
            options={{ title: 'New Collection', presentation: 'modal' }}
          />
          <Stack.Screen name="collections/[id]" options={{ title: 'Collection' }} />
          <Stack.Screen
            name="hands/new"
            options={{ title: 'New Hand', presentation: 'modal', headerShown: false }}
          />
          <Stack.Screen
            name="hands/[id]/edit"
            options={{ title: 'Edit Hand', presentation: 'modal', headerShown: false }}
          />
          <Stack.Screen name="hands/[id]/index" options={{ title: 'Hand Detail' }} />
          <Stack.Screen name="+not-found" options={{ title: 'Not Found' }} />
        </Stack>
      </AppProvider>
    </SQLiteProvider>
  );
}
