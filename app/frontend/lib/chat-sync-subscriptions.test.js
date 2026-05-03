import { describe, expect, test } from 'vitest';
import { buildChatSubscriptions, chatSyncSignature } from './chat-sync-subscriptions';

describe('chat sync subscriptions', () => {
  test('subscribes to account chat list when no chat is open', () => {
    expect(buildChatSubscriptions({ account: { id: 12 }, chat: null })).toEqual({
      'Account:12:chats': 'chats',
    });
  });

  test('subscribes to chat messages and active whiteboard when present', () => {
    expect(
      buildChatSubscriptions({
        account: { id: 12 },
        chat: { id: 34, active_whiteboard: { id: 56 } },
      })
    ).toEqual({
      'Account:12:chats': 'chats',
      'Chat:34': ['chat', 'messages'],
      'Chat:34:messages': 'messages',
      'Whiteboard:56': ['chat', 'messages'],
    });
  });

  test('signatures change when the selected chat or recent message ids change', () => {
    expect(chatSyncSignature({ account: { id: 12 }, chat: { id: 34 }, recentMessages: [{ id: 1 }, { id: 2 }] })).toBe(
      '12|34|1:2'
    );
    expect(chatSyncSignature({ account: { id: 12 }, chat: null, recentMessages: [] })).toBe('12|none|');
  });
});
