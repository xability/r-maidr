# Parent-side listener for the messages a MAIDR iframe posts

Handles two messages, both keyed to the frame that sent them by matching
`contentWindow` against the message's source:

## Usage

``` r
maidr_iframe_host_script()
```

## Value

Character string with a script tag

## Details

- `maidr-iframe-height` resizes the frame to its content.

- `maidr:frame-focus-escape` moves focus out of the frame and into this
  document, when the reader shift-tabs off the chart and the browser has
  nowhere in this page to send them. Keyboard events do not cross a
  frame boundary, so while the reader is inside the chart the page
  around it hears nothing; if Shift+Tab then leaves the document
  altogether for the browser's own UI, the page cannot be driven from
  the keyboard at all. On a reveal.js slide that is exactly what happens
  — the deck renders no controls of its own, so a chart is the first
  thing on the page — and no key reaches the deck. The frame asks for
  the handoff rather than performing it, which keeps working whether or
  not it can reach this document: it could not when the chart was
  embedded through a `data:` URL, and a message costs nothing now that
  `srcdoc` means it could.

Focus goes to the tab stop before the frame where this page has a
reachable one, which is what the browser would have done. Where it has
none, focus lands on the element holding the frame — a reveal.js slide
is a `<section>`, so on a slide deck that is the slide itself.

Reachability is checked rather than assumed: reveal.js leaves the slides
on either side of the current one rendered, so a chart on the previous
slide is a tab stop in document order even though it is marked hidden.

So is the handoff itself. Asking an element to take focus is not the
same as it taking focus — `focus()` on an element with no rendered box
is a silent no-op, and Shiny wraps every output in a `display: contents`
div — so the outcome is read back and the ancestors are walked until one
actually holds it. An element is asked as it stands before being given
`tabindex="-1"`, so a tab stop this page already owns is never taken out
of the tab order, and a `tabindex` added to one that still refuses is
removed again.

Registered at most once per document (guarded by a window flag), no
matter how many iframes embed it.
