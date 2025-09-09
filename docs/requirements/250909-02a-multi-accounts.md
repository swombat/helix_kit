# Multi-Account Support

So, right now we have the concept of personal accounts and team accounts, and people can be invited to team accounts, and perhaps someone who joins as a personal account and then gets invited to a team account can be in both.

But we really need to make this a little bit more flexible, to enable full multi account support.

Here are the requirements:

1. Users can only ever have one or zero personal accounts. Never two or more.
2. Users can have any number of team accounts.
3. Users can be invited to team accounts.
4. No one can be invited to a personal account.
5. When someone is invited directly to a team account, they don't get a personal account automatically, but there should be a way for them to create one.
6. There should be some kind of account switcher in the interface. Perhaps when clicking on the account name in the dropdown, if there are multiple accounts, it then shows a further dropdown of available accounts.

First, I want you to design and implement any required backend changes. Ideally this remains RESTful, with as few custom methods as possible. We don't set a "sticky" Current Account - that's always passed as part of the URL string, like, all account-specific routes are like `/accounts/gNDMev/resource/fhaseF`, so a request has a current account but it's not session-based.

Once the backend changes are implemented, please create/adjust the required views in Svelte. We want to keep this clear and minimal, there should not be a need for a lot of views here. Just a way to view what accounts you're in, create a personal account if it's missing, create more team accounts, switch between them. We already have a way to convert team<->personal when allowed.

