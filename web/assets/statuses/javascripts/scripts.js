function handleSelectChange(select) {
  window.location = select.options[select.selectedIndex].getAttribute('data-url')
}
