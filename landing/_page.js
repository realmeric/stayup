/* The hero's menu bar. Click the cup, the flag moves. */
(function () {
  "use strict";
  var bar = document.getElementById("bar");
  var cup = document.getElementById("cup");
  var flag = document.getElementById("flag");
  var caption = document.getElementById("caption");
  if (!bar || !cup) return;

  function set(on) {
    bar.classList.toggle("is-awake", on);
    cup.setAttribute("aria-pressed", on ? "true" : "false");
    if (flag) flag.textContent = on ? "1" : "0";
    if (caption) {
      caption.textContent = on
        ? "Holds through a closed lid. The lease is two minutes ahead."
        : "Asleep on a lid close, like any Mac.";
    }
  }

  cup.addEventListener("click", function () { set(!bar.classList.contains("is-awake")); });

  document.addEventListener("keydown", function (e) {
    if (!e.metaKey || !e.altKey || !e.ctrlKey) return;
    if ((e.key || "").toLowerCase() !== "b") return;
    e.preventDefault();
    set(!bar.classList.contains("is-awake"));
  });
})();
