import React, { useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import type { TileSlot } from '../../types/hands';
import type { CustomHand } from '../../types/hands';
import {
  parseFullNotation,
  detectIsConsecutive,
  type GroupDef,
  type ColorLabel,
} from '../../utils/notationParser';
import { GroupChip } from './GroupChip';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface NotationSaveData {
  name: string;
  displayLabel: string;
  slots: TileSlot[];
  isConcealed: boolean;
  pointValue?: number;
  tags: string[];
}

interface NotationHandEditorProps {
  onSave: (data: NotationSaveData) => void;
  onCancel: () => void;
  /** When provided, shows the existing hand's displayLabel as a reference and pre-fills fields. */
  existingHand?: CustomHand;
}

// ── Component ─────────────────────────────────────────────────────────────────

export function NotationHandEditor({
  onSave,
  onCancel,
  existingHand,
}: NotationHandEditorProps) {
  const [notationText, setNotationText] = useState('');
  const [groups, setGroups] = useState<GroupDef[]>([]);
  const [name, setName]           = useState(existingHand?.name ?? '');
  const [category, setCategory]   = useState(existingHand?.tags[0] ?? '');
  const [description, setDescription] = useState('');
  const [pointText, setPointText] = useState(
    existingHand?.pointValue != null ? String(existingHand.pointValue) : '',
  );
  const [isConcealed, setIsConcealed] = useState(existingHand?.isConcealed ?? false);

  // ── Notation input handler ──────────────────────────────────────────────

  function handleNotationChange(text: string) {
    setNotationText(text);
    const tokens = text.trim().split(/\s+/).filter(Boolean);
    setGroups((prev) => {
      return tokens.map((token, i) => {
        // Keep existing group config if the token at this position hasn't changed
        if (prev[i]?.token === token) return prev[i];
        // Reuse config from another position with same token
        const reuse = prev.find((g) => g.token === token);
        if (reuse) return reuse;
        // Brand-new group
        return {
          token,
          colorLabel: 'RED' as ColorLabel,
          isConsecRun: detectIsConsecutive(token),
          dragonType: 'RED' as const,
        };
      });
    });
  }

  function handleGroupChange(index: number, updated: GroupDef) {
    setGroups((prev) => prev.map((g, i) => (i === index ? updated : g)));
  }

  // ── Save ────────────────────────────────────────────────────────────────

  function handleSave() {
    if (!name.trim()) return;
    const slots = parseFullNotation(groups);
    // Build a compact auto-label from the tokens (used as displayLabel fallback)
    const autoLabel = groups.map((g) => g.token.toUpperCase()).join(' ');
    const pointValue = pointText.trim() ? parseInt(pointText.trim(), 10) : undefined;
    onSave({
      name: name.trim(),
      displayLabel: description.trim() || autoLabel,
      slots,
      isConcealed,
      pointValue: pointValue && !isNaN(pointValue) ? pointValue : undefined,
      tags: category.trim() ? [category.trim()] : [],
    });
  }

  const canSave = name.trim().length > 0;

  // ── Render ──────────────────────────────────────────────────────────────

  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={80}
    >
      <ScrollView
        style={s.root}
        contentContainerStyle={s.content}
        keyboardShouldPersistTaps="handled"
      >
        {/* Reference label for edit mode */}
        {existingHand && existingHand.displayLabel ? (
          <View style={s.refBox}>
            <Text style={s.refTitle}>Previous notation (reference)</Text>
            <Text style={s.refText}>{existingHand.displayLabel}</Text>
          </View>
        ) : null}

        {/* ── Notation input ───────────────────────────────────────── */}
        <Text style={s.sectionLabel}>Notation</Text>
        <Text style={s.hint}>
          Enter space-separated groups.{'\n'}
          {'Numbers: 11 222 3333  ·  Dragon: DD DDD  ·  Winds: NEWS NSEW  ·  Joker/Flower: J FF'}
        </Text>
        <TextInput
          style={s.notationInput}
          value={notationText}
          onChangeText={handleNotationChange}
          placeholder="e.g.  FF  11  2222  333  DD  NEWS"
          placeholderTextColor="#444"
          autoCapitalize="characters"
          autoCorrect={false}
          returnKeyType="done"
        />

        {/* ── Group chips ──────────────────────────────────────────── */}
        {groups.length > 0 && (
          <>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              style={s.chipsScroll}
              contentContainerStyle={s.chipsContent}
            >
              {groups.map((g, i) => (
                <GroupChip
                  key={`${i}-${g.token}`}
                  group={g}
                  groupIndex={i}
                  onChange={(updated) => handleGroupChange(i, updated)}
                />
              ))}
            </ScrollView>
            <Text style={s.colorHint}>
              Same color = same suit · Different color = any suit · Gray = freely flexible
            </Text>
          </>
        )}

        <View style={s.divider} />

        {/* ── Form fields ──────────────────────────────────────────── */}
        <Text style={s.fieldLabel}>Category / Heading</Text>
        <TextInput
          style={s.input}
          value={category}
          onChangeText={setCategory}
          placeholder="e.g. QUINTS, CONSECUTIVE RUN, 13579"
          placeholderTextColor="#444"
          returnKeyType="next"
        />

        <Text style={s.fieldLabel}>Hand Name <Text style={s.required}>*</Text></Text>
        <TextInput
          style={s.input}
          value={name}
          onChangeText={setName}
          placeholder="e.g. FF Pung Kong 2024"
          placeholderTextColor="#444"
          returnKeyType="next"
        />

        <Text style={s.fieldLabel}>Description</Text>
        <TextInput
          style={[s.input, s.multilineInput]}
          value={description}
          onChangeText={setDescription}
          placeholder="e.g. Any 3 Suits, Any 3 Consec. Nos."
          placeholderTextColor="#444"
          multiline
          numberOfLines={2}
          textAlignVertical="top"
          returnKeyType="next"
        />

        <Text style={s.fieldLabel}>Point Value</Text>
        <TextInput
          style={s.input}
          value={pointText}
          onChangeText={setPointText}
          placeholder="e.g. 25"
          placeholderTextColor="#444"
          keyboardType="number-pad"
          returnKeyType="done"
        />

        <View style={s.concealedRow}>
          <View>
            <Text style={s.fieldLabel}>Concealed</Text>
            <Text style={s.concealedHint}>Hand must be fully concealed (no discards)</Text>
          </View>
          <Switch
            value={isConcealed}
            onValueChange={setIsConcealed}
            trackColor={{ false: '#333', true: '#4A6CF7' }}
            thumbColor={isConcealed ? '#fff' : '#888'}
          />
        </View>

        {/* ── Buttons ──────────────────────────────────────────────── */}
        <View style={s.buttonRow}>
          <Pressable style={[s.btn, s.cancelBtn]} onPress={onCancel}>
            <Text style={s.cancelText}>Cancel</Text>
          </Pressable>
          <Pressable
            style={[s.btn, s.saveBtn, !canSave && s.saveBtnDisabled]}
            onPress={handleSave}
            disabled={!canSave}
          >
            <Text style={s.saveText}>Save Hand</Text>
          </Pressable>
        </View>

        <View style={s.bottomPad} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────

const s = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#0D0D1A',
  },
  content: {
    padding: 20,
  },
  refBox: {
    backgroundColor: '#1A1A2E',
    borderRadius: 10,
    padding: 12,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: '#2A2A50',
  },
  refTitle: {
    fontSize: 11,
    color: '#666',
    fontWeight: '600',
    marginBottom: 4,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  refText: {
    fontSize: 14,
    color: '#AAA',
    fontFamily: Platform.OS === 'ios' ? 'Courier New' : 'monospace',
  },
  sectionLabel: {
    fontSize: 16,
    fontWeight: '700',
    color: '#F0F0F0',
    marginBottom: 6,
  },
  hint: {
    fontSize: 12,
    color: '#666',
    marginBottom: 10,
    lineHeight: 18,
  },
  notationInput: {
    backgroundColor: '#141428',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    color: '#F0F0F0',
    fontSize: 18,
    fontWeight: '700',
    letterSpacing: 2,
    padding: 14,
    marginBottom: 16,
    fontFamily: Platform.OS === 'ios' ? 'Courier New' : 'monospace',
  },
  chipsScroll: {
    marginBottom: 8,
  },
  chipsContent: {
    paddingRight: 20,
  },
  colorHint: {
    fontSize: 11,
    color: '#555',
    marginBottom: 16,
    lineHeight: 16,
  },
  divider: {
    height: 1,
    backgroundColor: '#1E1E35',
    marginVertical: 20,
  },
  fieldLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#AAA',
    marginBottom: 6,
    marginTop: 4,
  },
  required: {
    color: '#E84545',
  },
  input: {
    backgroundColor: '#141428',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    color: '#F0F0F0',
    fontSize: 15,
    padding: 12,
    marginBottom: 14,
  },
  multilineInput: {
    minHeight: 72,
    paddingTop: 12,
  },
  concealedRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#141428',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    padding: 12,
    marginBottom: 28,
  },
  concealedHint: {
    fontSize: 11,
    color: '#555',
    marginTop: 2,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
  },
  btn: {
    flex: 1,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  cancelBtn: {
    backgroundColor: '#1E1E35',
    borderWidth: 1,
    borderColor: '#333',
  },
  cancelText: {
    color: '#888',
    fontSize: 15,
    fontWeight: '600',
  },
  saveBtn: {
    backgroundColor: '#4A6CF7',
  },
  saveBtnDisabled: {
    opacity: 0.4,
  },
  saveText: {
    color: '#FFF',
    fontSize: 15,
    fontWeight: '700',
  },
  bottomPad: {
    height: 40,
  },
});
