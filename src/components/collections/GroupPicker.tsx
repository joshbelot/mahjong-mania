import React, { useState } from 'react';
import {
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import type { HandGroup } from '../../types/collections';

interface GroupPickerProps {
  groups: HandGroup[];
  selectedGroupId: string | null;
  onSelect: (groupId: string | null) => void;
  /** Called when user wants to create a new group with the given name. */
  onCreateNew: (name: string) => void;
}

const CREATE_NEW_ID = '__CREATE_NEW__';
const NONE_ID = '__NONE__';

export function GroupPicker({ groups, selectedGroupId, onSelect, onCreateNew }: GroupPickerProps) {
  const [modalVisible, setModalVisible] = useState(false);
  const [newGroupName, setNewGroupName] = useState('');
  const [showNewInput, setShowNewInput] = useState(false);

  const selectedGroup = groups.find((g) => g.id === selectedGroupId);
  const displayLabel = selectedGroup?.name ?? 'Select a group…';

  function handleSelect(id: string) {
    if (id === CREATE_NEW_ID) {
      setShowNewInput(true);
      return;
    }
    setModalVisible(false);
    setShowNewInput(false);
    onSelect(id === NONE_ID ? null : id);
  }

  function handleCreateNew() {
    const name = newGroupName.trim();
    if (!name) return;
    setModalVisible(false);
    setShowNewInput(false);
    setNewGroupName('');
    onCreateNew(name);
  }

  return (
    <View>
      <Pressable
        style={[s.trigger, selectedGroupId && s.triggerSelected]}
        onPress={() => setModalVisible(true)}
        accessibilityRole="button"
        accessibilityLabel="Select group"
      >
        <Text style={[s.triggerText, !selectedGroupId && s.triggerPlaceholder]}>
          {displayLabel}
        </Text>
        <Text style={s.chevron}>▾</Text>
      </Pressable>

      <Modal
        visible={modalVisible}
        transparent
        animationType="fade"
        onRequestClose={() => setModalVisible(false)}
      >
        <Pressable style={s.overlay} onPress={() => setModalVisible(false)}>
          <View style={s.sheet}>
            <Text style={s.sheetTitle}>Choose a Group</Text>
            <ScrollView style={s.optionList} bounces={false}>
              {groups.map((g) => (
                <Pressable
                  key={g.id}
                  style={[s.option, g.id === selectedGroupId && s.optionSelected]}
                  onPress={() => handleSelect(g.id)}
                >
                  <Text style={[s.optionText, g.id === selectedGroupId && s.optionTextSelected]}>
                    {g.name}
                  </Text>
                  {g.id === selectedGroupId && <Text style={s.checkmark}>✓</Text>}
                </Pressable>
              ))}
              {groups.length > 0 && <View style={s.optionDivider} />}
              {!showNewInput ? (
                <Pressable style={s.option} onPress={() => handleSelect(CREATE_NEW_ID)}>
                  <Text style={s.optionNew}>+ Create new group</Text>
                </Pressable>
              ) : (
                <View style={s.newGroupRow}>
                  <TextInput
                    style={s.newGroupInput}
                    value={newGroupName}
                    onChangeText={setNewGroupName}
                    placeholder="Group name (e.g. QUINTS)"
                    placeholderTextColor="#555"
                    autoFocus
                    autoCapitalize="characters"
                    returnKeyType="done"
                    onSubmitEditing={handleCreateNew}
                  />
                  <Pressable
                    style={[s.newGroupBtn, !newGroupName.trim() && s.newGroupBtnDisabled]}
                    onPress={handleCreateNew}
                    disabled={!newGroupName.trim()}
                  >
                    <Text style={s.newGroupBtnText}>Add</Text>
                  </Pressable>
                </View>
              )}
            </ScrollView>
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

const s = StyleSheet.create({
  trigger: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#141428',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    paddingHorizontal: 14,
    paddingVertical: 13,
    marginBottom: 14,
  },
  triggerSelected: {
    borderColor: '#4A6CF7',
  },
  triggerText: {
    color: '#F0F0F0',
    fontSize: 15,
    fontWeight: '600',
    flex: 1,
  },
  triggerPlaceholder: {
    color: '#555',
    fontWeight: '400',
  },
  chevron: {
    color: '#555',
    fontSize: 14,
    marginLeft: 8,
  },
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.65)',
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: '#1A1A2E',
    borderTopLeftRadius: 18,
    borderTopRightRadius: 18,
    paddingTop: 20,
    paddingBottom: Platform.OS === 'ios' ? 36 : 20,
    maxHeight: '70%',
  },
  sheetTitle: {
    color: '#DDD',
    fontSize: 14,
    fontWeight: '700',
    textAlign: 'center',
    marginBottom: 12,
    paddingHorizontal: 20,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  optionList: {
    flexGrow: 0,
  },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 15,
  },
  optionSelected: {
    backgroundColor: '#1E1E40',
  },
  optionText: {
    color: '#CCC',
    fontSize: 16,
    fontWeight: '600',
  },
  optionTextSelected: {
    color: '#4A6CF7',
  },
  checkmark: {
    color: '#4A6CF7',
    fontSize: 16,
  },
  optionDivider: {
    height: 1,
    backgroundColor: '#252540',
    marginHorizontal: 16,
    marginVertical: 4,
  },
  optionNew: {
    color: '#4A6CF7',
    fontSize: 15,
    fontWeight: '600',
  },
  newGroupRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    gap: 10,
  },
  newGroupInput: {
    flex: 1,
    backgroundColor: '#141428',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#4A6CF7',
    color: '#F0F0F0',
    fontSize: 15,
    fontWeight: '600',
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  newGroupBtn: {
    backgroundColor: '#4A6CF7',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  newGroupBtnDisabled: {
    opacity: 0.4,
  },
  newGroupBtnText: {
    color: '#FFF',
    fontSize: 14,
    fontWeight: '700',
  },
});
