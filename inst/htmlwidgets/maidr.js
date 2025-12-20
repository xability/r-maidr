// MAIDR htmlwidget binding
// Uses iframe-based isolation to ensure MAIDR.js initializes properly
// for each plot in its own JavaScript context.

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
