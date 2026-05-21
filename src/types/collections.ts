import type { CustomHand } from './hands';

export type CollectionSource = 'USER_CREATED' | 'IMPORTED' | 'DEMO';

/** A named section heading inside a collection, mirroring the card's category rows. */
export interface HandGroup {
  readonly id: string;
  readonly collectionId: string;
  readonly name: string;
  readonly sortOrder: number;
  readonly createdAt: number;
  readonly updatedAt: number;
}

export interface CardCollection {
  readonly id: string;
  readonly name: string;
  readonly description?: string;
  readonly source: CollectionSource;
  /** Incremented on structural schema changes to this collection's format. */
  readonly schemaVersion: number;
  readonly hands: CustomHand[];
  /** Named section groups (e.g. "QUINTS", "2468"). Ordered by sortOrder. */
  readonly groups: HandGroup[];
  readonly createdAt: number;
  readonly updatedAt: number;
  /** True for the built-in DEMO_COLLECTION — prevents mutation. */
  readonly isReadOnly: boolean;
}

export type GameMode = 'AMERICAN' | 'CHINESE';

export interface AppSettings {
  readonly activeCollectionId: string | null;
  readonly lastViewMode: 'ASSIST' | 'FOCUS' | 'SCOUT';
  readonly appSchemaVersion: string;
  readonly gameMode: GameMode;
}
