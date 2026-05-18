/**
 * TileSvg — vector artwork for every American Mahjong tile.
 *
 * Tile art uses react-native-svg shapes only — no image files needed.
 * Each tile is drawn on a white card with a coloured top pip strip.
 */
import React from 'react';
import Svg, {
  Circle,
  Ellipse,
  G,
  Line,
  Path,
  Rect,
  Text as SvgText,
} from 'react-native-svg';
import type { ConcreteTile, NumberTileValue } from '../../types/tiles';

// ── Palette ───────────────────────────────────────────────────────────────────

const C = {
  CRACKS:  { pip: '#E65100', primary: '#E65100', secondary: '#FF9800' },
  DOTS:    { pip: '#1565C0', primary: '#1565C0', secondary: '#42A5F5' },
  BAMS:    { pip: '#2E7D32', primary: '#2E7D32', secondary: '#66BB6A' },
  WINDS:   { pip: '#4A148C', primary: '#4A148C', secondary: '#AB47BC' },
  DRAGONS: { pip: '#880E4F', primary: '#880E4F', secondary: '#F06292' },
  JOKER:   { pip: '#F57F17', primary: '#F57F17', secondary: '#FDD835' },
};

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Layout a grid of N dots centred in a w×h box, returning [cx, cy] pairs. */
function dotLayout(n: NumberTileValue, w: number, h: number): [number, number][] {
  const cx = w / 2;
  const cy = h / 2;
  const s = Math.min(w, h) * 0.28;
  switch (n) {
    case 1: return [[cx, cy]];
    case 2: return [[cx, cy - s], [cx, cy + s]];
    case 3: return [[cx, cy - s], [cx, cy], [cx, cy + s]];
    case 4: return [[cx - s, cy - s], [cx + s, cy - s], [cx - s, cy + s], [cx + s, cy + s]];
    case 5: return [[cx - s, cy - s], [cx + s, cy - s], [cx, cy], [cx - s, cy + s], [cx + s, cy + s]];
    case 6: return [[cx - s, cy - s], [cx + s, cy - s], [cx - s, cy], [cx + s, cy], [cx - s, cy + s], [cx + s, cy + s]];
    case 7: return [[cx - s, cy - s], [cx + s, cy - s], [cx - s, cy], [cx + s, cy], [cx - s, cy + s], [cx + s, cy + s], [cx, cy - s * 1.7]];
    case 8: return [[cx - s, cy - s * 1.4], [cx + s, cy - s * 1.4], [cx - s, cy - s * 0.2], [cx + s, cy - s * 0.2], [cx - s, cy + s * 0.8], [cx + s, cy + s * 0.8], [cx - s, cy + s * 1.8], [cx + s, cy + s * 1.8]];
    case 9: return [[cx - s, cy - s * 1.4], [cx, cy - s * 1.4], [cx + s, cy - s * 1.4], [cx - s, cy], [cx, cy], [cx + s, cy], [cx - s, cy + s * 1.4], [cx, cy + s * 1.4], [cx + s, cy + s * 1.4]];
  }
}

// Chinese numeral characters for CRACKS (万子)
const CRACK_CHAR: Record<NumberTileValue, string> = {
  1: '一', 2: '二', 3: '三', 4: '四', 5: '五',
  6: '六', 7: '七', 8: '八', 9: '九',
};

// ── Sub-renderers ─────────────────────────────────────────────────────────────

function CrackBody({ n, w, h, col }: { n: NumberTileValue; w: number; h: number; col: typeof C.CRACKS }) {
  const ch = CRACK_CHAR[n];
  return (
    <G>
      {/* Big Chinese numeral */}
      <SvgText
        x={w / 2} y={h * 0.58}
        fontSize={h * 0.38}
        fontWeight="bold"
        fill={col.primary}
        textAnchor="middle"
      >
        {ch}
      </SvgText>
      {/* Arabic digit top-left */}
      <SvgText
        x={w * 0.14} y={h * 0.28}
        fontSize={h * 0.16}
        fill={col.secondary}
        fontWeight="600"
      >
        {n}
      </SvgText>
      {/* 万 label bottom */}
      <SvgText
        x={w / 2} y={h * 0.85}
        fontSize={h * 0.14}
        fill={col.secondary}
        textAnchor="middle"
      >
        萬
      </SvgText>
    </G>
  );
}

function DotBody({ n, w, h, col }: { n: NumberTileValue; w: number; h: number; col: typeof C.DOTS }) {
  const positions = dotLayout(n, w, h * 0.72);
  const r = Math.min(w, h) * 0.1;
  // y-offset to centre the dot area below the pip strip
  const yOff = h * 0.18;
  return (
    <G>
      {positions.map(([cx, cy], i) => (
        <G key={i}>
          <Circle cx={cx} cy={cy + yOff} r={r * 1.2} fill={col.secondary} opacity={0.35} />
          <Circle cx={cx} cy={cy + yOff} r={r} fill={col.primary} />
        </G>
      ))}
      <SvgText
        x={w * 0.14} y={h * 0.15}
        fontSize={h * 0.13}
        fill={col.primary}
        fontWeight="700"
      >
        {n}
      </SvgText>
    </G>
  );
}

function BamBody({ n, w, h, col }: { n: NumberTileValue; w: number; h: number; col: typeof C.BAMS }) {
  if (n === 1) {
    // Traditional single-bam bird shape (simplified as a circle + stick)
    return (
      <G>
        <Circle cx={w / 2} cy={h * 0.44} r={w * 0.22} fill={col.secondary} opacity={0.4} />
        <Circle cx={w / 2} cy={h * 0.44} r={w * 0.15} fill={col.primary} />
        <Rect x={w / 2 - 2} y={h * 0.6} width={4} height={h * 0.2} rx={2} fill={col.primary} />
        <SvgText x={w * 0.14} y={h * 0.15} fontSize={h * 0.13} fill={col.primary} fontWeight="700">{n}</SvgText>
      </G>
    );
  }
  // Columns of bamboo sticks
  const cols = n <= 3 ? 1 : n <= 6 ? 2 : 3;
  const rows = Math.ceil(n / cols);
  const stickW = w * 0.16;
  const stickH = h * 0.22;
  const xGap = w / (cols + 1);
  const yStart = h * 0.2;
  const yGap = (h * 0.72) / rows;
  let stick = 0;
  const sticks: React.ReactNode[] = [];
  for (let r = 0; r < rows && stick < n; r++) {
    for (let c = 0; c < cols && stick < n; c++) {
      const sx = xGap * (c + 1) - stickW / 2;
      const sy = yStart + r * yGap;
      sticks.push(
        <G key={stick}>
          <Rect x={sx} y={sy} width={stickW} height={stickH} rx={stickW / 2} fill={col.primary} />
          {/* node rings */}
          <Rect x={sx - 1} y={sy + stickH * 0.38} width={stickW + 2} height={3} rx={1.5} fill={col.secondary} />
          <Rect x={sx - 1} y={sy + stickH * 0.65} width={stickW + 2} height={3} rx={1.5} fill={col.secondary} />
        </G>
      );
      stick++;
    }
  }
  return (
    <G>
      {sticks}
      <SvgText x={w * 0.14} y={h * 0.16} fontSize={h * 0.13} fill={col.primary} fontWeight="700">{n}</SvgText>
    </G>
  );
}

const WIND_CHAR: Record<string, string> = { N: '北', S: '南', E: '東', W: '西' };
const WIND_LABEL: Record<string, string> = { N: 'North', S: 'South', E: 'East', W: 'West' };

function WindBody({ value, w, h, col }: { value: string; w: number; h: number; col: typeof C.WINDS }) {
  return (
    <G>
      <SvgText
        x={w / 2} y={h * 0.6}
        fontSize={h * 0.42}
        fontWeight="bold"
        fill={col.primary}
        textAnchor="middle"
      >
        {WIND_CHAR[value]}
      </SvgText>
      <SvgText
        x={w / 2} y={h * 0.84}
        fontSize={h * 0.13}
        fill={col.secondary}
        textAnchor="middle"
      >
        {WIND_LABEL[value]}
      </SvgText>
    </G>
  );
}

function DragonBody({ value, w, h, col }: { value: string; w: number; h: number; col: typeof C.DRAGONS }) {
  if (value === 'RED') {
    return (
      <G>
        <SvgText x={w / 2} y={h * 0.62} fontSize={h * 0.44} fontWeight="bold" fill="#C62828" textAnchor="middle">中</SvgText>
        <SvgText x={w / 2} y={h * 0.84} fontSize={h * 0.13} fill="#EF9A9A" textAnchor="middle">Chun</SvgText>
      </G>
    );
  }
  if (value === 'GREEN') {
    return (
      <G>
        <SvgText x={w / 2} y={h * 0.62} fontSize={h * 0.44} fontWeight="bold" fill="#2E7D32" textAnchor="middle">發</SvgText>
        <SvgText x={w / 2} y={h * 0.84} fontSize={h * 0.13} fill="#81C784" textAnchor="middle">Hatsu</SvgText>
      </G>
    );
  }
  // WHITE — blank soap tile with decorative border ring
  return (
    <G>
      <Rect x={w * 0.12} y={h * 0.2} width={w * 0.76} height={h * 0.58} rx={4} fill="none" stroke="#BDBDBD" strokeWidth={2} />
      <SvgText x={w / 2} y={h * 0.84} fontSize={h * 0.13} fill="#9E9E9E" textAnchor="middle">Haku</SvgText>
    </G>
  );
}

function JokerBody({ w, h }: { w: number; h: number }) {
  return (
    <G>
      <SvgText x={w / 2} y={h * 0.58} fontSize={h * 0.38} textAnchor="middle">🃏</SvgText>
      <SvgText x={w / 2} y={h * 0.84} fontSize={h * 0.13} fill="#F57F17" textAnchor="middle" fontWeight="700">JOKER</SvgText>
    </G>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

interface TileSvgProps {
  tile: ConcreteTile;
  width?: number;
  height?: number;
}

export function TileSvg({ tile, width = 44, height = 54 }: TileSvgProps) {
  const w = width;
  const h = height;
  const col = C[tile.suit] ?? C.JOKER;
  const r = Math.min(w, h) * 0.12;

  function renderBody() {
    switch (tile.suit) {
      case 'CRACKS':
        return <CrackBody n={tile.value as NumberTileValue} w={w} h={h} col={col} />;
      case 'DOTS':
        return <DotBody n={tile.value as NumberTileValue} w={w} h={h} col={col} />;
      case 'BAMS':
        return <BamBody n={tile.value as NumberTileValue} w={w} h={h} col={col} />;
      case 'WINDS':
        return <WindBody value={tile.value as string} w={w} h={h} col={col} />;
      case 'DRAGONS':
        return <DragonBody value={tile.value as string} w={w} h={h} col={col} />;
      case 'JOKER':
        return <JokerBody w={w} h={h} />;
      default:
        return null;
    }
  }

  return (
    <Svg width={w} height={h} viewBox={`0 0 ${w} ${h}`}>
      {/* Card background */}
      <Rect x={0.5} y={0.5} width={w - 1} height={h - 1} rx={r} fill="#FFFFFF" stroke={col.pip} strokeWidth={1.5} />
      {/* Coloured top pip strip */}
      <Path
        d={`M ${r} 0.5 L ${w - r} 0.5 Q ${w - 0.5} 0.5 ${w - 0.5} ${r} L ${w - 0.5} ${h * 0.08} L 0.5 ${h * 0.08} L 0.5 ${r} Q 0.5 0.5 ${r} 0.5 Z`}
        fill={col.pip}
      />
      {/* Tile art */}
      {renderBody()}
    </Svg>
  );
}
