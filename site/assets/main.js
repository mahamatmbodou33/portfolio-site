(function () {
  "use strict";
  var root = document.documentElement;
  var cfg = window.SITE_CONFIG || {};
  var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function store(key, val) {
    try { if (val === undefined) return localStorage.getItem(key); localStorage.setItem(key, val); } catch (e) { return null; }
  }

  /* Language: English is in the HTML; French comes from i18n.js */
  var FR = window.I18N_FR || null;
  var EN_ROLES = ["Cloud Engineer", "DevOps Engineer", "Terraform Builder", "Solutions Architect"];
  var EN_MSG = {
    copied: "Copied", selected: "Selected", menuOpen: "Open menu", menuClose: "Close menu",
    invalid: "Please add your name, a valid email, and a message of at least 20 characters.",
    preview: "Preview mode: the form isn't connected to the backend yet, so nothing was sent.",
    sending: "Sending…", sent: "Thanks, your message was sent. I'll reply within one business day.",
    tooMany: "Too many messages right now. Please try again in a minute.",
    failed: "Your message couldn't be sent. Please email me directly instead.",
    offline: "Your message couldn't be sent. Check your connection, or email me directly."
  };
  var lang = "en";
  var originals = [];   // [element, englishHTML]
  var originalAttrs = []; // [element, attr, englishValue]
  var metaDesc = document.querySelector('meta[name="description"]');
  var enTitle = document.title, enDesc = metaDesc ? metaDesc.getAttribute("content") : "";
  function t(name) { return lang === "fr" && FR && FR.messages[name] ? FR.messages[name] : EN_MSG[name]; }
  function roles() { return lang === "fr" && FR ? FR.roles : EN_ROLES; }

  if (FR) {
    Array.prototype.forEach.call(document.querySelectorAll("[data-i18n]"), function (el) { originals.push([el, el.innerHTML]); });
    FR.attrs.forEach(function (a) {
      var el = document.querySelector(a[0]);
      if (el) originalAttrs.push([el, a[1], el.getAttribute(a[1]), a[2]]);
    });
  }

  function setYear() {
    var y = document.getElementById("year");
    if (y) y.textContent = String(new Date().getFullYear());
  }

  function applyLang(next) {
    if (!FR) return;
    lang = next === "fr" ? "fr" : "en";
    root.setAttribute("lang", lang);
    originals.forEach(function (pair) {
      var fr = FR.text[pair[0].getAttribute("data-i18n")];
      pair[0].innerHTML = lang === "fr" && fr ? fr : pair[1];
    });
    originalAttrs.forEach(function (a) { a[0].setAttribute(a[1], lang === "fr" ? a[3] : a[2]); });
    var page = document.getElementById("home") ? "index" : "404";
    document.title = lang === "fr" ? FR.title[page] : enTitle;
    if (metaDesc && page === "index") metaDesc.setAttribute("content", lang === "fr" ? FR.description : enDesc);
    setYear();
    if (typeof restartTyping === "function") restartTyping();
  }

  var langBtn = document.getElementById("lang-toggle");
  if (langBtn) {
    if (!FR) langBtn.hidden = true;
    langBtn.addEventListener("click", function () {
      var next = lang === "fr" ? "en" : "fr";
      applyLang(next);
      store("lang", next);
    });
  }

  /* Theme: dark by default, follows the system until the visitor picks one */
  var saved = store("theme");
  if (saved === "light" || saved === "dark") root.setAttribute("data-theme", saved);
  var toggle = document.getElementById("theme-toggle");
  if (toggle) toggle.addEventListener("click", function () {
    var current = root.getAttribute("data-theme") ||
      (window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");
    var next = current === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    store("theme", next);
  });

  /* Mobile menu */
  var menuBtn = document.getElementById("menu-toggle");
  var links = document.getElementById("nav-links");
  function closeMenu() {
    if (!links) return;
    links.classList.remove("is-open");
    if (menuBtn) { menuBtn.setAttribute("aria-expanded", "false"); menuBtn.setAttribute("aria-label", t("menuOpen")); }
  }
  if (menuBtn && links) {
    menuBtn.addEventListener("click", function () {
      var open = links.classList.toggle("is-open");
      menuBtn.setAttribute("aria-expanded", String(open));
      menuBtn.setAttribute("aria-label", open ? t("menuClose") : t("menuOpen"));
    });
    links.addEventListener("click", function (e) { if (e.target.tagName === "A") closeMenu(); });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") closeMenu(); });
  }

  /* Nav background, back-to-top button, active section link */
  var nav = document.getElementById("nav");
  var toTop = document.getElementById("to-top");
  var navLinks = links ? Array.prototype.slice.call(links.querySelectorAll("a")) : [];
  var sections = navLinks.map(function (a) { return document.querySelector(a.getAttribute("href")); });
  function onScroll() {
    var y = window.scrollY || 0;
    if (nav) nav.classList.toggle("is-scrolled", y > 10);
    if (toTop) toTop.classList.toggle("is-visible", y > 700);
    var current = -1;
    sections.forEach(function (s, i) { if (s && s.getBoundingClientRect().top <= 120) current = i; });
    navLinks.forEach(function (a, i) { a.classList.toggle("is-active", i === current); });
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* Typing effect for the role line. The first role is already in the HTML. */
  var typed = document.getElementById("typed");
  var typeTimer = null;
  function restartTyping() {
    if (!typed) return;
    clearTimeout(typeTimer);
    var list = roles();
    typed.textContent = list[0];
    if (reduceMotion) return;
    var r = 0, i = list[0].length, deleting = true;
    var tick = function () {
      var words = roles();
      if (deleting) {
        i -= 1;
        typed.textContent = words[r].slice(0, i);
        if (i <= 0) { deleting = false; r = (r + 1) % words.length; }
        typeTimer = setTimeout(tick, 45);
      } else {
        i += 1;
        typed.textContent = words[r].slice(0, i);
        if (i >= words[r].length) { deleting = true; typeTimer = setTimeout(tick, 2200); } else { typeTimer = setTimeout(tick, 85); }
      }
    };
    typeTimer = setTimeout(tick, 2600);
  }

  var savedLang = store("lang");
  if (savedLang === "fr") applyLang("fr"); else restartTyping();

  /* Project filter */
  var filters = document.querySelectorAll(".filter");
  var cards = document.querySelectorAll("#project-list .project");
  var empty = document.getElementById("projects-empty");
  Array.prototype.forEach.call(filters, function (btn) {
    btn.addEventListener("click", function () {
      var f = btn.getAttribute("data-filter");
      Array.prototype.forEach.call(filters, function (b) {
        var on = b === btn;
        b.classList.toggle("is-active", on);
        b.setAttribute("aria-pressed", String(on));
      });
      var shown = 0;
      Array.prototype.forEach.call(cards, function (c) {
        var match = f === "all" || (" " + c.getAttribute("data-cat") + " ").indexOf(" " + f + " ") !== -1;
        c.hidden = !match;
        if (match) shown += 1;
      });
      if (empty) empty.hidden = shown > 0;
    });
  });

  setYear();

  /* Copy email */
  var copyBtn = document.getElementById("copy-email");
  var emailText = document.getElementById("email-text");
  if (copyBtn && emailText) copyBtn.addEventListener("click", function () {
    var done = function () { var before = copyBtn.textContent; copyBtn.textContent = t("copied"); setTimeout(function () { copyBtn.textContent = before; }, 1600); };
    var fallback = function () {
      var range = document.createRange(); range.selectNodeContents(emailText);
      var sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(range);
      copyBtn.textContent = t("selected");
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(emailText.textContent.trim()).then(done, fallback);
    } else { fallback(); }
  });

  /* Contact form */
  var form = document.getElementById("contact-form");
  var statusEl = document.getElementById("form-status");
  var submit = document.getElementById("f-submit");
  if (!form) return;

  function setStatus(msg, kind) {
    statusEl.textContent = msg;
    statusEl.className = "form__status" + (kind ? " is-" + kind : "");
  }
  function validate() {
    var ok = true;
    ["f-name", "f-email", "f-message"].forEach(function (id) {
      var el = document.getElementById(id);
      var valid = el.checkValidity() && el.value.trim().length > 0;
      el.setAttribute("aria-invalid", valid ? "false" : "true");
      if (!valid) ok = false;
    });
    return ok;
  }

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    if (!validate()) {
      setStatus(t("invalid"), "err");
      return;
    }
    if (!cfg.contactEndpoint) {
      setStatus(t("preview"), "err");
      return;
    }
    var data = {
      name: form.name.value.trim(),
      email: form.email.value.trim(),
      company: form.company.value.trim(),
      topic: form.topic.value,
      message: form.message.value.trim(),
      website: form.website.value
    };
    submit.disabled = true;
    setStatus(t("sending"));
    fetch(cfg.contactEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data)
    }).then(function (res) {
      if (res.ok) {
        form.reset();
        setStatus(t("sent"), "ok");
      } else if (res.status === 429) {
        setStatus(t("tooMany"), "err");
      } else {
        setStatus(t("failed"), "err");
      }
    }).catch(function () {
      setStatus(t("offline"), "err");
    }).finally(function () { submit.disabled = false; });
  });
})();
