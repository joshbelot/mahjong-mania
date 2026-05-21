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
import type { HandGroup } from '../../types/collections';
import {
  parseFullNotation,
  detectIsConsecutive,
  type GroupDef,
  type ColorLabel,
} from '../../utils/notationParser';
import { GroupChip } from './GroupChip';
import { GroupPicker } from './GroupPicker';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface NotationSaveData {
  name: string;
  displayLabel: string;
  slots: TileSlot[];
  groupDefs: GroupDef[];
  alternateSlots?: TileSlot[];
  alternateGroupDefs?: GroupDef[];
  constraintDescription?: string;
  isConcealed: boolean;
  pointValue?: number;
  tags: string[];
  groupId?: string;
  newGroupName?: string;
}

interface NotationHandEditorProps {
  onSave: (data: NotationSaveData) => void;
  onCancel: () => void;
  /** Pre-populate from existing hand in edit mode. */
  existingHand?: CustomHand;
  /** Groups already defined in this collection, for the group picker. */
  existingGroups?: HandGroup[];
  /** Pre-select this group id (edit mode). */
  initialGroupId?: string;
}

// ── Component ─────────────────────────────────────────────────────────────────

export function NotationHandEditor({
  onSave,
  onCancel,
  existingHand,
  existingGroups = [],
  initialGroupId,
}: NotationHandEditorProps) {
  // Primary notation — preload from existing hand in edit mode
  const [notationText, setNotationText] = useState(
    () => existingHand?.groupDefs?.map((g) => g.token).join(' ') ?? '',
  );
  const [groups, setGroups] = useState<GroupDef[]>(
    () => existingHand?.groupDefs ?? [],
  );

  // Alternate (-or-) notation — preload if the hand has alternates
  const [showAlt, setShowAlt] = useState(
    () => (existingHand?.alternateGroupDefs?.length ?? 0) > 0,
  );
  const [altNotationText, setAltNotationText] = useState(
    () => existingHand?.alternateGroupDefs?.map((g) => g.token).join(' ') ?? '',
  );
  const [altGroups, setAltGroups] = useState<GroupDef[]>(
    () => existingHand?.alternateGroupDefs ?? [],
  );

  // Group membership
  const [selectedGroupId, setSelectedGroupId] = useState<string | undefined>(
    initialGroupId ?? existingHand?.groupId,
  );
  const [newGroupName, setNewGroupName] = useState<string | undefined>();

  // Other fields
  const [constraintDescription, setConstraintDescription] = useState(
    existingHand?.constraintDescription ?? '',
  );
  const [name, setName] = useState(existingHand?.name ?? '');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [pointText, setPointText] = useState(
    existingHand?.pointValue != null ? String(existingHand.pointValue) : '',
  );
  const [isConcealed, setIsConcealed] = useState(existingHand?.isConcealed ?? false);

  // ── Notation input handlers ─────────────────────────────────────────────

  function buildGroups(text: string, prev: GroupDef[]): GroupDef[] {
    const tokens = text.trim().split(/\s+/).filter(Boolean);
    return tokens.map((token, i) => {
      if (prev[i]?.token === token) return prev[i];
      const reuse = prev.find((g) => g.token === token);
      if (reuse) return reuse;
      return {
        token,
        colorLabel: 'RED' as ColorLabel,
        isConsecRun: detectIsConsecutive(token),
        dragonType: 'RED' as const,
      };
    });
  }

  function handleNotationChange(text: string) {
    setNotationText(text);
    setGroups((prev) => buildGroups(text, prev));
  }

  function handleAltNotationChange(text: string) {
    setAltNotationText(text);
    setAltGroups((prev) => buildGroups(text, prev));
  }

  function handleGroupChange(index: number, updated: GroupDef) {
    setGroups((prev) => prev.map((g, i) => (i === index ? updated : g)));
  }

  function handleAltGroupChange(index: number, updated: GroupDef) {
    setAltGroups((prev) => prev.map((g, i) => (i === index ? updated : g)));
  }

  // ── Save ────────────────────────────────────────────────────────────────

  function handleSave() {
    const slots = parseFullNotation(groups);
    const autoLabel = groups.map((g) => g.token.toUpperCase()).join(' ');
    const pointValue = pointText.trim() ? parseInt(pointText.trim(), 10) : undefined;

    const alternateSlots =
      showAlt && altGroups.length > 0 ? parseFullNotation(altGroups) : undefined;
    const alternateGroupDefs =
      showAlt && altGroups.length > 0 ? altGroups : undefined;

    onSave({
      name: name.trim(),
      displayLabel: autoLabel,
      slots,
      groupDefs: groups,
      alternateSlots,
      alternateGroupDefs,
      constraintDescription: constraintDescription.trim() || undefined,
      isConcealed,
      pointValue: pointValue && !isNaN(pointValue) ? pointValue : undefined,
      tags: [],
      groupId: newGroupName ? undefined : selectedGroupId,
      newGroupName: newGroupName,
    });
  }

  const canSave = groups.length > 0;

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

        {/* ── 1. Group picker ──────────────────────────────────────── */}
        <Text style={s.sectionLabel}>Group</Text>
        <GroupPicker
          groups={existingGroups}
          selectedGroupId={newGroupName ? null : (selectedGroupId ?? null)}
          onSelect={(id) => {
            setSelectedGroupId(id ?? undefined);
            setNewGroupName(undefined);
          }}
          onCreateNew={(groupName) => {
            setNewGroupName(groupName);
            setSelectedGroupId(undefined);
          }}
        />

        <View style={s.divider} />

        {/* ── 2. Primary notation ──────────────────────────────────── */}
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

        {/* ── 3. Alternate (-or-) notation ─────────────────────────── */}
        {!showAlt ? (
          <Pressable style={s.altToggle} onPress={() => setShowAlt(true)}>
            <Text style={s.altToggleText}>+ Add alternate  <Text style={s.altOr}>-or-</Text>  pattern</Text>
          </Pressable>
        ) : (
          <View style={s.altSection}>
            <View style={s.altHeader}>
              <Text style={s.altLabel}>-or-  Alternate Pattern</Text>
              <Pressable onPress={() => { setShowAlt(false); setAltNotationText(''); setAltGroups([]); }}>
                <Text style={s.altRemove}>Remove</Text>
              </Pressable>
            </View>
            <TextInput
              style={s.notationInput}
              value={altNotationText}
              onChangeText={handleAltNotationChange}
              placeholder="e.g.  FF  33  4444  555  DD"
              placeholderTextColor="#444"
              autoCapitalize="characters"
              autoCorrect={false}
              returnKeyType="done"
            />
            {altGroups.length > 0 && (
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                style={s.chipsScroll}
                contentContainerStyle={s.chipsContent}
              >
                {altGroups.map((g, i) => (
                  <GroupChip
                    key={`alt-${i}-${g.token}`}
                    group={g}
                    groupIndex={i}
                    onChange={(updated) => handleAltGroupChange(i, updated)}
                  />
                ))}
              </ScrollView>
            )}
          </View>
        )}

        <View style={s.divider} />

        {/* ── 4. Constraint description ─────────────────────────────── */}
        <Text style={s.fieldLabel}>Constraint Description</Text>
        <TextInput
          style={[s.input, s.multilineInput]}
          value={constraintDescription}
          onChangeText={setConstraintDescription}
          placeholder="e.g. Any 2 Suits, These Nos. Only"
          placeholderTextColor="#444"
          multiline
          numberOfLines={2}
          textAlignVertical="top"
          returnKeyType="next"
        />

        {/* ── 5. Point value ───────────────────────────────────────── */}
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

        {/* ── 6. Concealed toggle ───────────────────────────────────── */}
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

        {/* ── 7. Advanced (collapsible): hand name ─────────────────── */}
        <Pressable style={s.advancedToggle} onPress={() => setShowAdvanced((v) => !v)}>
          <Text style={s.advancedToggleText}>
            {showAdvanced ? '▾' : '▸'}  Advanced
          </Text>
        </Pressable>
        {showAdvanced && (
          <View style={s.advancedSection}>
            <Text style={s.fieldLabel}>Hand Name <Text style={s.optional}>(optional)</Text></Text>
            <TextInput
              style={s.input}
              value={name}
              onChangeText={setName}
              placeholder="e.g. FF Pung Kong 2024"
              placeholderTextColor="#444"
              returnKeyType="done"
            />
          </View>
        )}

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
  optional: {
    color: '#555',
    fontWeight: '400',
  },
  groupPickerBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#141428',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 14,
  },
  groupPickerBtnText: {
    color: '#F0F0F0',
    fontSize: 15,
    flex: 1,
  },
  groupPickerArrow: {
    color: '#666',
    fontSize: 14,
    marginLeft: 8,
  },
  altToggle: {
    alignSelf: 'flex-start',
    marginBottom: 16,
  },
  altToggleText: {
    color: '#4A6CF7',
    fontSize: 14,
    fontWeight: '600',
  },
  altOr: {
    color: '#F7C94A',
    fontWeight: '700',
  },
  altSection: {
    borderLeftWidth: 2,
    borderLeftColor: '#F7C94A',
    paddingLeft: 12,
    marginBottom: 16,
  },
  altHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  altLabel: {
    color: '#F7C94A',
    fontSize: 14,
    fontWeight: '700',
  },
  altRemove: {
    color: '#E84545',
    fontSize: 13,
  },
  advancedToggle: {
    marginTop: 4,
    marginBottom: 8,
  },
  advancedToggleText: {
    color: '#666',
    fontSize: 13,
    fontWeight: '600',
  },
  advancedSection: {
    marginBottom: 12,
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
