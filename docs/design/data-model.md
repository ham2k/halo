# The Ham2K Logger Ideal Data Model

This document is not conclusive or perfect, but it sets a general direction to how we want to represent the world in
the Ham2K Logger code and databases.

## The Context

Our app is based around the idea of views (windows or screens, generally) that present some interface components to the user. Each view operates within a specific context,
which defines the scope of data and actions available to that view.

A view's context consists of:
- a user profile
- user preferences (tied to the profile)
- the station configuration and current state
- the operating position within that station
- the operator's callsign, which can change through the operation
- the current operation (if any)
- the current QSO, either new being entered, or existing being edited

## The global data

The app provides global data that is accessible from any view, including:

- the current date and time
- the database of all the QSOs and Operations
- a list of profiles and their settings, including the last selected or default profile
- a list of station configurations, including the last selected or default station
- a lookup database, for use by extensions
- a data file store and service, for use by extensions

## The user profile

Each user profile consists of a callsign (might be the same over multiple profiles), a name (which defaults to the callsign, and does have to be unique) and a UUID.

Along these identifiers it includes a set of data values for the user preferences, which is combined with the data values in the default profile and the preference definition defaults to provide the full picture of user settings. When the app wants to update a preference value, it is stored in the current profile unless explicitly requested to be stored in the default profile.

A profile also includes a selected station configuration, along with the attributes that define the state of that station configuration.

## The Log Data

The core purpose of the app is to register QSOs (amateur radio contacts) between two parties. This information is divided into `our`, `their`, `refs` and common qso data (like, band, mode, frequency and timestamps). The `our` and `their` components contain the details specific to each party and have similar shapes, while `refs` is an array of "references", or information specific to different activities, contests, events, etc, managed by different extensions. Each QSO has its own UUID, and also can reference the UUID of the operation it belongs to.

QSOs are often grouped in Operations, which have their own `refs` and attributes that apply to the entire operation. And they can be broken down into segments, each with their own refs and attributes.

An operation also moves through a lifecycle, recorded as an attribute of the operation itself: new, ready, active, paused, completed, processed and archived. Most of the transitions are explicit — the operator starts, pauses, ends or restarts. Two are inferred by the app, after a long silence or after an operation has been sitting processed for a while, and one, `processed`, is written whenever a log first leaves the app through an export or an upload to a confirmation service. From `paused` onwards the new-QSO entry row is locked and nothing else is; existing contacts stay editable, and reopening an operation returns it to `active`.

On a shared operation, only the owner changes the state. Ownership is an account: the operation records the account it was created under, and a device may only write the status when that matches the account it is signed in to. A device that receives an operation from a peer on another account contributes contacts to it but never starts, pauses, ends or archives it, because it cannot know when the operator whose log it is considers the work done, and a guest's guess would travel back to the owner as if the owner had made it. An operation created by a device signed in to no account has no owner, and any device may change its state.

## Stations

A station is a collection of equipment (radios, antennas, switches, etc) used by one or more operators to make radio contacts.

Each piece of equipment has
- uuid
- category: defines its general characteristics ("transceiver", "antenna", "antenna switch", "rotator", etc)
- type: defines the specific model (i.e. "a yaesu ftDX-10", or a "Generic Kenwood Transceiver")
- transport: defines how the equipment connects or communicates (i.e. "USB", "Ethernet")
- transport configuration: details relevant to the transport
- user-defined name (i.e. "Left Radio")

Based on the category and characteristics, each equipment provides a set of ports, providing inputs, outputs and/or controls, such as "antA", "antB", "ptt", "audio", "mic", "key"

A station definition the includes which equipment is active, and how one equipment's ports connect to other equipments.

Some equipment represents mere placeholders, like "headset" and "20m dipole" with no state, but other components can include complex state and behavior, such as a rotator with its current azimuth and elevation, or a transceiver with its current frequency and mode.

Finally, some of these ports connect to specific "operating positions", each with controls for VFO, audio, mic, ptt and key

The app has a global list of known equipment that has been configured, or automatically detected. There's also a global list of Station Configurations, which is where the user can define which equipment is active, and how each piece connects with each other.

A station configuration requires at least one transceiver (labeled as radio1) providing at least one vfo port, and a vfo control node (labeled vfoA) connected with each other.

Each user profile has a current Station Configuration, and a current (or last-known) state for that configuration.

A vfo control node has at least a frequency and mode and might have other characteristics such as bandwidth, filtering, notches, etc.

The global context provides access to the nodes in the station configuration and its current state, and the control nodes
can receive update commands from the user interface or automated scripts.

So for example, the "radio" controls in the operation view can be connected to vfoA and thus update the radio's VFO when the user enters a frequency, or when they select a station from the spots. And if the user changes the frequency on the radio, it's updated in the operation view.

