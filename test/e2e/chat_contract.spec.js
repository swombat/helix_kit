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

async function getRunState(request, runId) {
  const response = await request.post('/test/e2e/state', { data: { run_id: runId } });
  expect(response.ok()).toBe(true);
  return response.json();
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

test.describe('browser contracts', () => {
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

  test('user can update profile details, timezone, and avatar', async ({ page, request }) => {
    await login(page, setup.primary_user, setup.password);
    await page.goto('/user/edit');
    await expect(page.getByRole('heading', { name: 'User Settings' })).toBeVisible();

    await page.getByLabel('First Name').fill('E2E Profile');
    await page.getByLabel('Last Name').fill('Tester');
    await page.getByText('Select your timezone').click();
    await page.getByRole('option', { name: /London/ }).click();
    await page.getByRole('button', { name: 'Save Changes' }).click();

    await expect(page.getByText(/Settings updated successfully/)).toBeVisible();

    await page.getByRole('button', { name: /update profile picture/i }).click();
    await page.locator('#avatar-upload').setInputFiles('test/fixtures/files/test_avatar.png');
    await expect(page.getByRole('dialog')).not.toBeVisible();

    const state = await getRunState(request, setup.run_id);
    expect(state.primary_user.full_name).toBe('E2E Profile Tester');
    expect(state.primary_user.timezone).toBe('London');
    expect(state.primary_user.avatar_attached).toBe(true);
  });

  test('owner can invite a user who accepts and joins the account', async ({ browser, page, request }) => {
    const invitedEmail = `e2e-${setup.run_id}-invitee@example.com`;

    await login(page, setup.primary_user, setup.password);
    await page.goto(`/accounts/${setup.account_id}`);
    await expect(page.getByRole('heading', { name: 'Account Settings' })).toBeVisible();

    await page.getByRole('button', { name: 'Invite Member' }).click();
    await page.getByLabel('Email Address').fill(invitedEmail);
    await page.getByRole('button', { name: 'Send Invitation' }).click();
    await expect(page.getByRole('cell', { name: invitedEmail })).toBeVisible();

    const invitationResponse = await request.post('/test/e2e/invitation_url', { data: { email: invitedEmail } });
    expect(invitationResponse.ok()).toBe(true);
    const { url } = await invitationResponse.json();

    const invitedContext = await browser.newContext();
    const invitedPage = await invitedContext.newPage();
    await invitedPage.goto(url);
    await expect(invitedPage.getByRole('heading', { name: 'Email Confirmed!' })).toBeVisible();
    await invitedPage.getByLabel('First Name').fill('Invited');
    await invitedPage.getByLabel('Last Name').fill('Member');
    await invitedPage.getByLabel('Password', { exact: true }).fill(setup.password);
    await invitedPage.getByLabel('Confirm Password').fill(setup.password);
    await invitedPage.getByRole('button', { name: 'Complete Setup' }).click();
    await expect(invitedPage).toHaveURL(/\/$/);
    await invitedContext.close();

    const state = await getRunState(request, setup.run_id);
    expect(state.account.members).toContainEqual(
      expect.objectContaining({
        email: invitedEmail,
        role: 'member',
        confirmed: true,
      })
    );
  });

  test('agent settings can be edited and saved', async ({ page, request }) => {
    await login(page, setup.primary_user, setup.password);
    await page.goto(setup.agents[0].edit_url);
    await expect(page.getByRole('heading', { name: 'Edit Agent' })).toBeVisible();

    await page.getByRole('button', { name: 'Memory' }).click();
    await expect(page.getByRole('heading', { name: 'Agent Memory' })).toBeVisible();
    await page.getByRole('button', { name: 'Add Memory' }).click();
    await expect(page.getByLabel('Memory Content')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Save Memory' })).toBeDisabled();
    await page
      .getByRole('button', { name: 'Save Memory' })
      .locator('..')
      .getByRole('button', { name: 'Cancel' })
      .click();
    await page.getByRole('button', { name: 'Identity' }).click();

    await page.getByLabel('Name').fill('E2E Refactor Sentinel');
    await page.getByLabel('System Prompt').fill('You are an E2E sentinel guarding refactors.');
    await page.getByLabel('Refinement Retention Threshold').fill('0.85');
    await page.locator('label[for="paused"]').click();
    await page.getByRole('button', { name: 'Update Agent' }).click();

    await expect(page).toHaveURL(/\/accounts\/[^/]+\/agents$/);
    await expect(page.getByText(/Agent updated/)).toBeVisible();

    const state = await getRunState(request, setup.run_id);
    expect(state.agents).toContainEqual(
      expect.objectContaining({
        name: 'E2E Refactor Sentinel',
        system_prompt: 'You are an E2E sentinel guarding refactors.',
        paused: true,
        refinement_threshold: 0.85,
      })
    );
  });
});
