# User Interface Design for Ham2K HaLo Next

## Concepts

We'll use "Views" to refer to the different screens or windows that the user interacts with. "Panels" to refer to the main components of a view (which may be laid out next to each other, or as tabs), and "Areas" to sections or groups inside a Panel.

## Main Views

The app currently has three main views:

- Home View: a list of all operations, along with a button to start a new operation

- Operation View: the main view for an operation, showing the list of QSOs, logging controls and related information

- Settings View: allows the user to configure the app's settings

### The Home View

The home view is a list of all operations in an "Operation List Panel", sorted most recent first,along with a button to start a new operation. 

The header shows "Desktop Logger" in desktop platforms and "Portable Logger" in mobile ones. It also has a button to navigate to the Settings View.

In the bottom there's a "Quick Lookup Panel", comprised of afield that allows the user to enter a callsign and see information about it, as well as enter commands. Information is displayed just above the field.

### The Operation View

The operation view has four main panels: 

- Logging Panel: a list of QSOs for the current operation, and a set of logging controls to add or edit QSOs
- Spots Panel: a list of spots relevant to the operation
- Map Panel: a map showing all the QSOs for the operation.
- Operation Settings Panel: a panel that allows the user to configure settings for the current operation.

Normally all four panels are displayed as tabs, with the logging panel tab showing the count of QSOs.

If the view is wide enough, the logging panel is displayed on the left, and the remaining panels are grouped as tabs on the right, with a split that can be resized by the user.


### The Logging Controls

The logging controls are an area of the Logging Panel dedicated to adding or editing QSOs. It is divided in three main areas: the main logging controls, the information area, and the secondary logging controls.

The main logging controls include the callsign input that's also used for commands, inputs such as their exchange, our exchange, state, grid, and other controls defined by active extensions and operation references.

The secondary logging controls are pills that show current state of some QSO attributes, both built-in ones like time and radio, as well as extension-defined pills. The pills can be selected to display a richer set of controls in a stripe above the secondary control area. This secondary control strip can scroll past the visible area, and the pills act like mutually exclusive tabs to display their controls.  The strip can be expanded to show all controls in multiple rows, or collapsed to a single row with scrolling to conserve screen space.

The information area is used to present information to the user, like details for the current callsign, or a summary of operation statistics when no callsign is entered. The data displayed in it is usually conveyed by extensions using markdown, and it can contain links to external resources or internal navigation. Tapping on the information area can take the user to a screen or pane with more detailed information.

The set of primary logging controls always starts with the callsign input, followed by the exchange inputs if the user has not disabled them, and then come the controls defined by active extensions and finally user-enabled ones like state or grid. 

The list of primary controls is very limited and focused on information exchanged over the air for every single contact. Most of the time the secondary controls should be used instead for other details.

Pressing tab or space should rotate focus between primary controls. If an input is in a mode that allows spaces, then pressing space once just enters the space character, but space twice in a row deletes the first space entered and then moves focus to the next primary control.

## General Layout

#### Header

Windows (or screens in mobile platforms) have a header, which can display a title and optional subtitle, along with a logo or back arrow on the left side, and one or more buttons on the right side.

When the window is wide enough for split views, the header title and subtitle text is left aligned. On narrow windows or screens, the text is centered.

#### Footer

A footer is displayed at the bottom of the window or screen, and might show a progress bar for sync activity, and other status information.

In mobile devices, the footer is hidden when they keyboard is open.

The footer should include padding to avoid being hidden by rounded corners.

## Future directions

* We will implement a layout mechanism that lets users drag and drop secondary controls to reorder them, and they can drag a secondary control outside of the current secondary area to create a separate secondary control strip where the user can leave a control open independently from the original secondary control strip.

* We will implement a more modular layout system, where a JSON-based layout definition can be used to customize the layout of different windows or screens in the app.

* We will add support for multiple windows, each with a separate "Current Operation" context.

* We will add support for customizing the layout of the QSO List, so that the logging controls appear on top and the list is sorted from most recent first, as well as the current set up where the controls are below the list and it is sorted from oldest first.

* We might add support for theming, allowing users to customize the appearance of the app.
