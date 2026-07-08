# Issues

* Do data files work on web? 

# Features

## Forms

We need to implement a schema for describing forms so that extensions can ask users for inputs in complex forms. And of course, we also need to implement a way to render this schema into the UI in a View.

A form is a list of fields, headers, section dividers and markdown text blocks. 
It is rendered in a view or dialog. It can have a title and subtitle. 
The form definition also includes the state values for each field, along with optional JS callbacks to validate and transform the field values.
Fields can be of various types including single line text, multi-line text, email, callsign, number, select, radio, checkbox.

Other elements include Section dividers with a title, and markdown text blocks.

## Exports

Operation Exports Panel: Provide a list of exports as suggested by extensions, allow selecting multiple exports and saving them to disk (or share, in mobile platforms). Display a summary of sync status for the operation and qsos.

## Activities

Operation Activities View: List the activities/references in the operation. If the operation has start, break or end events, display them as headers on the list. Each ref gets its own row. Use a fab to add new activities, or to add breaks.

Start, end and break events allow editing their times

Implement a

## Location

Implement the location options in the Operation Settings Panel
