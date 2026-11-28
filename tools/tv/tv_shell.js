// Samsung TV remote for Chimora. Arrows and OK reach Godot as normal arrow and Enter keys.
// Back (10009) goes to TvRemote.gd, which handles it like the Android back button.
window.CHIMORA_TV = true;
(function () {
  try { tizen.tvinputdevice.registerKeyBatch(['MediaPlayPause', 'MediaPlay', 'MediaPause']); } catch (e) {}
  window.addEventListener('keydown', function (e) {
    if (e.keyCode !== 10009) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    if (window.chimoraTvBack) window.chimoraTvBack();
  }, true);
  document.addEventListener('visibilitychange', function () {
    var c = document.querySelector('canvas');
    if (!document.hidden && c) c.focus();
  });
})();
