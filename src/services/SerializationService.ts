import type { CardCollection } from '../types/collections';
import type { SharePayload } from '../types/ingestion';
import { base64Encode, base64Decode, sha256Digest } from '../utils/cryptoUtils';

export interface CryptoProvider {
  encode(data: string): string;
  decode(encoded: string): string;
}

const defaultProvider: CryptoProvider = {
  encode: base64Encode,
  decode: base64Decode,
};

export const SerializationService = {
  async encodeCollection(
    collection: CardCollection,
    crypto: CryptoProvider = defaultProvider,
  ): Promise<string> {
    const json = JSON.stringify(collection);
    const checksum = await sha256Digest(json);
    const payload: SharePayload = { payloadVersion: '1', collection, checksum };
    return crypto.encode(JSON.stringify(payload));
  },

  async decodeCollection(
    encoded: string,
    crypto: CryptoProvider = defaultProvider,
  ): Promise<{ payload: SharePayload; checksumValid: boolean }> {
    const json = crypto.decode(encoded.trim());
    const payload = JSON.parse(json) as SharePayload;
    const expectedChecksum = await sha256Digest(JSON.stringify(payload.collection));
    return { payload, checksumValid: expectedChecksum === payload.checksum };
  },
};
