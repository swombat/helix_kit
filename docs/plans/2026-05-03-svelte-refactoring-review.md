# Svelte Refactoring Review

Date: 2026-05-03

Status: Review plan only. No refactoring has been performed.

## Goal

Reduce the sprawl in app-owned Svelte files while keeping the Inertia page metaphor intact. Pages should remain recognizable as pages: they receive server props, subscribe to page-level data, coordinate high-level flows, and compose smaller pieces. They should not become tiny routers around a maze of opaque components.

The extraction target is the repeated or independently testable work currently embedded inside pages: tab bodies, drawers, cards, lists, modal forms, URL/filter state, optimistic UI logic, and shared formatting helpers.

## Scope

Reviewed app-owned Svelte files under:

- `app/frontend/pages`
- `app/frontend/layouts`
- `app/frontend/lib/components`, excluding generated shadcn primitives

Out of scope for this plan:

- `app/frontend/lib/components/shadcn/**`: generated/vendor-style primitives. Leave them alone unless upgrading shadcn.
- `app/frontend/test/__mocks__/Link.svelte`: test fixture.

## Current Shape

The Svelte layer is already halfway through a healthy refactor. Chat state has several tested plain JS helpers:

- `app/frontend/lib/chat-message-state.js`
- `app/frontend/lib/chat-streaming-state.js`
- `app/frontend/lib/chat-sync-subscriptions.js`
- `app/frontend/lib/chat-message-formatting.js`
- `app/frontend/lib/file-upload-rules.js`

That is the right direction. The next pass should do the same for other domains: keep domain logic testable in plain JS where possible, and make Svelte components mostly responsible for rendering and local interaction.

## Refactoring Rules

1. Keep pages as orchestration boundaries.
  A page should still show the page structure at a glance: page header, major regions, forms/dialogs, and route submissions.
2. Extract sections, not everything.
  Good extraction candidates are repeated panels, tab bodies, modal bodies, list rows, filter bars, and self-contained widgets.
3. Move pure logic to JS modules before moving markup.
  Filtering, grouping, token warning levels, icon lookup, form defaults, URL param serialization, and formatting helpers should be ordinary functions with Vitest coverage.
4. Prefer existing Rails/Inertia route helpers.
  Several components still use literal paths. When touching them, use generated route helpers where they exist, and keep route ownership obvious.
5. Do not fight shadcn.
  Components can wrap shadcn primitives for app-specific patterns, but should not fork the primitives.
6. Add tests where extraction creates a natural boundary.
  Component tests are useful for widgets, but the highest-value tests here are plain JS tests for logic extracted from pages.

## Priority Order

### P0 - First Refactoring Slice

These files carry multiple responsibilities and should be tackled first.

1. `app/frontend/pages/agents/edit.svelte` - 960 lines
  Most egregious page. It contains tab navigation, five tab bodies, form defaults, model lookup, tool toggling, Telegram actions, memory filtering, memory creation, memory refinement, and memory card rendering.
2. `app/frontend/pages/documentation.svelte` - 1030 lines
  Largest file. It is mostly content and code examples, so it is less behaviorally risky than the agent editor, but it is structurally the least maintainable.
3. `app/frontend/pages/chats/show.svelte` - 870 lines
  Already improved by tested helper modules and chat components, but still owns message pagination, sync, streaming, scroll behavior, retries, editing, deletion, voice, dialogs, toasts, and composition.
4. `app/frontend/pages/agents/index.svelte` - 530 lines
  Combines agent cards, create form, upgrade modal, model/tool/color/icon selectors, icon registry, and actions. It also duplicates logic from the edit page.
5. `app/frontend/pages/admin/audit-logs.svelte` - 478 lines
  Filter parsing/serialization, multi-select rendering, date range UI, table rows, drawer detail sections, JSON highlighting, and sync all live in one file.
6. `app/frontend/pages/chats/new.svelte` - 403 lines
  Duplicates agent icon registry and model/agent selection with other chat/agent screens. It also contains chat composer-like behavior that overlaps with `MessageComposer`.
7. `app/frontend/lib/components/navigation/navbar.svelte` - 397 lines
  This is a global component, but it has page-level complexity: public nav, desktop nav, mobile menu, admin menu, account switcher, integrations menu, user menu, search, logout, and theme persistence.
8. `app/frontend/lib/components/chat/ChatHeader.svelte` - 385 lines
  It is already a component, but it is too broad. Title editing, token display, chat actions, admin actions, moderation, archive/delete, fork, web access, and dialog triggers are independent concerns.

### P1 - Second Slice

These are not as severe, but they would become cleaner once the P0 shared components exist.

- `app/frontend/pages/accounts/show.svelte` - 339 lines
- `app/frontend/pages/chats/ChatList.svelte` - 303 lines
- `app/frontend/pages/home.svelte` - 299 lines
- `app/frontend/pages/whiteboards/index.svelte` - 263 lines
- `app/frontend/pages/accounts/convert_confirmation.svelte` - 251 lines
- `app/frontend/lib/components/chat/MessageBubble.svelte` - 243 lines
- `app/frontend/pages/admin/accounts.svelte` - 238 lines
- `app/frontend/lib/components/chat/AgentTriggerBar.svelte` - 181 lines
- `app/frontend/lib/components/chat/WhiteboardDrawer.svelte` - 180 lines
- `app/frontend/lib/components/chat/MessageComposer.svelte` - 168 lines
- `app/frontend/pages/admin/settings.svelte` - 158 lines
- `app/frontend/lib/components/AvatarUpload.svelte` - 157 lines

### P2 - Opportunistic Cleanup

These are small enough to leave alone until nearby work touches them, except where they duplicate a new shared component.

- Integration pages: GitHub, Oura, X, GitHub repo selection
- API key pages
- Auth/password/registration pages
- Form wrapper components
- Small chat widgets such as file attachment, toast, image lightbox, debug panel
- Layouts and logos

## Proposed Shared Extracts

### Agent UI

Create an agent component/helper area:

- `app/frontend/lib/components/agents/AgentCard.svelte`
- `app/frontend/lib/components/agents/AgentFormFields.svelte`
- `app/frontend/lib/components/agents/AgentModelSelect.svelte`
- `app/frontend/lib/components/agents/AgentToolChecklist.svelte`
- `app/frontend/lib/components/agents/AgentAppearanceFields.svelte`
- `app/frontend/lib/components/agents/AgentMemoryPanel.svelte`
- `app/frontend/lib/components/agents/AgentMemoryCard.svelte`
- `app/frontend/lib/components/agents/AgentMemoryFilters.svelte`
- `app/frontend/lib/components/agents/AgentTelegramPanel.svelte`
- `app/frontend/lib/components/agents/AgentUpgradeDialog.svelte`
- `app/frontend/lib/agent-icons.js`
- `app/frontend/lib/agent-models.js`
- `app/frontend/lib/agent-memory.js`

High-value tests:

- `agent-models.test.js`: model grouping, label lookup, thinking support.
- `agent-memory.test.js`: filtering, journal opacity, token summary display values.
- `agent-icons.test.js`: accepted icon lookup/fallback.

### Chat UI

Keep `pages/chats/show.svelte` as the chat room orchestrator, but extract the remaining page internals:

- `app/frontend/lib/components/chat/MessageList.svelte`
- `app/frontend/lib/components/chat/MessageTimestampDivider.svelte`
- `app/frontend/lib/components/chat/ChatStatusPlaceholders.svelte`
- `app/frontend/lib/components/chat/TokenWarningBanner.svelte`
- `app/frontend/lib/components/chat/ChatDialogs.svelte`
- `app/frontend/lib/components/chat/ChatSidebarFilters.svelte`
- `app/frontend/lib/chat-pagination-state.js`
- `app/frontend/lib/chat-scroll-state.js`
- `app/frontend/lib/chat-actions.js` where shared route/fetch helpers make sense.

High-value tests:

- Pagination merge/dedupe and oldest-id handling.
- Scroll threshold decisions without DOM.
- Token warning level calculation reused by page and header.

### Admin Tables

Create reusable admin/table pieces:

- `app/frontend/lib/components/admin/ResourceSplitView.svelte`
- `app/frontend/lib/components/admin/AuditLogFilters.svelte`
- `app/frontend/lib/components/admin/AuditLogTable.svelte`
- `app/frontend/lib/components/admin/AuditLogDrawer.svelte`
- `app/frontend/lib/components/admin/AuditLogDetailSection.svelte`
- `app/frontend/lib/components/admin/AccountList.svelte`
- `app/frontend/lib/components/admin/AccountDetails.svelte`
- `app/frontend/lib/admin-audit-log-filters.js`

High-value tests:

- Audit filter initialization from query props.
- Audit filter URL serialization, including empty filter removal.
- Account search matching.

### Settings/Integrations

The GitHub, Oura, and X pages repeat a lot of connection-status structure.

Create:

- `app/frontend/lib/components/settings/IntegrationPage.svelte`
- `app/frontend/lib/components/settings/IntegrationStatusCard.svelte`
- `app/frontend/lib/components/settings/IntegrationSettingsCard.svelte`
- `app/frontend/lib/integration-actions.js`

Keep each page as the page, passing provider-specific copy, icon, routes, and enabled setting payload.

### General UI

Create a few app-level components only where they remove repeated code:

- `PageHeader.svelte`: title, subtitle, optional actions.
- `EmptyState.svelte`: icon, title, body, optional action.
- `DataListShell.svelte`: split list/detail page shell.
- `FlashMessages.svelte`: success/notice/alert rendering from `$page.props.flash`.
- `CodeBlock.svelte`: highlight wrapper used by documentation and audit logs.

Avoid creating a generic `FormField` abstraction unless repetition becomes real after the first pass. Many current fields are different enough that a generic wrapper may make them harder to read.

## File-by-File Evaluation

### Pages

#### `app/frontend/pages/documentation.svelte`

Problem:

- Giant content file with many inline code example constants.
- Page markup, navigation/sections, code block rendering, and documentation content are inseparable.
- Editing any single documentation section requires scrolling through the whole file.

Plan:

- Extract code examples to `app/frontend/lib/documentation-examples.js`.
- Extract `DocumentationSection.svelte`, `DocumentationCodeBlock.svelte`, and maybe `FeatureDocCard.svelte`.
- Keep the page as the table of contents and section ordering.
- Add a small test for example exports if they are transformed or indexed; otherwise no test needed.

Priority: P0 because of size and editing friction, despite low runtime complexity.

#### `app/frontend/pages/agents/edit.svelte`

Problem:

- The page is doing everything: tab system, form setup, model/tool helpers, Telegram actions, memory CRUD, memory filtering, refinement menu, and all tab markup.
- It duplicates model/tool/color/icon concepts with `agents/index.svelte` and chat creation.
- Memory filtering and opacity are testable logic but live inside the page.

Plan:

- Keep the page responsible for receiving props, creating the Inertia form, saving the agent, and deciding active tab.
- Extract tab navigation to `AgentEditTabs.svelte`.
- Extract tab bodies: `AgentIdentityTab`, `AgentAppearanceTab`, `AgentModelTab`, `AgentIntegrationsTab`, `AgentMemoryTab`.
- Extract memory helpers to `agent-memory.js`.
- Extract model helpers to `agent-models.js`.
- Extract reusable `AgentModelSelect` and `AgentToolChecklist`.
- Replace the custom refinement dropdown with the existing dropdown menu primitives.
- After extraction, the page should read as form setup plus tab composition.

Priority: P0, first target.

#### `app/frontend/pages/chats/show.svelte`

Problem:

- The page has already had logic pulled into tested helpers, but it still contains too many independent workflows.
- Message pagination, scroll preservation, streaming safety refresh, transient toasts, retry/resend, voice generation, edit/delete, assign/add-agent dialogs, and message list rendering are all in the page.
- Some helper behavior is DOM-bound, but much of the decision logic can still be tested outside Svelte.

Plan:

- Keep the page as `ChatRoom`: props, sync setup, high-level state, and composition.
- Extract `MessageList.svelte` for loading earlier messages, empty state, timestamp dividers, bubbles, thinking/sending placeholders.
- Extract `TokenWarningBanner.svelte`.
- Extract `ChatDialogs.svelte` or keep the dialogs in the page if that reads clearer; the key is to pull out repeated dialog wiring.
- Move pagination merge/state helpers to `chat-pagination-state.js`.
- Move scroll decision helpers to `chat-scroll-state.js`, leaving actual DOM scrolling in the component.
- Consider moving `messageVoicePath` once route generation includes it.

Priority: P0, after agent edit.

#### `app/frontend/pages/agents/index.svelte`

Problem:

- The page mixes list rendering, create modal, upgrade modal, icon registry, model helpers, tool checklist, color/icon pickers, and agent actions.
- Duplicates `findModelLabel`, `toggleTool`, and model select markup from edit.
- The icon import/registry is repeated in multiple files.

Plan:

- Extract `AgentCard.svelte`.
- Extract `CreateAgentDialog.svelte`.
- Extract `AgentUpgradeDialog.svelte`.
- Move icon lookup to `agent-icons.js`.
- Reuse `AgentModelSelect`, `AgentToolChecklist`, and `AgentAppearanceFields`.
- Keep page ownership of sync, create/delete/upgrade actions, and showing modals.

Priority: P0.

#### `app/frontend/pages/admin/audit-logs.svelte`

Problem:

- Filter query state, date picker setup, URL serialization, table display, pagination, selected drawer, and detail cards are all together.
- The multi-select trigger rendering is repeated four times with only source data changed.
- Debug logging remains in the component.

Plan:

- Extract pure filter parsing/serialization to `admin-audit-log-filters.js`.
- Extract `AuditLogFilters.svelte` with a small `MultiSelectFilter.svelte`.
- Extract `AuditLogTable.svelte`.
- Extract `AuditLogDrawer.svelte` and detail sections.
- Keep page responsible for props, sync subscriptions, URL navigation, and selected drawer open/close.
- Remove debug logging or gate it consistently.

Priority: P0.

#### `app/frontend/pages/chats/new.svelte`

Problem:

- Duplicates agent icon registry and model grouping/selection logic.
- Combines chat creation state, model/agent selector, group-chat agent chips, file upload, textarea autosize, and sidebar shell.
- Overlaps with `MessageComposer` but is not the same because it creates the chat.

Plan:

- Extract `ChatTargetSelect.svelte` for the combined agent/model picker.
- Extract `GroupChatAgentPicker.svelte`.
- Move model grouping to `agent-models.js` or `chat-targets.js`.
- Reuse `agent-icons.js`.
- Consider a shared `ChatTextarea.svelte` used by both `new.svelte` and `MessageComposer`.
- Keep page responsible for building `FormData` and posting `accountChatsPath`.

Priority: P0.

#### `app/frontend/pages/chats/ChatList.svelte`

Problem:

- This lives under `pages` but behaves like a shared chat component.
- Duplicates agent icon registry.
- Owns URL query toggles for deleted/agent-only filters.
- Renders chat row, group participant avatars, status markers, model/date/token/message counts in one component.

Plan:

- Move to `app/frontend/lib/components/chat/ChatList.svelte` once imports are updated.
- Extract `ChatListRow.svelte`.
- Extract `ChatListFilters.svelte`.
- Reuse `ParticipantAvatars` or introduce a smaller `ParticipantStack` for chat list rows.
- Move URL query toggle helpers to a small helper if tested value is worthwhile.

Priority: P1, but move early if touching chat pages.

#### `app/frontend/pages/chats/search.svelte`

Problem:

- Small enough, but contains custom HTML escaping/highlighting and search/pagination navigation.
- Highlighting logic is testable and security-sensitive.

Plan:

- Move `escapeHtml` and `highlightMatch` to `chat-search-highlighting.js` with tests.
- Consider extracting `ChatSearchResults.svelte` only if the page grows.

Priority: P2.

#### `app/frontend/pages/chats/index.svelte`

Problem:

- Small page, but likely overlaps with `chats/new.svelte` model selection and create-chat behavior.

Plan:

- After extracting model select helpers, update this page to reuse them.
- Otherwise leave it as a simple page.

Priority: P2.

#### `app/frontend/pages/home.svelte`

Problem:

- Content arrays plus feature card rendering live in the page.
- It is reasonably readable, but adding features means editing a long list in the Svelte file.

Plan:

- Move feature arrays to `home-features.js`.
- Extract `FeatureGrid.svelte` and `FeatureCard.svelte`.
- Keep page layout and hero in the page.

Priority: P1.

#### `app/frontend/pages/whiteboards/index.svelte`

Problem:

- List/detail/edit/conflict-resolution behavior is all in one file.
- Whiteboard conflict save logic duplicates the same shape as `WhiteboardDrawer.svelte`.
- Uses literal routes.

Plan:

- Extract `WhiteboardList.svelte`, `WhiteboardViewer.svelte`, `WhiteboardEditor.svelte`, and `WhiteboardConflictBanner.svelte`.
- Move save/conflict helper to `whiteboard-save.js` if it can be shared with `WhiteboardDrawer`.
- Keep the page as the list/detail layout and selected whiteboard URL owner.
- Use generated routes when available.

Priority: P1.

#### `app/frontend/pages/accounts/show.svelte`

Problem:

- Account information, usage, team members, pending invitations, invite form, flash rendering, and conversion state live together.
- Flash rendering is repeated elsewhere.
- Member and pending-invitation table rows are natural components.

Plan:

- Extract `FlashMessages.svelte`.
- Extract `AccountSummaryCards.svelte`, `TeamMembersTable.svelte`, `PendingInvitationsTable.svelte`, and `AccountTypeCard.svelte`.
- Keep page responsible for account props, invite/remove/resend actions, and conversion navigation.

Priority: P1.

#### `app/frontend/pages/accounts/edit.svelte`

Problem:

- Small wrapper around `Form.svelte`, but uses `$page.props` rather than explicit `$props`, unlike most pages.

Plan:

- Leave mostly alone.
- Consider explicit props for consistency if touching account form flow.

Priority: P2.

#### `app/frontend/pages/accounts/convert_confirmation.svelte`

Problem:

- Medium-sized confirmation page, likely contains several repeated account conversion detail blocks.

Plan:

- Extract only if markup has repeated warning/summary blocks.
- Otherwise leave as a page; confirmation pages are allowed to be explicit.

Priority: P1/P2 depending on future account work.

#### `app/frontend/pages/admin/accounts.svelte`

Problem:

- Split list/detail admin view with search, sync, selected account routing, details cards, and users table.
- Similar layout to audit logs and potentially other admin screens.

Plan:

- Extract `AccountList.svelte` and `AccountDetails.svelte`.
- Move search predicate to `admin-account-search.js` if reused/tested.
- Consider a shared split-view shell after both audit logs and accounts have been cleaned up.

Priority: P1.

#### `app/frontend/pages/admin/settings.svelte`

Problem:

- Moderate length settings form. Likely fine unless it repeats card/field patterns from integrations.

Plan:

- Leave until settings grow.
- If touched, extract a provider-neutral settings section component only after a second settings page needs it.

Priority: P2.

#### `app/frontend/pages/admin/jobs.svelte`

Problem:

- Small admin page. No urgent refactor.

Plan:

- Leave unless adding more job controls.

Priority: P2.

#### `app/frontend/pages/api_keys/index.svelte`

Problem:

- Page contains create form, key list, delete action, and API documentation block.
- The API documentation block is content-heavy and may grow separately from key management.

Plan:

- Extract `ApiKeyCreateForm.svelte`, `ApiKeyList.svelte`, and `ApiUsageInstructions.svelte` if the page grows.
- For now, the best immediate cleanup is moving the API endpoint list to data.

Priority: P2.

#### `app/frontend/pages/api_keys/show.svelte`, `approve.svelte`, `approved.svelte`

Problem:

- Small flow pages. They may share approval-state layout but are not currently a major pain.

Plan:

- Leave alone unless API key approval flow is being redesigned.

Priority: P2.

#### `app/frontend/pages/settings/github_integration.svelte`

Problem:

- Repeats connection status, native OAuth POST, disconnect, enabled toggle, sync-now state, and settings card patterns used by Oura/X.
- Has GitHub-specific repo selection behavior.

Plan:

- Use shared integration status/settings components.
- Keep GitHub-specific repository actions in the page or pass them as snippets/children.

Priority: P2, but high payoff if doing settings cleanup.

#### `app/frontend/pages/settings/oura_integration.svelte`

Problem:

- Same structure as GitHub integration with different copy/routes.

Plan:

- Reuse shared integration components and helper for native OAuth form POST.

Priority: P2.

#### `app/frontend/pages/settings/x_integration.svelte`

Problem:

- Same integration shape, smaller because there is no sync action.

Plan:

- Reuse shared integration components.

Priority: P2.

#### `app/frontend/pages/settings/github_select_repo.svelte`

Problem:

- Small page. Could reuse `PageHeader` and form shell after integration cleanup.

Plan:

- Leave until GitHub integration UI is refactored.

Priority: P2.

#### Auth, User, Password, Registration Pages

Files:

- `registrations/new.svelte`
- `registrations/check_email.svelte`
- `registrations/confirm_email.svelte`
- `registrations/set_password.svelte`
- `sessions/new.svelte`
- `passwords/new.svelte`
- `passwords/edit.svelte`
- `user/edit.svelte`
- `user/edit_password.svelte`

Problem:

- Mostly thin page wrappers around existing form components.
- `confirm_email.svelte` has client-side confirmation behavior that could be reviewed separately, but not for component sprawl.

Plan:

- Leave as pages.
- Use `AuthLayout` and existing forms consistently.
- Only extract confirmation status UI if another confirmation flow appears.

Priority: P2.

#### `privacy.svelte` and `terms.svelte`

Problem:

- Content pages. Length is acceptable, and component extraction would likely hide static content without improving behavior.

Plan:

- Leave alone unless converting legal/policy content to Markdown.

Priority: P2.

### Components

#### `app/frontend/lib/components/navigation/navbar.svelte`

Problem:

- Global component contains several separate menus and behaviors.
- Theme persistence, account switching, admin nav, user menu, guest menu, mobile nav, integrations nav, and search are mixed.

Plan:

- Extract `MainNavLinks.svelte`, `MobileNavMenu.svelte`, `AdminMenu.svelte`, `AccountSwitcher.svelte`, `UserMenu.svelte`, `GuestMenu.svelte`, `ThemeMenu.svelte`, and `NavSearch.svelte`.
- Move theme persistence helper to `theme-preferences.js`.
- Keep `navbar.svelte` as the top-level composition and source of `$page.props`.

Priority: P0.

#### `app/frontend/lib/components/chat/ChatHeader.svelte`

Problem:

- Broad component with local editing state, route mutations, dropdown menu, token display, admin actions, moderation request, archive/delete, fork, web access, and dialog triggers.

Plan:

- Extract `ChatTitleEditor.svelte`.
- Extract `ChatTokenStatus.svelte` and share token warning calculation with the page.
- Extract `ChatActionsMenu.svelte`.
- Consider moving mutations to callbacks provided by the page so this component becomes more render-focused.

Priority: P0.

#### `app/frontend/lib/components/chat/MessageBubble.svelte`

Problem:

- Handles user and assistant rendering in one file, including markdown, files, moderation, audio, retries, voice, thinking, tool use, and action buttons.
- Some duplication exists between user and assistant metadata rows.

Plan:

- Extract `MessageActions.svelte`, `MessageMeta.svelte`, `MessageContent.svelte`, and maybe `VoiceControls.svelte`.
- Do not split user/assistant bubbles until shared subcomponents are extracted; otherwise duplication may get worse.
- Keep the public API stable for `chats/show.svelte`.

Priority: P1.

#### `app/frontend/lib/components/chat/MessageComposer.svelte`

Problem:

- Reasonable size, but it owns form setup, fetch submission, file uploads, transcription callbacks, textarea autosize, and error handling.
- Overlaps with `chats/new.svelte`.

Plan:

- Extract shared `ChatTextarea.svelte`.
- Extract send-message request construction to a helper if it can be tested without Inertia.
- Keep as a component; no page-level concern here.

Priority: P1.

#### `app/frontend/lib/components/chat/WhiteboardDrawer.svelte`

Problem:

- Duplicates whiteboard edit/save/conflict behavior from `whiteboards/index.svelte`.

Plan:

- Share `WhiteboardEditor` and `WhiteboardConflictBanner`.
- Consider a `saveWhiteboard` helper returning `{ ok, conflict, error }`.

Priority: P1.

#### `app/frontend/lib/components/chat/AgentTriggerBar.svelte`

Problem:

- Agent grouping/rendering/action bar is moderately complex.
- Likely duplicates agent icon/colour rendering.

Plan:

- Reuse `agent-icons.js` and maybe `AgentChip.svelte`.
- Leave overall component shape intact.

Priority: P1.

#### `app/frontend/lib/components/chat/ParticipantAvatars.svelte`

Problem:

- Has icon registry and participant display logic that overlaps with `ChatList`.

Plan:

- Reuse `agent-icons.js`.
- Consider splitting a small `ParticipantAvatar.svelte` if reused in chat list rows.

Priority: P1.

#### `app/frontend/lib/components/chat/MicButton.svelte`

Problem:

- Browser media recording/transcription logic is hard to unit test as-is.

Plan:

- Leave UI component intact unless changing speech-to-text.
- If touched, move MIME selection and transcription request payload building to helpers.

Priority: P2.

#### `app/frontend/lib/components/chat/AudioPlayer.svelte`

Problem:

- Self-contained custom player. Fine.

Plan:

- Leave unless adding accessibility/keyboard controls.

Priority: P2.

#### `app/frontend/lib/components/chat/FileUploadInput.svelte`

Problem:

- Already uses file-upload helper tests elsewhere. Component is acceptable.

Plan:

- Leave unless adding drag/drop validation UI.

Priority: P2.

#### `app/frontend/lib/components/chat/FileAttachment.svelte`

Problem:

- Small component with file icon and size formatting.

Plan:

- Move `formatFileSize` to an existing utility only if reused elsewhere.

Priority: P2.

#### Small Chat Components

Files:

- `AgentPickerDialog.svelte`
- `DebugPanel.svelte`
- `EditMessageDrawer.svelte`
- `ImageLightbox.svelte`
- `TelegramBanner.svelte`
- `ThinkingBlock.svelte`
- `ToastNotification.svelte`
- `ModerationIndicator.svelte`

Plan:

- Leave mostly alone.
- `EditMessageDrawer` can share route helpers if message routes are generated.
- `ModerationIndicator` formatting can move to a helper if moderation categories appear elsewhere.

Priority: P2.

#### Form Components

Files:

- `Form.svelte`
- `LoginForm.svelte`
- `SignupForm.svelte`
- `SetPasswordForm.svelte`
- `ResetPasswordForm.svelte`
- `EditPasswordForm.svelte`
- `ChangePasswordForm.svelte`
- `UserSettingsForm.svelte`
- `InviteMemberForm.svelte`
- `ResendConfirmation.svelte`

Problem:

- Generally already componentized.
- Some may duplicate label/input/error markup, but they are not the source of current page sprawl.

Plan:

- Leave during the first pass.
- Revisit after page refactors reveal a real repeated field pattern.

Priority: P2.

#### General Components

Files:

- `Alert.svelte`
- `Avatar.svelte`
- `AvatarUpload.svelte`
- `ColourPicker.svelte`
- `IconPicker.svelte`
- `InfoCard.svelte`
- `PaginationNav.svelte`
- logo components

Plan:

- `AvatarUpload.svelte`: extract upload/delete request helpers if adding tests.
- `ColourPicker.svelte` and `IconPicker.svelte`: keep; reuse more broadly in agent components.
- `InfoCard.svelte` and `PaginationNav.svelte`: keep; they are already useful app primitives.
- `Alert.svelte`: consider replacing bespoke flash rendering with `FlashMessages.svelte`.
- Logos/layouts: leave alone.

Priority: P2.

## Suggested Execution Plan

### Phase 1: Shared Agent Foundations

1. Add `agent-icons.js`, `agent-models.js`, and `agent-memory.js` with Vitest tests.
2. Refactor `agents/edit.svelte` memory tab into components.
3. Refactor remaining `agents/edit.svelte` tabs.
4. Refactor `agents/index.svelte` to reuse the same model/tool/appearance components.
5. Update `chats/new.svelte`, `ChatList`, and `ParticipantAvatars` to use `agent-icons.js`.

Reason: this pays down the worst page first and removes duplication that affects chat screens too.

### Phase 2: Chat Room Shell

1. Extract token warning helper and banner.
2. Extract message list and placeholders from `chats/show.svelte`.
3. Extract pagination/scroll helper tests.
4. Split `ChatHeader` into title, token status, and actions menu.
5. Move `ChatList` out of `pages` and split rows/filters.

Reason: chat is central and already has good helper tests; continue that direction carefully.

### Phase 3: Admin and Whiteboards

1. Refactor audit log filters with tested URL serialization.
2. Extract audit table and drawer.
3. Extract admin account split-view pieces.
4. Share whiteboard editor/conflict UI between page and drawer.

Reason: these are self-contained areas with clear component boundaries.

### Phase 4: Content and Settings

1. Split `documentation.svelte` into data/examples/section components.
2. Move `home.svelte` feature data out of the component.
3. Create integration status/settings components and update GitHub/Oura/X pages.
4. Add small app primitives such as `PageHeader`, `EmptyState`, and `FlashMessages` only where the previous phases prove they are useful.

## Definition of Done

For each refactoring slice:

- The Inertia page remains easy to read as a page.
- Existing tests still pass.
- New pure helper modules have Vitest coverage.
- Extracted components have narrow props and no hidden `$page` dependency unless they are explicitly navigation/global components.
- Route mutations remain obvious from the page or from clearly named action components.
- No broad visual redesign is mixed into the refactor.

## Progress Checkpoint: 2026-05-03

Status: Phase 1 is partially implemented and green. This is a good commit checkpoint before continuing with the remaining `agents/edit.svelte` tabs.

Completed:

- Added shared agent helper modules with Vitest coverage:
  - `app/frontend/lib/agent-icons.js`
  - `app/frontend/lib/agent-models.js`
  - `app/frontend/lib/agent-memory.js`
- Extracted shared agent UI components:
  - `AgentModelSelect.svelte`
  - `AgentToolChecklist.svelte`
  - `AgentAppearanceFields.svelte`
  - `AgentCard.svelte`
  - `CreateAgentDialog.svelte`
  - `AgentUpgradeDialog.svelte`
  - `AgentSettingsTabs.svelte`
  - `AgentMemoryPanel.svelte`
- Refactored `agents/index.svelte` to keep page orchestration while moving card and dialog UI into components.
- Refactored `agents/edit.svelte` to move tab navigation and the memory panel into components.
- Updated `chats/new.svelte`, `ChatList.svelte`, `AgentTriggerBar.svelte`, and `ParticipantAvatars.svelte` to reuse shared agent model/icon helpers.
- Added a small Playwright assertion to the existing agent settings smoke test so the extracted Memory tab is rendered during E2E coverage.

Current size notes:

- `app/frontend/pages/agents/index.svelte`: 182 lines after extraction.
- `app/frontend/pages/agents/edit.svelte`: 555 lines after extraction, down from 878 lines before the memory/tab split.
- `AgentMemoryPanel.svelte` is intentionally still a substantial component at about 300 lines; it is a clearer boundary than keeping the whole memory workflow inside the page, but it remains a candidate for a later split into memory filters, new memory form, and memory list/card components.

Last verified test baseline:

- `yarn test:unit`: 10 files, 29 tests passed.
- `bin/vite build --mode test`: passed, with existing Svelte warnings unrelated to this slice.
- `yarn test`: 5 Playwright tests passed.
- `bin/rails test`: 1815 tests, 7329 assertions, 0 failures, 0 errors.

Known notes:

- Rails tests can dirty VCR cassettes during this work; restore generated cassette churn before committing unless a cassette was intentionally changed.
- The Vite build still reports pre-existing warnings in areas such as `chats/index.svelte`, `InfoCard.svelte`, `ChatHeader.svelte`, `ColourPicker.svelte`, `IconPicker.svelte`, `FileAttachment.svelte`, and `AudioPlayer.svelte`.
- The next sensible Phase 1 slice is to continue reducing `agents/edit.svelte`, probably by extracting the Identity, Model, and Integrations panels one at a time with tests between each extraction.

## Progress Checkpoint: 2026-05-03 Continued

Status: The remaining large `agents/edit.svelte` tabs have been extracted and the test suite remains green.

Completed after commit `3381029 Refactor agent Svelte components`:

- Extracted `AgentIdentityPanel.svelte` from `agents/edit.svelte`.
- Extracted `AgentModelPanel.svelte` from `agents/edit.svelte`.
- Extracted `AgentIntegrationsPanel.svelte` from `agents/edit.svelte`.
- Kept `agents/edit.svelte` responsible for Inertia props, form initialization, route mutations, tab selection, and submit/cancel actions.

Current size notes:

- `app/frontend/pages/agents/edit.svelte`: 244 lines after the Identity, Model, and Integrations panel extractions.
- `AgentIdentityPanel.svelte`: 171 lines.
- `AgentModelPanel.svelte`: 69 lines.
- `AgentIntegrationsPanel.svelte`: 101 lines.

Last verified test baseline:

- `yarn test:unit`: 10 files, 29 tests passed.
- `bin/vite build --mode test`: passed, with existing Svelte warnings unrelated to this slice.
- `yarn test`: 5 Playwright tests passed.
- `bin/rails test`: 1815 tests, 7329 assertions, 0 failures, 0 errors.

Known notes:

- The VCR cassette append cleanup from commit `25acae3 Prevent VCR cassette appends` held during this pass; the full Rails suite did not leave cassette churn in the worktree.
- `AgentMemoryPanel.svelte` is still the largest extracted agent component and remains the next obvious candidate for a smaller split if the agent area needs more refinement.
- The `appearance` tab is already thin and currently delegates to `AgentAppearanceFields.svelte`; it does not need a separate panel unless future behavior is added.

## Progress Checkpoint: 2026-05-03 Memory Panel Split

Status: The `AgentMemoryPanel.svelte` split is implemented and green.

Completed after commit `3b6553c Extract agent edit panels`:

- Extracted `AgentMemoryCard.svelte` from `AgentMemoryPanel.svelte`.
- Extracted `AgentNewMemoryForm.svelte`.
- Extracted `AgentMemoryFilters.svelte`.
- Extracted `AgentMemorySummary.svelte`.
- Kept `AgentMemoryPanel.svelte` responsible for refinement actions, filter state, the filtered-memory derivation, and list orchestration.
- Extended the agent settings Playwright smoke test to open the memory form and assert the empty form cannot be submitted.

Current size notes:

- `AgentMemoryPanel.svelte`: 124 lines, down from about 300 lines when first extracted from `agents/edit.svelte`.
- `AgentMemoryCard.svelte`: 89 lines.
- `AgentNewMemoryForm.svelte`: 64 lines.
- `AgentMemoryFilters.svelte`: 41 lines.
- `AgentMemorySummary.svelte`: 28 lines.

Last verified test baseline for this slice:

- `yarn test:unit`: 10 files, 29 tests passed.
- `bin/vite build --mode test`: passed, with existing Svelte warnings unrelated to this slice.
- `yarn test`: 5 Playwright tests passed.
- `bin/rails test`: 1815 tests, 7329 assertions, 0 failures, 0 errors.

Next sensible slice:

- Move to the next P0 target in this plan: `documentation.svelte`, which is mostly structural/content extraction rather than interactive behavior.

## Progress Checkpoint: 2026-05-03 Documentation Examples

Status: The first `documentation.svelte` extraction is implemented and green.

Completed:

- Moved large inline code example strings from `documentation.svelte` to `app/frontend/lib/documentation-examples.js`.
- Added `DocumentationCodeBlock.svelte` so the page no longer imports `svelte-highlight` languages directly.
- Added a small Playwright smoke assertion for `/documentation` so this public page renders and shows a highlighted code example.

Current size notes:

- `app/frontend/pages/documentation.svelte`: 735 lines, down from 1030 lines.
- `app/frontend/lib/documentation-examples.js`: 310 lines.
- `DocumentationCodeBlock.svelte`: 12 lines.

Last verified test baseline for this slice:

- `yarn test:unit`: 10 files, 29 tests passed.
- `bin/vite build --mode test`: passed, with existing Svelte warnings unrelated to this slice.
- `yarn test`: 6 Playwright tests passed.
- `bin/rails test`: 1815 tests, 7329 assertions, 0 failures, 0 errors.

Next sensible slice:

- Extract documentation section shells such as quick navigation and the three large topic cards, while keeping the documentation page responsible for ordering the sections.

## Progress Checkpoint: 2026-05-03 Documentation Structure

Status: The documentation shell extraction is implemented and green.

Completed after commit `bc42500 Extract documentation examples`:

- Extracted `DocumentationQuickNavigation.svelte`.
- Extracted `DocumentationTopicCard.svelte` for the repeated section card/header/content shell.
- Kept `documentation.svelte` responsible for the page title, section order, and the substantive section content.

Current size notes:

- `app/frontend/pages/documentation.svelte`: 682 lines, down from 735 lines after the examples extraction and 1030 lines originally.
- `DocumentationQuickNavigation.svelte`: 43 lines.
- `DocumentationTopicCard.svelte`: 15 lines.

Last verified test baseline for this slice:

- `yarn test:unit`: 10 files, 29 tests passed.
- `bin/vite build --mode test`: passed, with existing Svelte warnings unrelated to this slice.
- `yarn test`: 6 Playwright tests passed.
- `bin/rails test`: 1815 tests, 7329 assertions, 0 failures, 0 errors.

Next sensible slice:

- Extract each large documentation topic body one at a time, starting with the real-time synchronization section.

## Progress Checkpoint: 2026-05-03 Documentation Realtime Section

Status: The first large documentation topic body extraction is implemented and green.

Completed after commit `54eace7 Extract documentation structure`:

- Extracted `RealtimeSyncDocumentation.svelte`.
- Moved realtime-specific imports (`Badge` and sync example constants) out of `documentation.svelte`.
- Kept `documentation.svelte` as the page-level ordering layer for the documentation topics.

Current size notes:

- `app/frontend/pages/documentation.svelte`: 446 lines, down from 682 lines after the structure extraction and 1030 lines originally.
- `RealtimeSyncDocumentation.svelte`: 243 lines.

Last verified test baseline for this slice:

- `yarn test:unit`: 10 files, 29 tests passed.
- `bin/vite build --mode test`: passed, with existing Svelte warnings unrelated to this slice.
- `yarn test`: 6 Playwright tests passed.
- `bin/rails test`: 1815 tests, 7329 assertions, 0 failures, 0 errors.

Next sensible slice:

- Extract `JsonAttributesDocumentation.svelte`, then `PromptSystemDocumentation.svelte`, leaving `documentation.svelte` as a short page that composes the documentation topics.
