// Trigger MAIDR's initialization by dispatching a DOM event
function triggerMaidrRescan() {
  // Try to trigger MAIDR's main function by dispatching a custom event
  // that MAIDR might be listening for
  const event = new CustomEvent('maidr-rescan', {
    detail: { timestamp: Date.now() }
  });
  document.dispatchEvent(event);
  
  // Also try to trigger by simulating DOMContentLoaded if MAIDR is listening
  const domEvent = new Event('DOMContentLoaded', {
    bubbles: true,
    cancelable: true
  });
  document.dispatchEvent(domEvent);
  
  console.log('Triggered MAIDR rescan events');
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
            
            // Trigger MAIDR rescan after a short delay to ensure DOM is updated
            setTimeout(function() {
              triggerMaidrRescan();
            }, 100);
                     
            console.log('MAIDR widget rendered with SVG content');
          },
      
      resize: function(width, height) {
        // Handle widget resizing if needed
      }
    };
  }
});
