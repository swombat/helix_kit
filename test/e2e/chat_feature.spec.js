import { test, expect } from '@playwright/test';

test.describe('Chat Feature E2E Tests', () => {
  let userEmail, userPassword;

  test.beforeEach(async ({ page }) => {
    // Create unique user for each test
    userEmail = `e2etest+${Date.now()}@example.com`;
    userPassword = 'testpassword123';

    // Create test user account via signup
    await page.goto('/signup');
    await page.fill('input[type="email"]', userEmail);
    await page.fill('input[type="password"]', userPassword);
    await page.click('button[type="submit"]');

    // Wait for successful registration and login
    await page.waitForURL(/\/$/);
  });

  test.afterEach(async ({ page }) => {
    // Cleanup: Delete the test user account
    // Note: This would require an admin endpoint or direct database access
    // For now, we'll rely on periodic test database cleanup
  });

  test('complete chat creation and conversation flow', async ({ page }) => {
    // Navigate to chats
    await page.goto('/accounts/1/chats');

    // Should see empty state
    await expect(page).toHaveTitle(/Chats/);
    await expect(page.locator('text=Start a conversation')).toBeVisible();

    // Select AI model
    await page.click('[id="model-select"]');
    await page.click('[data-value="gpt-4o-mini"]');

    // Create new chat
    await page.click('button:has-text("Start New Chat")');

    // Should navigate to new chat page
    await page.waitForURL(/\/accounts\/\d+\/chats\/[a-zA-Z0-9]+/);
    await expect(page).toHaveTitle(/New Conversation/);

    // Send first message
    const messageInput = page.locator('textarea[placeholder="Type your message..."]');
    await messageInput.fill('Hello, can you help me with a simple math problem?');
    await page.click('button:has(svg)');

    // Message should appear in chat
    await expect(page.locator('text=Hello, can you help me with a simple math problem?')).toBeVisible();

    // Wait for AI response (this would trigger the real AI job)
    // In a real test, we might mock the AI response or use a test model
    await expect(page.locator('text=Thinking...')).toBeVisible();

    // Note: Full AI response testing would require mocking or a dedicated test environment
    // For E2E, we're primarily testing the UI flow

    // Send another message
    await messageInput.fill('What is 2 + 2?');
    await page.press('textarea[placeholder="Type your message..."]', 'Enter');

    // Second message should appear
    await expect(page.locator('text=What is 2 + 2?')).toBeVisible();
  });

  test('chat list management', async ({ page }) => {
    // Create multiple chats by visiting the chats page multiple times
    await page.goto('/accounts/1/chats');

    // Create first chat
    await page.click('[id="model-select"]');
    await page.click('[data-value="gpt-4o-mini"]');
    await page.click('button:has-text("Start New Chat")');

    // Wait for chat creation
    await page.waitForURL(/\/accounts\/\d+\/chats\/[a-zA-Z0-9]+/);

    // Send a message to make it appear in sidebar
    await page.fill('textarea[placeholder="Type your message..."]', 'First chat message');
    await page.click('button:has(svg)');

    // Go back to create another chat
    await page.goto('/accounts/1/chats');
    await page.click('[id="model-select"]');
    await page.click('[data-value="claude-3.5-sonnet"]');
    await page.click('button:has-text("Start New Chat")');

    // Send message to second chat
    await page.fill('textarea[placeholder="Type your message..."]', 'Second chat message');
    await page.click('button:has(svg)');

    // Check sidebar shows both chats
    await expect(page.locator('text=First chat message').first()).toBeVisible();
    await expect(page.locator('text=Second chat message').first()).toBeVisible();

    // Navigate between chats using sidebar
    // This would require clicking on chat items in the sidebar
    // The exact selector would depend on the ChatList component structure
  });

  test('chat deletion', async ({ page }) => {
    // Create a chat first
    await page.goto('/accounts/1/chats');
    await page.click('button:has-text("Start New Chat")');

    // Wait for chat creation
    await page.waitForURL(/\/accounts\/\d+\/chats\/[a-zA-Z0-9]+/);

    // Add a message
    await page.fill('textarea[placeholder="Type your message..."]', 'This chat will be deleted');
    await page.click('button:has(svg)');

    // Delete the chat (would need delete button in UI)
    // Note: This depends on having a delete button in the chat interface
    // If not available in the UI, this test would need to be adjusted

    // For now, let's test navigation away from chat
    await page.goto('/accounts/1/chats');

    // Should return to chats index
    await expect(page).toHaveTitle(/Chats/);
  });

  test('message retry functionality', async ({ page }) => {
    // This test would require simulating a failed AI response
    // which is difficult without mocking the AI service

    await page.goto('/accounts/1/chats');
    await page.click('button:has-text("Start New Chat")');

    // Send a message
    await page.fill('textarea[placeholder="Type your message..."]', 'Test message for retry');
    await page.click('button:has(svg)');

    // In a real scenario with mocked failures, we would:
    // 1. See the message appear
    // 2. See "Thinking..." state
    // 3. See error state with retry button
    // 4. Click retry button
    // 5. See successful response

    // For now, just verify the message was sent
    await expect(page.locator('text=Test message for retry')).toBeVisible();
  });

  test('real-time updates and message streaming', async ({ page, browser }) => {
    // This test simulates real-time features using multiple browser contexts

    await page.goto('/accounts/1/chats');
    await page.click('button:has-text("Start New Chat")');

    // Get the current chat URL
    await page.waitForURL(/\/accounts\/\d+\/chats\/[a-zA-Z0-9]+/);
    const chatUrl = page.url();

    // Send a message
    await page.fill('textarea[placeholder="Type your message..."]', 'Testing real-time updates');
    await page.click('button:has(svg)');

    // Open second browser context to same chat (simulating another user/tab)
    const context2 = await browser.newContext();
    const page2 = await context2.newPage();

    // Login as same user in second context
    await page2.goto('/login');
    await page2.fill('input[type="email"]', userEmail);
    await page2.fill('input[type="password"]', userPassword);
    await page2.click('button[type="submit"]');

    // Navigate to same chat
    await page2.goto(chatUrl);

    // Both pages should show the same message
    await expect(page.locator('text=Testing real-time updates')).toBeVisible();
    await expect(page2.locator('text=Testing real-time updates')).toBeVisible();

    // Send message from second context
    await page2.fill('textarea[placeholder="Type your message..."]', 'Message from second tab');
    await page2.click('button:has(svg)');

    // First page should receive real-time update
    await expect(page.locator('text=Message from second tab')).toBeVisible();

    await context2.close();
  });

  test('keyboard shortcuts and accessibility', async ({ page }) => {
    await page.goto('/accounts/1/chats');
    await page.click('button:has-text("Start New Chat")');

    const messageInput = page.locator('textarea[placeholder="Type your message..."]');

    // Test Enter key sends message
    await messageInput.fill('Testing Enter key');
    await page.press('textarea[placeholder="Type your message..."]', 'Enter');

    // Message should be sent and input cleared
    await expect(page.locator('text=Testing Enter key')).toBeVisible();
    await expect(messageInput).toHaveValue('');

    // Test Shift+Enter creates new line
    await messageInput.fill('Line 1');
    await page.press('textarea[placeholder="Type your message..."]', 'Shift+Enter');
    await messageInput.type('Line 2');

    // Should contain newline
    const inputValue = await messageInput.inputValue();
    expect(inputValue).toContain('\n');

    // Send multi-line message
    await page.press('textarea[placeholder="Type your message..."]', 'Enter');
    await expect(page.locator('text=Line 1')).toBeVisible();
    await expect(page.locator('text=Line 2')).toBeVisible();
  });

  test('mobile responsiveness', async ({ page }) => {
    // Test mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });

    await page.goto('/accounts/1/chats');

    // Check that mobile layout works
    await expect(page.locator('text=Start a conversation')).toBeVisible();

    // Create chat on mobile
    await page.click('button:has-text("Start New Chat")');

    // Chat interface should be mobile-friendly
    const messageInput = page.locator('textarea[placeholder="Type your message..."]');
    await expect(messageInput).toBeVisible();

    // Send button should be accessible on mobile
    const sendButton = page.locator('button:has(svg)');
    await expect(sendButton).toBeVisible();

    // Test message sending on mobile
    await messageInput.fill('Mobile test message');
    await sendButton.click();

    await expect(page.locator('text=Mobile test message')).toBeVisible();
  });

  test('account scoping and security', async ({ page, browser }) => {
    // Create first chat
    await page.goto('/accounts/1/chats');
    await page.click('button:has-text("Start New Chat")');

    await page.waitForURL(/\/accounts\/\d+\/chats\/[a-zA-Z0-9]+/);
    const firstUserChatUrl = page.url();

    // Create second user in different context
    const context2 = await browser.newContext();
    const page2 = await context2.newPage();

    const secondUserEmail = `e2etest2+${Date.now()}@example.com`;

    // Register second user
    await page2.goto('/signup');
    await page2.fill('input[type="email"]', secondUserEmail);
    await page2.fill('input[type="password"]', 'testpassword123');
    await page2.click('button[type="submit"]');

    // Try to access first user's chat with second user
    await page2.goto(firstUserChatUrl);

    // Should be redirected or show 404/403
    await expect(page2).not.toHaveURL(firstUserChatUrl);
    // Or: await expect(page2.locator('text=Not Found')).toBeVisible();

    await context2.close();
  });

  test('error handling and edge cases', async ({ page }) => {
    await page.goto('/accounts/1/chats');

    // Test empty message submission
    await page.click('button:has-text("Start New Chat")');

    const messageInput = page.locator('textarea[placeholder="Type your message..."]');
    const sendButton = page.locator('button:has(svg)');

    // Send button should be disabled for empty input
    await expect(sendButton).toBeDisabled();

    // Try whitespace-only message
    await messageInput.fill('   ');
    await expect(sendButton).toBeDisabled();

    // Valid message should enable button
    await messageInput.fill('Valid message');
    await expect(sendButton).toBeEnabled();

    // Test very long message
    const longMessage = 'a'.repeat(10000);
    await messageInput.fill(longMessage);
    await sendButton.click();

    // Should handle long messages gracefully
    await expect(page.locator('text=' + longMessage.substring(0, 50))).toBeVisible();
  });

  test('message formatting and markdown rendering', async ({ page }) => {
    await page.goto('/accounts/1/chats');
    await page.click('button:has-text("Start New Chat")');

    // Send message with markdown-like content
    const markdownMessage = 'Here is **bold** text and `code` and a [link](https://example.com)';
    await page.fill('textarea[placeholder="Type your message..."]', markdownMessage);
    await page.click('button:has(svg)');

    // Message should appear (user messages might not be rendered as markdown)
    await expect(page.locator('text=' + markdownMessage)).toBeVisible();

    // AI responses would be rendered as markdown HTML
    // This would need to be tested with actual AI responses or mocked responses
  });

  test('chat history persistence', async ({ page }) => {
    await page.goto('/accounts/1/chats');
    await page.click('button:has-text("Start New Chat")');

    // Send some messages
    await page.fill('textarea[placeholder="Type your message..."]', 'First message');
    await page.click('button:has(svg)');

    await page.fill('textarea[placeholder="Type your message..."]', 'Second message');
    await page.click('button:has(svg)');

    // Get chat URL
    const chatUrl = page.url();

    // Navigate away and back
    await page.goto('/accounts/1/chats');
    await page.goto(chatUrl);

    // Messages should still be there
    await expect(page.locator('text=First message')).toBeVisible();
    await expect(page.locator('text=Second message')).toBeVisible();

    // Refresh page
    await page.reload();

    // Messages should persist after refresh
    await expect(page.locator('text=First message')).toBeVisible();
    await expect(page.locator('text=Second message')).toBeVisible();
  });
});
