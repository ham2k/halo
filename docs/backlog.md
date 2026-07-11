# Issues

* Do data files work on web?

# Features

## Secondary Controls

The time widget should show :00 if the qso data has no seconds

The user should be able to drag to scroll.

There should be a caret to expand the area into up to 4 rows of controls.

There should be a settings button at the end, which opens a dialog where the user can select which controls to show or hide. Time and Radio are not optional. Items in this dialog's list should have a grab handle that lets the user reorder them.

When in edit mode, the pills should display with a background color.

There should not be borders around the pills.

The extended area for secondary controls should have the same background color as the pills.

### Logging View Settings

A "..." menu on the top right of the logging view, with options to show/hide RST fields, state field, grid field, show deleted qsos and show numbers row.

### QSO Rows

* Number (Optional)
* Time - HH:MMz
* Frequency - Mhz bolded, then KHz regular weight, then, if needed, Hz regular weight in a smaller font size, all separated by periods.  For Hz, decide how many digits to display based on all the qsos in the operation and how many digits are needed to represent their Hz while padding zeroes on the right.  If no frequency is available, display mode.
* Mode - only if the qsos in the operation use more than one mode.
* Callsign - wide enough to fit the longest callsign in all qsos
* Emoji(s), Name - this row expands to use available space
* References - Using the icons from their extensions, with "x2" indicating multiple references of the same type.
* Exchange or RST

Add an option in the logging view settings menu to "Show QSO Numbers"


## Radio Service

Keep state of the radio(s) in use in the operation
Wire secondary controls to a state for "VFO" that provides `freq`, `mode` and `band` for up to 4 VFOs objects as `vfoA`, `vfoB`, `vfoC` and `vfoD`.

For now, we'll only use vfoA, but the structure allows for up to 4 VFOs to be used in the future.


## Exports

Operation Exports Panel: Provide a list of exports as suggested by extensions, allow selecting multiple exports and saving them to disk (or share, in mobile platforms). Display a summary of sync status for the operation and qsos.

## Activities

Operation Activities View: List the activities/references in the operation. If the operation has start, break or end events, display them as headers on the list. Each ref gets its own row. Use a fab to add new activities, or to add breaks.

Start, end and break events allow editing their times

Implement a view/dialog to manage the activities for the current operation. Tapping the activity opens a view to edit their details, based on a form definition provided by the extension, along with an option to remove the activity.

This view/dialog also has a list of suggestions provided by the extensions, which are given the current operation, including location and callsign, and above the list of suggestions there is a search bar. The search bar asks each extension to provide suggestions with the search term. Results are combined, sorted by distance multiplied by relevance (returned by the extension as part of the data). Finally followed, after a separator, by a list of active extensions



## Location

Implement the location options in the Operation Settings Panel


## Callsign Input

When switching between logging fields, the next field's text should not be selected, just the cursor placed at the end.

Callsign input should support call stacking.



### Status bar

A status bar on the bottom of the screen, which in mobile apps is hidden unless there is important information to display.  It can show transient single line text messages, progress bars, or notices. Each can have an icon, a title and markdown text. Notices can have richer content, multi-line text, and action buttons (see app-polo for examples).

Extensions and app components can add messages programmatically, and messages and progress status can have a key (prefixed with the extension key automatically, extensions cannot modify other extension messages) that allows them to update or remove existing messages.

If there are multiple items active, it shows the last one but can be tapped to expand it and see at least five lines in a scrollable area. If there are notices, they are displayed as a stack of post-it like rectangles on top of the rest of the active items scrollable area.r

On the settings screen, in the about section, there should be a link to a screen that shows "Recent Notices" where they are still displayed as post-it notes but one after another, with most recent on top.
