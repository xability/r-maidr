HTMLWidgets.widget({
  name: 'maidrWidget',
  type: 'output',
  factory: function(el, width, height) {
    return {
      renderValue: function(x) {
        // The actual rendering logic is handled by the CDN maidr.js
        // Optionally, you could call a global function if maidr.js exposes one
        // Fallback: just show the JSON
        el.innerHTML = '<pre>' + JSON.stringify(x.data, null, 2) + '</pre>';
      },
      resize: function(width, height) {
        // Optionally handle resizing
      }
    };
  }
}); 