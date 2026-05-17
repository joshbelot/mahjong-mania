import React, { useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Modal,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import type { CardCollection } from '../../types/collections';
import { SerializationService } from '../../services/SerializationService';
import { cardIngestionService } from '../../services/CardIngestionService';
import { QRCodeView } from './QRCodeView';

type Tab = 'export' | 'import';

interface ShareImportModalProps {
  visible: boolean;
  collections: CardCollection[];
  onImport: (collection: CardCollection) => void;
  onClose: () => void;
}

export function ShareImportModal({
  visible,
  collections,
  onImport,
  onClose,
}: ShareImportModalProps) {
  const [tab, setTab] = useState<Tab>('export');
  const [selectedCollectionId, setSelectedCollectionId] = useState<string | null>(
    collections[0]?.id ?? null,
  );
  const [shareString, setShareString] = useState<string>('');
  const [importText, setImportText] = useState<string>('');
  const [isImporting, setIsImporting] = useState(false);
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [cameraPermission, requestCameraPermission] = useCameraPermissions();
  const didScanRef = useRef(false);

  const selectedCollection = collections.find((c) => c.id === selectedCollectionId) ?? null;

  // Build share string on demand when tab or selection changes
  React.useEffect(() => {
    if (tab !== 'export' || !selectedCollection) {
      setShareString('');
      return;
    }
    let cancelled = false;
    SerializationService.encodeCollection(selectedCollection).then((encoded) => {
      if (!cancelled) setShareString(encoded);
    });
    return () => { cancelled = true; };
  }, [tab, selectedCollectionId, selectedCollection]);

  async function handleNativeShare() {
    if (!shareString) return;
    try {
      await Share.share({ message: shareString });
    } catch {
      // User dismissed sheet — no action needed
    }
  }

  async function handleImport(text: string) {
    const trimmed = text.trim();
    if (!trimmed) return;
    setIsImporting(true);
    try {
      const result = await cardIngestionService.ingestFromShareString(trimmed);
      if (result.success && result.collection) {
        onImport(result.collection);
        setImportText('');
        onClose();
      } else if (!result.success) {
        Alert.alert(
          'Import failed',
          result.code === 'CHECKSUM_MISMATCH'
            ? 'The share string was corrupted or tampered with.'
            : result.code === 'SCHEMA_VALIDATION_FAILED'
            ? 'The collection data is invalid or from an incompatible version.'
            : 'Could not read the collection. Make sure you copied the full share string.',
        );
      }
    } finally {
      setIsImporting(false);
    }
  }

  async function handleOpenScanner() {
    if (!cameraPermission?.granted) {
      const { granted } = await requestCameraPermission();
      if (!granted) {
        Alert.alert(
          'Camera permission required',
          'Please grant camera access in Settings to scan QR codes.',
        );
        return;
      }
    }
    didScanRef.current = false;
    setIsScannerOpen(true);
  }

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={s.root}>
        {/* Header */}
        <View style={s.header}>
          <Text style={s.title}>Share / Import</Text>
          <Pressable onPress={onClose} style={s.closeBtn} accessibilityRole="button" accessibilityLabel="Close">
            <Text style={s.closeText}>✕</Text>
          </Pressable>
        </View>

        {/* Tabs */}
        <View style={s.tabs}>
          {(['export', 'import'] as Tab[]).map((t) => (
            <Pressable
              key={t}
              style={[s.tab, tab === t && s.tabActive]}
              onPress={() => setTab(t)}
              accessibilityRole="tab"
              accessibilityState={{ selected: tab === t }}
            >
              <Text style={[s.tabText, tab === t && s.tabTextActive]}>
                {t === 'export' ? '↑ Export' : '↓ Import'}
              </Text>
            </Pressable>
          ))}
        </View>

        <ScrollView contentContainerStyle={s.body} keyboardShouldPersistTaps="handled">
          {tab === 'export' ? (
            <ExportTab
              collections={collections}
              selectedId={selectedCollectionId}
              onSelectId={setSelectedCollectionId}
              shareString={shareString}
              onNativeShare={handleNativeShare}
            />
          ) : (
            <ImportTab
              importText={importText}
              onChangeText={setImportText}
              onImport={() => handleImport(importText)}
              onOpenScanner={handleOpenScanner}
              isImporting={isImporting}
            />
          )}
        </ScrollView>
      </View>

      {/* QR Scanner overlay */}
      <Modal visible={isScannerOpen} animationType="slide" onRequestClose={() => setIsScannerOpen(false)}>
        <View style={s.scannerRoot}>
          <CameraView
            style={StyleSheet.absoluteFill}
            facing="back"
            barcodeScannerSettings={{ barcodeTypes: ['qr'] }}
            onBarcodeScanned={(scanned) => {
              if (didScanRef.current) return;
              didScanRef.current = true;
              setIsScannerOpen(false);
              handleImport(scanned.data);
            }}
          />
          <Pressable
            style={s.scannerClose}
            onPress={() => setIsScannerOpen(false)}
            accessibilityRole="button"
            accessibilityLabel="Close scanner"
          >
            <Text style={s.scannerCloseText}>✕  Close</Text>
          </Pressable>
          <View style={s.scannerHint}>
            <Text style={s.scannerHintText}>Align QR code within the frame</Text>
          </View>
        </View>
      </Modal>
    </Modal>
  );
}

// ── Sub-components ──────────────────────────────────────────────

function ExportTab({
  collections,
  selectedId,
  onSelectId,
  shareString,
  onNativeShare,
}: {
  collections: CardCollection[];
  selectedId: string | null;
  onSelectId: (id: string) => void;
  shareString: string;
  onNativeShare: () => void;
}) {
  const exportable = collections.filter((c) => !c.isReadOnly);

  if (exportable.length === 0) {
    return (
      <Text style={s.emptyText}>
        No shareable collections yet.{'\n'}Create a collection first.
      </Text>
    );
  }

  return (
    <View style={s.exportSection}>
      <Text style={s.label}>Select collection to share</Text>
      {exportable.map((c) => (
        <Pressable
          key={c.id}
          style={[s.collectionRow, selectedId === c.id && s.collectionRowActive]}
          onPress={() => onSelectId(c.id)}
          accessibilityRole="radio"
          accessibilityState={{ checked: selectedId === c.id }}
        >
          <Text style={[s.collectionRowText, selectedId === c.id && s.collectionRowTextActive]}>
            {c.name}
          </Text>
          <Text style={s.collectionRowCount}>{c.hands.length} hands</Text>
        </Pressable>
      ))}

      {selectedId && shareString ? (
        <>
          <QRCodeView value={shareString} size={200} />
          <Pressable style={s.shareBtn} onPress={onNativeShare} accessibilityRole="button">
            <Text style={s.shareBtnText}>⬆  Copy / Share String</Text>
          </Pressable>
        </>
      ) : (
        <ActivityIndicator color="#4A6CF7" style={{ marginTop: 24 }} />
      )}
    </View>
  );
}

function ImportTab({
  importText,
  onChangeText,
  onImport,
  onOpenScanner,
  isImporting,
}: {
  importText: string;
  onChangeText: (t: string) => void;
  onImport: () => void;
  onOpenScanner: () => void;
  isImporting: boolean;
}) {
  return (
    <View style={s.importSection}>
      <Text style={s.label}>Paste a share string</Text>
      <TextInput
        style={s.textArea}
        value={importText}
        onChangeText={onChangeText}
        placeholder="Paste share string here…"
        placeholderTextColor="#444"
        multiline
        accessibilityLabel="Share string input"
      />
      <Pressable
        style={[s.importBtn, (!importText.trim() || isImporting) && s.importBtnDisabled]}
        onPress={onImport}
        disabled={!importText.trim() || isImporting}
        accessibilityRole="button"
      >
        {isImporting ? (
          <ActivityIndicator color="#FFF" />
        ) : (
          <Text style={s.importBtnText}>Import Collection</Text>
        )}
      </Pressable>

      <View style={s.divider}>
        <View style={s.dividerLine} />
        <Text style={s.dividerText}>or</Text>
        <View style={s.dividerLine} />
      </View>

      <Pressable style={s.scanBtn} onPress={onOpenScanner} accessibilityRole="button">
        <Text style={s.scanBtnText}>📷  Scan QR Code</Text>
      </Pressable>
    </View>
  );
}

// ── Styles ───────────────────────────────────────────────────────

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#0D0D1A' },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 56,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  title: { color: '#DDD', fontSize: 18, fontWeight: '700' },
  closeBtn: { padding: 8 },
  closeText: { color: '#888', fontSize: 18 },
  tabs: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  tab: { flex: 1, paddingVertical: 14, alignItems: 'center' },
  tabActive: { borderBottomWidth: 2, borderBottomColor: '#4A6CF7' },
  tabText: { color: '#555', fontSize: 14, fontWeight: '600' },
  tabTextActive: { color: '#4A6CF7' },
  body: { padding: 20, paddingBottom: 40 },
  emptyText: { color: '#555', textAlign: 'center', marginTop: 40, lineHeight: 22 },
  label: {
    color: '#888',
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 10,
  },
  exportSection: { gap: 12 },
  collectionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#1C1C2E',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  collectionRowActive: { borderColor: '#4A6CF7', backgroundColor: '#161630' },
  collectionRowText: { color: '#CCC', fontSize: 14, fontWeight: '600' },
  collectionRowTextActive: { color: '#7C9FF7' },
  collectionRowCount: { color: '#555', fontSize: 12 },
  shareBtn: {
    backgroundColor: '#4A6CF7',
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
    marginTop: 8,
  },
  shareBtnText: { color: '#FFF', fontWeight: '700', fontSize: 14 },
  importSection: { gap: 12 },
  textArea: {
    backgroundColor: '#1C1C2E',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
    color: '#DDD',
    fontSize: 12,
    fontFamily: 'monospace',
    padding: 12,
    height: 120,
    textAlignVertical: 'top',
  },
  importBtn: {
    backgroundColor: '#4A6CF7',
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
  },
  importBtnDisabled: { backgroundColor: '#2A2A4A' },
  importBtnText: { color: '#FFF', fontWeight: '700', fontSize: 14 },
  divider: { flexDirection: 'row', alignItems: 'center', gap: 10, marginVertical: 4 },
  dividerLine: { flex: 1, height: 1, backgroundColor: '#2A2A2A' },
  dividerText: { color: '#444', fontSize: 12 },
  scanBtn: {
    backgroundColor: '#1C1C2E',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#444',
    padding: 14,
    alignItems: 'center',
  },
  scanBtnText: { color: '#AAA', fontWeight: '700', fontSize: 14 },
  scannerRoot: { flex: 1, backgroundColor: '#000' },
  scannerClose: {
    position: 'absolute',
    top: 56,
    right: 20,
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  scannerCloseText: { color: '#FFF', fontWeight: '700' },
  scannerHint: {
    position: 'absolute',
    bottom: 60,
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  scannerHintText: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 13,
    backgroundColor: 'rgba(0,0,0,0.5)',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
});
