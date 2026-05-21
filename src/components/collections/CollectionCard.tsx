import React from 'react';
import { Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import type { CardCollection } from '../../types/collections';

interface CollectionCardProps {
  collection: CardCollection;
  isActive: boolean;
  onPress: (id: string) => void;
  onEdit?: (id: string) => void;
  onDelete?: (id: string) => void;
}

export function CollectionCard({
  collection,
  isActive,
  onPress,
  onEdit,
  onDelete,
}: CollectionCardProps) {
  return (
    <Pressable
      onPress={() => onPress(collection.id)}
      style={[s.card, isActive && s.active]}
      accessibilityRole="button"
      accessibilityLabel={`Collection: ${collection.name}`}
      accessibilityState={{ selected: isActive }}
    >
      <View style={s.left}>
        <Text style={[s.name, isActive && s.nameActive]}>{collection.name}</Text>
        <Text style={s.meta}>
          {collection.hands.length} hand{collection.hands.length !== 1 ? 's' : ''}
          {collection.isReadOnly ? '  ·  Read-only' : ''}
          {collection.source === 'IMPORTED' ? '  ·  Imported' : ''}
        </Text>
        {collection.description ? (
          <Text style={s.desc} numberOfLines={1}>{collection.description}</Text>
        ) : null}
      </View>
      {!collection.isReadOnly && (
        <View style={s.actions}>
          {onEdit && (
            <Pressable onPress={() => onEdit(collection.id)} style={s.actionBtn} accessibilityLabel="Edit collection">
              <Text style={s.actionText}>Edit</Text>
            </Pressable>
          )}
          {onDelete && (
            <Pressable
              onPress={() =>
                Alert.alert(
                  'Delete Collection',
                  `Are you sure you want to delete "${collection.name}"? This cannot be undone.`,
                  [
                    { text: 'Cancel', style: 'cancel' },
                    { text: 'Delete', style: 'destructive', onPress: () => onDelete(collection.id) },
                  ],
                )
              }
              style={[s.actionBtn, s.deleteBtn]}
              accessibilityLabel="Delete collection"
            >
              <Text style={s.deleteText}>Delete</Text>
            </Pressable>
          )}
        </View>
      )}
    </Pressable>
  );
}

const s = StyleSheet.create({
  card: {
    backgroundColor: '#1C1C2E',
    borderRadius: 12,
    padding: 14,
    marginHorizontal: 12,
    marginVertical: 5,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: 'transparent',
  },
  active: {
    borderColor: '#4A6CF7',
    backgroundColor: '#161630',
  },
  left: {
    flex: 1,
  },
  name: {
    color: '#CCC',
    fontSize: 15,
    fontWeight: '700',
  },
  nameActive: {
    color: '#7C9FF7',
  },
  meta: {
    color: '#666',
    fontSize: 11,
    marginTop: 2,
  },
  desc: {
    color: '#555',
    fontSize: 11,
    marginTop: 3,
    fontStyle: 'italic',
  },
  actions: {
    flexDirection: 'row',
    gap: 8,
    marginLeft: 8,
  },
  actionBtn: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 6,
    backgroundColor: '#2A2A3E',
    borderWidth: 1,
    borderColor: '#444',
  },
  deleteBtn: {
    borderColor: '#8B2020',
    backgroundColor: '#1A0A0A',
  },
  actionText: {
    color: '#AAB',
    fontSize: 12,
    fontWeight: '600',
  },
  deleteText: {
    color: '#FF6B6B',
    fontSize: 12,
    fontWeight: '600',
  },
});
