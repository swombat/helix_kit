import { describe, expect, test } from 'vitest';
import {
  isChatResponseTimedOut,
  lastMessageIsHiddenThinking,
  lastUserMessageNeedsResend,
  shouldShowSendingPlaceholder,
  shouldShowTimestampForMessages,
  timestampLabelForMessages,
  visibleChatMessages,
} from './chat-message-state';

const at = (iso) => new Date(iso).toISOString();
const message = (attrs) => ({ id: attrs.id ?? Math.random(), created_at: at('2026-05-03T10:00:00Z'), ...attrs });

describe('chat message state', () => {
  test('hides tool chatter, empty assistant placeholders, and pure JSON tool results', () => {
    const messages = [
      message({ id: 1, role: 'user', content: 'Hi' }),
      message({ id: 2, role: 'tool', content: 'raw result' }),
      message({ id: 3, role: 'assistant', content: '', streaming: false }),
      message({ id: 4, role: 'assistant', content: '{"tool":"result"}', streaming: false }),
      message({ id: 5, role: 'assistant', content: '{"tool":"result"} Actual answer', streaming: false }),
    ];

    expect(visibleChatMessages(messages).map((visible) => visible.id)).toEqual([1, 5]);
    expect(visibleChatMessages(messages, true)).toBe(messages);
  });

  test('detects hidden thinking and pending user responses without showing placeholders in manual chats', () => {
    expect(lastMessageIsHiddenThinking([message({ role: 'assistant', content: '', streaming: false })])).toBe(true);
    expect(
      shouldShowSendingPlaceholder({ chat: {}, messages: [message({ role: 'user' })], waitingForResponse: false })
    ).toBe(true);
    expect(
      shouldShowSendingPlaceholder({
        chat: { manual_responses: true },
        messages: [message({ role: 'user' })],
        waitingForResponse: true,
      })
    ).toBe(false);
  });

  test('marks stale unanswered user messages as timed out and resendable', () => {
    const now = new Date('2026-05-03T10:02:01Z').getTime();
    const messages = [message({ role: 'user', created_at: at('2026-05-03T10:00:00Z') })];

    expect(
      isChatResponseTimedOut({ chat: {}, messages, waitingForResponse: false, messageSentAt: null, currentTime: now })
    ).toBe(true);
    expect(lastUserMessageNeedsResend(messages, now)).toBe(true);
  });

  test('shows timestamp dividers for the first message, day changes, and hour gaps', () => {
    const messages = [
      message({ created_at: at('2026-05-03T10:00:00Z') }),
      message({ created_at: at('2026-05-03T10:30:00Z') }),
      message({ created_at: at('2026-05-03T11:30:00Z') }),
      message({ created_at: at('2026-05-04T09:00:00Z') }),
    ];

    expect(messages.map((_, index) => shouldShowTimestampForMessages(messages, index))).toEqual([
      true,
      false,
      true,
      true,
    ]);
  });

  test('uses date labels for new groups and time labels within a day', () => {
    const messages = [
      message({ created_at: at('2026-05-03T10:00:00Z') }),
      message({ created_at: at('2026-05-03T10:30:00Z') }),
    ];
    const formatters = {
      formatDate: (date) => `date:${date.toISOString().slice(0, 10)}`,
      formatTime: (date) => `time:${date.toISOString().slice(11, 16)}`,
    };

    expect(timestampLabelForMessages(messages, 0, formatters)).toBe('date:2026-05-03');
    expect(timestampLabelForMessages(messages, 1, formatters)).toBe('time:10:30');
  });
});
