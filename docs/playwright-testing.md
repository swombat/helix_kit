# Browser Testing Guide

This document covers how to use the `agent-browser` skill for testing and interacting with the application during development.

## Overview

Use the `agent-browser` skill (invoke with `/agent-browser`) to navigate to pages, test them, take screenshots, etc.

To navigate anywhere, first you need to open a tab. Then you can navigate it wherever you want.

**NEVER GUESS THE URL.** Use a route helper if you must, but ideally, click on links in the app. Most of the time when you try to guess the URL you will get it wrong (it happens all the time, even with this instruction...). So instead, log in and let it show you the default page, and then use the navigation controls on-page to get where you want to be.

When you check a page is working, ALWAYS check the contents, not just the 200 response code! Just because it shows something doesn't mean it's working. Check that it's not an error page! Error pages are very long because they include debugging code and a REPL console. You can identify it's an error page because it contains the string `templates/rescues/diagnostics.html.erb` near the top. You can grab all the information you actually care about by grabbing the contents of the `<main role="main" id="container">` element. Anything outside can safely be ignored.

## Application Details

- The app is running on **http://localhost:3100** - not https!
- If you need to restart it, don't - just ask the user to restart it for you.

## Logging In

**Note: The browser session may already be logged in when you start.** Check if you're already on a logged-in page before attempting to log in.

To log into the application (if not already logged in):
1. Navigate to `http://localhost:3100`
2. Fill the email field: `input[type="email"]` with `daniel@granttree.co.uk`
3. Fill the password field: `input[type="password"]` with `password`
4. Click the submit button: `button[type="submit"]`

## Debugging

**When selectors aren't working or timing out:** The page may have a server error (500, routing errors, etc.). Always take a screenshot or reload the page to check if there's an error page being displayed instead of the expected content. If selectors are timing out, it's often because the page has an error and the expected elements don't exist.

## Screenshots

Save screenshots in the `~/Downloads/screenshots/` directory. This directory already exists. Use the snap-happy MCP to take screenshots.
