import { expect, test } from '@playwright/test';

async function login(page, user, password) {
  await page.goto('/login');
  await page.getByLabel(/email/i).fill(user.email);
  await page.getByLabel(/password/i).fill(password);
  await page.getByRole('button', { name: /sign in|log in/i }).click();
  await expect(page).toHaveURL(/\/$/);
}

async function setupRun(request) {
  const runId = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const response = await request.post('/test/e2e/setup', { data: { run_id: runId } });
  expect(response.ok()).toBe(true);
  return response.json();
}

async function cleanupRun(request, runId) {
  await request.post('/test/e2e/cleanup', { data: { run_id: runId } });
}

async function startGroupChat(page, accountId, firstMessage) {
  await page.goto(`/accounts/${accountId}/chats`);
  await expect(page.getByRole('heading', { name: 'New Chat' })).toBeVisible();

  await page.getByLabel(/group chat with agents/i).check();
  await page.getByRole('button', { name: /E2E Researcher/i }).click();
  await page.getByRole('button', { name: /E2E Critic/i }).click();

  const composer = page.locator('main textarea').last();
  await composer.fill(firstMessage);
  await page.locator('main button').last().click();

  await expect(page).toHaveURL(/\/accounts\/[^/]+\/chats\/[^/]+$/);
  await expect(page.getByText(firstMessage)).toBeVisible();
}

test.describe('chat browser contracts', () => {
  let setup;

  test.beforeEach(async ({ request }) => {
    setup = await setupRun(request);
  });

  test.afterEach(async ({ request }) => {
    await cleanupRun(request, setup.run_id);
  });

  test('user can log in, create a multi-agent chat, and see deterministic thinking output', async ({
    page,
    request,
  }) => {
    await login(page, setup.primary_user, setup.password);
    await startGroupChat(page, setup.account_id, 'Please compare the two test agents.');

    const chatId = page.url().split('/').pop();
    const response = await request.post('/test/e2e/assistant_message', {
      data: {
        chat_id: chatId,
        thinking: 'I will compare both deterministic test agents before answering.',
        content: 'The researcher gathers context; the critic checks assumptions.',
      },
    });
    expect(response.ok()).toBe(true);

    await page.reload();
    await expect(page.getByText('The researcher gathers context; the critic checks assumptions.')).toBeVisible();
    await expect(page.getByText(/I will compare both deterministic test agents/)).toBeVisible();
  });

  test('chat messages sync between two logged-in browser windows', async ({ browser, page }) => {
    await login(page, setup.primary_user, setup.password);
    await startGroupChat(page, setup.account_id, 'Initial message from the primary user.');
    const chatUrl = page.url();

    const secondContext = await browser.newContext();
    const secondPage = await secondContext.newPage();
    await login(secondPage, setup.secondary_user, setup.password);
    await secondPage.goto(chatUrl);
    await expect(secondPage.getByText('Initial message from the primary user.')).toBeVisible();

    await secondPage.locator('main textarea').last().fill('Synced message from another browser.');
    await secondPage.locator('main button').last().click();

    await expect(page.getByText('Synced message from another browser.')).toBeVisible();
    await secondContext.close();
  });
});
