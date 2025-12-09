// Track widget count for coordinated initialization
let maidrWidgetCount = 0;
let maidrInitTimeout = null;

function triggerMaidrInit() {
  maidrWidgetCount++;

  // Clear any pending initialization
  if (maidrInitTimeout) {
    clearTimeout(maidrInitTimeout);
  }

  // Wait for all widgets to render, then check if MAIDR needs initialization
  maidrInitTimeout = setTimeout(function() {
    // Check if MAIDR library is loaded and has an init function
    if (typeof window.maidr !== 'undefined' && typeof window.maidr.init === 'function') {
      // MAIDR has a public init API - use it
      window.maidr.init();
      console.log('Called maidr.init() for ' + maidrWidgetCount + ' widgets');
    } else {
      // MAIDR should auto-initialize - no action needed
      // The maidr-data attributes are already in the DOM
      console.log('MAIDR auto-initialization expected for ' + maidrWidgetCount + ' widgets');
    }
    maidrWidgetCount = 0;
  }, 300);
}

HTMLWidgets.widget({
  name: "maidr",
  type: "output",
  
  factory: function(el, width, height) {
    return {
          renderValue: function(x) {
            // Clear any existing content
            el.innerHTML = "";
            
            // Insert SVG content
            el.innerHTML = x.svg_content;
            
            // Notify that widget is ready (coordinates with other widgets)
            setTimeout(function() {
              triggerMaidrInit();
            }, 100);
                     
            console.log('MAIDR widget rendered with SVG content');
          },
      
      resize: function(width, height) {
        // Handle widget resizing if needed
      }
    };
  }
});
