import { useCallback, useEffect } from 'react';
import { useCollectionRepository } from '../db/repositories/CollectionRepository';
import type { CardCollection } from '../types/collections';
import { useAppContext } from '../context/AppProvider';

export function useCollections() {
  const { state, dispatch } = useAppContext();
  const repo = useCollectionRepository();

  const loadCollections = useCallback(async () => {
    dispatch({ type: 'SET_LOADING', payload: true });
    try {
      const collections = await repo.findAll();
      dispatch({ type: 'SET_COLLECTIONS', payload: collections });
      if (!state.activeCollectionId && collections.length > 0) {
        dispatch({ type: 'SET_ACTIVE_COLLECTION', payload: collections[0].id });
      }
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  }, [repo, dispatch, state.activeCollectionId]);

  useEffect(() => {
    void loadCollections();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const createCollection = useCallback(
    async (collection: CardCollection) => {
      await repo.save(collection);
      dispatch({ type: 'ADD_COLLECTION', payload: collection });
      if (!state.activeCollectionId) {
        dispatch({ type: 'SET_ACTIVE_COLLECTION', payload: collection.id });
      }
    },
    [repo, dispatch, state.activeCollectionId],
  );

  const updateCollection = useCallback(
    async (collection: CardCollection) => {
      await repo.save(collection);
      dispatch({ type: 'UPDATE_COLLECTION', payload: collection });
    },
    [repo, dispatch],
  );

  const deleteCollection = useCallback(
    async (id: string) => {
      await repo.delete(id);
      dispatch({ type: 'DELETE_COLLECTION', payload: id });
    },
    [repo, dispatch],
  );

  const setActiveCollection = useCallback(
    (id: string | null) => dispatch({ type: 'SET_ACTIVE_COLLECTION', payload: id }),
    [dispatch],
  );

  return {
    collections: state.collections,
    activeCollectionId: state.activeCollectionId,
    isLoading: state.isLoading,
    loadCollections,
    createCollection,
    updateCollection,
    deleteCollection,
    setActiveCollection,
  };
}
