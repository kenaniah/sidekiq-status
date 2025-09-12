document.addEventListener('DOMContentLoaded', function() {
  document.getElementById("sidekiq-status-select-status-name").addEventListener("change", handleSelectChange);
  document.getElementById("sidekiq-status-select-per-page").addEventListener("change", handleSelectChange);
});

function handleSelectChange() {
  window.location = this.options[this.selectedIndex].getAttribute("data-url");
}
