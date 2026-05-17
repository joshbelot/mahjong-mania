import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Link } from 'expo-router';

export default function NotFoundScreen() {
  return (
    <View style={s.root}>
      <Text style={s.title}>Page Not Found</Text>
      <Text style={s.subtitle}>This route doesn't exist.</Text>
      <Link href="/" asChild>
        <Pressable style={s.btn} accessibilityRole="link">
          <Text style={s.btnText}>Go Home</Text>
        </Pressable>
      </Link>
    </View>
  );
}

const s = StyleSheet.create({
  root: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0D0D1A',
    padding: 24,
  },
  title: { color: '#DDD', fontSize: 22, fontWeight: '700', marginBottom: 8 },
  subtitle: { color: '#555', fontSize: 14, marginBottom: 32 },
  btn: { backgroundColor: '#4A6CF7', borderRadius: 10, paddingHorizontal: 24, paddingVertical: 12 },
  btnText: { color: '#FFF', fontWeight: '700', fontSize: 14 },
});
