import type { CustomHand } from './hands';

export type CollectionSource = 'USER_CREATED' | 'IMPORTED' | 'DEMO';

export interface CardCollection {
  readonly id: string;
  readonly name: string;
  readonly description?: string;
  readonly source: CollectionSource;
  /** Incremented on structural schema changes to this collection's format. */
  readonly schemaVersion: number;
  readonly hands: CustomHand[];
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
