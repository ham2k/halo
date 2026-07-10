# Issues

* Do data files work on web? 

# Features

## Basic

- QSO selection and editing, including a "more" secondary control and a full form view similar to the one on app-polo.

## Exports

Operation Exports Panel: Provide a list of exports as suggested by extensions, allow selecting multiple exports and saving them to disk (or share, in mobile platforms). Display a summary of sync status for the operation and qsos.

## Activities

Operation Activities View: List the activities/references in the operation. If the operation has start, break or end events, display them as headers on the list. Each ref gets its own row. Use a fab to add new activities, or to add breaks.

Start, end and break events allow editing their times

Implement a

## Location

Implement the location options in the Operation Settings Panel

### Status bar

A status bar on the bottom of the screen, which in mobile apps is hidden unless there is important information to display.  It can show transient single line text messages, progress bars, or notices. Each can have an icon, a title and markdown text. Notices can have richer content, multi-line text, and action buttons (see app-polo for examples). 

Extensions and app components can add messages programmatically, and messages and progress status can have a key (prefixed with the extension key automatically, extensions cannot modify other extension messages) that allows them to update or remove existing messages.

If there are multiple items active, it shows the last one but can be tapped to expand it and see at least five lines in a scrollable area. If there are notices, they are displayed as a stack of post-it like rectangles on top of the rest of the active items scrollable area.

On the settings screen, in the about section, there should be a link to a screen that shows "Recent Notices" where they are still displayed as post-it notes but one after another, with most recent on top.
