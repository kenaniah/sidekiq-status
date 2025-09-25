// Handles the navigation for the filter and per-page select dropdowns
document.addEventListener("change", function(event) {
  if (event.target.matches(".nav-container select.form-control")) {
    window.location = event.target.options[event.target.selectedIndex].getAttribute('data-url')
  }
})

// Set width of progress bars based on their aria-valuenow attribute
function updateProgressBarWidths() {
  document.querySelectorAll('.progress-bar').forEach(function(progressBar) {
    const valueNow = progressBar.getAttribute('aria-valuenow');
    if (valueNow !== null) {
      progressBar.style.width = valueNow + '%';
    }
  });
}
updateProgressBarWidths();

// Update progress bar widths when the page loads
document.addEventListener("DOMContentLoaded", updateProgressBarWidths);

// Also update when new content is dynamically loaded
document.addEventListener("DOMContentMounted", updateProgressBarWidths);

