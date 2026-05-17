import React from 'react';
import { Tabs } from 'expo-router';
import { StyleSheet, Text } from 'react-native';

function TabIcon({ symbol, focused }: { symbol: string; focused: boolean }) {
  return (
    <Text style={[styles.icon, focused && styles.iconFocused]}>{symbol}</Text>
  );
}

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerStyle: { backgroundColor: '#0D0D1A' },
        headerTintColor: '#DDD',
        headerTitleStyle: { fontWeight: '700' },
        tabBarStyle: styles.tabBar,
        tabBarActiveTintColor: '#4A6CF7',
        tabBarInactiveTintColor: '#555',
        tabBarLabelStyle: styles.tabLabel,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Tracker',
          tabBarLabel: 'Tracker',
          tabBarIcon: ({ focused }) => <TabIcon symbol="🀄" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="collections"
        options={{
          title: 'Collections',
          tabBarLabel: 'Collections',
          tabBarIcon: ({ focused }) => <TabIcon symbol="📚" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="share"
        options={{
          title: 'Share',
          tabBarLabel: 'Share',
          tabBarIcon: ({ focused }) => <TabIcon symbol="↕" focused={focused} />,
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    backgroundColor: '#0D0D1A',
    borderTopColor: '#222',
    borderTopWidth: 1,
    height: 80,
    paddingBottom: 16,
  },
  tabLabel: { fontSize: 10, fontWeight: '600' },
  icon: { fontSize: 20, opacity: 0.5 },
  iconFocused: { opacity: 1 },
});
