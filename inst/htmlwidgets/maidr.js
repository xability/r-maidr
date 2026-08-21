// MAIDR htmlwidget binding
// Uses iframe-based isolation to ensure MAIDR.js initializes properly
// for each plot in its own JavaScript context.
//
// Both listeners below are duplicated from the parent-side script that
// `maidr_iframe_host_script()` (R/svg_utils.R) appends to every chart iframe.
// They have to be: this binding sets the iframe HTML through `innerHTML`, and
// a script element assigned that way never runs. Change one and change the
// other -- nothing checks that the two agree.

// Global message listener for iframe height auto-sizing
// Only set up once per page
(function() {
  if (window._maidrHeightListenerSetup) return;
  window._maidrHeightListenerSetup = true;

  window.addEventListener("message", function(event) {
    // Validate message structure
    if (!event.data || event.data.type !== "maidr-iframe-height") return;

    var height = event.data.height;
    if (typeof height !== "number" || height < 50) return;

    // Find the iframe that sent this message
    // Since data: URLs are opaque origins, we check all MAIDR iframes
    var iframes = document.querySelectorAll('iframe[id^="maidr-iframe-"]');
    iframes.forEach(function(iframe) {
      // Check if this iframe's contentWindow matches the message source
      try {
        if (iframe.contentWindow === event.source) {
          iframe.style.height = height + "px";
          console.log("MAIDR iframe resized to", height, "px");
        }
      } catch (e) {
        // Cross-origin access error - try sizing based on current state
        // If iframe doesn't have explicit height or is smaller, update it
        var currentHeight = parseInt(iframe.style.height, 10) || 0;
        if (currentHeight < height) {
          iframe.style.height = height + "px";
        }
      }
    });
  });
})();

// Global listener for the chart asking to hand focus back to this page.
// Only set up once per page.
//
// Keyboard events do not cross a frame boundary, so while the reader is inside
// a chart the page around it hears nothing, and Shift+Tab off the chart is
// their way back. Usually the browser handles that by itself; the chart only
// asks when nothing reachable precedes its frame here, so that Shift+Tab would
// otherwise leave the document altogether for the browser's own UI. A chart on
// a reveal.js slide is exactly that case -- the deck renders no controls of its
// own -- and from inside the chart no key reaches the deck.
(function() {
  if (window._maidrFocusEscapeSetup) return;
  window._maidrFocusEscapeSetup = true;

  var TABBABLE = 'a[href], area[href], button:not([disabled]), '
    + 'input:not([disabled]), select:not([disabled]), textarea:not([disabled]), '
    + 'iframe, audio[controls], video[controls], '
    + '[contenteditable]:not([contenteditable="false"]), [tabindex]:not([tabindex^="-"])';
  // A reveal.js slide is a <section>, so on a slide deck focus lands on the
  // slide itself. Page-level landmarks are left out: handing a reader the whole
  // page when they stepped out of one chart says less about where they are.
  var CONTAINER = 'section, article, [role="region"]';

  // A tab stop the reader cannot get to is not somewhere to send them, and that
  // distinction is the whole point in a deck: reveal.js leaves the slides on
  // either side of the current one rendered, so the chart on the previous slide
  // is a tab stop in document order even though it is marked hidden.
  function reachable(element) {
    if (element.closest('[hidden], [aria-hidden="true"], [inert]')) return false;
    var style = window.getComputedStyle(element);
    return style.display !== "none" && style.visibility !== "hidden";
  }

  function stopBefore(frame) {
    var stops = document.querySelectorAll(TABBABLE);
    var found = null;
    for (var i = 0; i < stops.length; i++) {
      if (stops[i] === frame) break;
      if (reachable(stops[i])) found = stops[i];
    }
    return found;
  }

  // Asking an element to take focus is not enough. focus() on an element with
  // no rendered box -- a `display: contents` wrapper, which is what Shiny puts
  // around every output -- is a silent no-op, so the outcome has to be read
  // back. A tabindex this added is removed again when the element refuses,
  // rather than leaving it claiming it can hold focus.
  function takeFocus(el) {
    var added = !el.hasAttribute("tabindex");
    // tabindex="-1" takes focus without joining this page's tab order.
    if (added) el.setAttribute("tabindex", "-1");
    el.focus();
    if (document.activeElement === el) return true;
    if (added) el.removeAttribute("tabindex");
    return false;
  }

  window.addEventListener("message", function(event) {
    if (!event.data || event.data.type !== "maidr:frame-focus-escape") return;

    var frames = document.querySelectorAll('iframe[id^="maidr-iframe-"]');
    for (var i = 0; i < frames.length; i++) {
      if (frames[i].contentWindow !== event.source) continue;

      var target = stopBefore(frames[i]);
      if (target) { target.focus(); return; }

      var section = frames[i].closest(CONTAINER);
      if (section && takeFocus(section)) return;
      for (var el = frames[i].parentElement; el; el = el.parentElement) {
        if (el !== section && takeFocus(el)) return;
      }
      return;
    }
  });
})();

HTMLWidgets.widget({
  name: "maidr",
  type: "output",

  factory: function(el, width, height) {
    return {
      renderValue: function(x) {
        // Clear any existing content
        el.innerHTML = "";

        // Debug: log what we received
        console.log('MAIDR widget received data:', Object.keys(x || {}));

        if (!x) {
          console.error('MAIDR widget: No data received');
          el.innerHTML = '<p style="color: red;">Error: No plot data received</p>';
          return;
        }

        // Insert iframe content (contains complete MAIDR.js environment)
        // The iframe has its own document context where MAIDR.js will
        // initialize and discover the SVG with maidr-data attribute
        if (x.iframe_content && x.iframe_content.length > 0) {
          el.innerHTML = x.iframe_content;
          console.log('MAIDR widget rendered with iframe isolation');
        } else if (x.svg_content && x.svg_content.length > 0) {
          // Legacy fallback for direct SVG content
          el.innerHTML = x.svg_content;
          console.log('MAIDR widget rendered with direct SVG (legacy mode)');
        } else {
          console.error('MAIDR widget: No iframe_content or svg_content found');
          el.innerHTML = '<p style="color: red;">Error: No plot content available</p>';
        }
      },

      resize: function(width, height) {
        // Resize iframe width only - height is managed by postMessage
        var iframe = el.querySelector('iframe');
        if (iframe) {
          if (width) iframe.style.width = typeof width === 'number' ? width + 'px' : width;
          // Don't override height set by postMessage unless explicitly requested
        }
      }
    };
  }
});
