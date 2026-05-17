import React from 'react';
import { View, StyleSheet } from 'react-native';
import QRCode from 'react-native-qrcode-svg';

interface QRCodeViewProps {
  value: string;
  size?: number;
}

export function QRCodeView({ value, size = 220 }: QRCodeViewProps) {
  return (
    <View style={s.container}>
      <QRCode
        value={value || ' '}
        size={size}
        backgroundColor="#FFFFFF"
        color="#000000"
      />
    </View>
  );
}

const s = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: 12,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    alignSelf: 'center',
  },
});
