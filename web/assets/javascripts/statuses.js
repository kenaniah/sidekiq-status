var filterSelects = document.querySelectorAll(".nav-container select.form-control")
for(var i = 0; i < filterSelects.length; i++){
  filterSelects[i].addEventListener("change", function() {
    console.log(this)
    window.location = this.options[this.selectedIndex].getAttribute('data-url')
  })
}
