"use strict";
// Sends the report form of /melden (plan area 7, item 2899). Built by tools/site/build_site.py.
const MSG = {
  good_faith: "Bitte bestätige den guten Glauben. / Please confirm good faith.",
  details: "Bitte erkläre kurz, was rechtswidrig ist. / Please explain briefly what is illegal.",
  no_such_code: "Bitte gib den Freundescode an. / Please enter the friend code.",
  slow_down: "Gerade kommen sehr viele Meldungen. Bitte versuch es in einer Stunde noch einmal. / Too many reports right now, please try again in an hour.",
  other: "Das hat nicht geklappt. Bitte versuch es später oder schreib uns (Support). / That did not work. Please try later or write to us (support)."
};
document.getElementById("f").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const f = ev.target;
  const out = document.getElementById("out");
  out.textContent = "Wird gesendet ... / Sending ...";
  try {
    const cfg = await (await fetch("/chimora.json")).json();
    const h = { "apikey": cfg.anon_key, "Content-Type": "application/json" };
    const s = await (await fetch("/auth/v1/signup", { method: "POST", headers: h, body: JSON.stringify({ data: {} }) })).json();
    if (!s.access_token) { throw new Error("sign-in"); }
    h["Authorization"] = "Bearer " + s.access_token;
    const r = await (await fetch("/rest/v1/rpc/report_web", { method: "POST", headers: h, body: JSON.stringify({
      p_code: f.code.value, p_reason: Number(f.reason.value), p_details: f.details.value,
      p_contact: f.contact.value, p_good_faith: f.faith.checked }) })).json();
    if (r && r.ok) {
      out.textContent = "Danke. Deine Meldung hat die Nummer W" + r.report_id + ". / Thank you. Your report number is W" + r.report_id + ".";
      f.reset();
    } else {
      out.textContent = MSG[r && r.error] || MSG.other;
    }
  } catch (e) {
    out.textContent = MSG.other;
  }
});
