// Handles the navigation for the filter and per-page select dropdowns
document.addEventListener("change", function(event) {
  if (event.target.matches(".nav-container select.form-control")) {
    window.location = event.target.options[event.target.selectedIndex].getAttribute('data-url')
  }
})
