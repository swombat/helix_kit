# Site Settings

Rather than have them set in ENV vars that are hard to change, I want some dynamic site settings to be configurable via the admin panel.

The site settings will include settings like the name of the site and the logo and functional toggles like whether to allow new user signups, whether to allow chats, etc.

## Rails side implementation

I think a Settings model will be a good fit for this. It doesn't belong to a specific Team, it is just global. Only site admins can access it, of course.

## Svelte side implementation

On the Svelte side I want an admin panel to edit the site settings.

It doesn't need to be extraordinarily complicated... just have a section for the site settings that includes at least the following settings for now:

- Site name
- Site logo (uploadable)
- Allow new user signups
- Allow chats
