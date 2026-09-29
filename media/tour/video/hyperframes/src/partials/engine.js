          // ---- shared compression engine (inlined per scene) ----
          const MONO = 0.6;
          const MARKS = {};
          const REGQ = [];
          let LASTHOVER = null;
          function geo(el) {
            return { x: +el.dataset.x, y: +el.dataset.y, fs: +el.dataset.fs, lh: +el.dataset.lh };
          }
          function tokPos(tok, g) {
            const ln = +tok.closest(".ln").dataset.ln;
            const c = +tok.dataset.c;
            const len = tok.textContent.length;
            return { x: g.x + (c + len / 2) * MONO * g.fs, y: g.y + ln * g.lh + g.lh / 2 };
          }
          function rng(seed) {
            let s = seed % 2147483647;
            if (s <= 0) s += 2147483646;
            return () => (s = (s * 16807) % 2147483647) / 2147483647;
          }
          function boxCenter(el) {
            const g = geo(el);
            const lines = el.querySelectorAll(".ln").length;
            let maxLen = 0;
            el.querySelectorAll(".ln").forEach((l) => (maxLen = Math.max(maxLen, l.textContent.length)));
            return { x: g.x + (maxLen * MONO * g.fs) / 2, y: g.y + (lines * g.lh) / 2 };
          }
          function linesIn(sel, t, opts) {
            const o = Object.assign({ stagger: 0.035, dur: 0.35, from: { x: -30 } }, opts || {});
            tl.fromTo(sel + " .ln", Object.assign({ opacity: 0 }, o.from), { opacity: 1, x: 0, y: 0, duration: o.dur, stagger: o.stagger, ease: "expo.out" }, t);
          }
          function mark(boxSel, a, b, t, dur, label, side) {
            const box = document.querySelector(boxSel);
            const g = geo(box);
            const m = document.createElement("div");
            m.className = "mk";
            const width = +box.dataset.w || 900;
            m.style.left = g.x - 14 + "px";
            m.style.top = g.y + a * g.lh - 2 + "px";
            m.style.width = width + 28 + "px";
            m.style.height = (b - a + 1) * g.lh + 4 + "px";
            box.parentNode.insertBefore(m, box);
            (MARKS[boxSel] = MARKS[boxSel] || []).push({ t: t, els: [m] });
            let lab = null;
            if (label) {
              lab = document.createElement("div");
              lab.className = "mk-label";
              lab.textContent = label;
              lab.style.top = g.y + a * g.lh + ((b - a + 1) * g.lh) / 2 - 22 + "px";
              if (side === "left") lab.style.right = 1920 - (g.x - 30) + "px";
              else lab.style.left = g.x + width + 40 + "px";
              box.parentNode.appendChild(lab);
              MARKS[boxSel][MARKS[boxSel].length - 1].els.push(lab);
            }
            tl.fromTo(m, { opacity: 0, scaleX: 0.2, transformOrigin: "0% 50%" }, { opacity: 1, scaleX: 1, duration: 0.3, ease: "expo.out" }, t);
            tl.to(m, { opacity: 0, duration: 0.25 }, t + dur);
            if (lab) {
              tl.fromTo(lab, { opacity: 0, x: side === "left" ? 20 : -20 }, { opacity: 1, x: 0, duration: 0.3, ease: "expo.out" }, t + 0.05);
              tl.to(lab, { opacity: 0, duration: 0.25 }, t + dur);
            }
          }
          // FLIP-morph a card background from one rect to another (rects: [x, y, w, h]).
          function morphCard(sel, from, to, t, dur, ease) {
            tl.fromTo(
              sel,
              { x: 0, y: 0, scaleX: 1, scaleY: 1, transformOrigin: "0% 0%" },
              { x: to[0] - from[0], y: to[1] - from[1], scaleX: to[2] / from[2], scaleY: to[3] / from[3], duration: dur, ease: ease || "power3.inOut" },
              t,
            );
          }
          function shake(t, amp) {
            const a = amp || 10;
            const s = "#" + SID + "-shake";
            tl.to(s, { x: a, y: -a * 0.4, duration: 0.04, ease: "none" }, t);
            tl.to(s, { x: -a * 0.7, y: a * 0.5, duration: 0.05, ease: "none" }, t + 0.04);
            tl.to(s, { x: a * 0.35, y: -a * 0.2, duration: 0.05, ease: "none" }, t + 0.09);
            tl.to(s, { x: 0, y: 0, duration: 0.08, ease: "power2.out" }, t + 0.14);
          }
          // Compress `beforeSel` into `afterSel` in four readable stages that land exactly on the cue (t + dur):
          //   1 mark: the tokens that survive light up
          //   2 fold: boilerplate lines collapse away line by line (accordion), the rest slide together
          //   3 travel: survivors fly to the measured position of their match in the RubyLLM line
          //   4 settle: the RubyLLM line locks in with one squash and settle
          // style only varies the fold order: implode/vacuum/shatter = edges inward, fold = top down, slam = bottom up
          // Width of one monospace character at font size fs, measured from a rendered probe (cached).
          const CW = {};
          function charW(fs) {
            if (CW[fs]) return CW[fs];
            const pr = document.createElement("span");
            pr.className = "cb";
            pr.style.cssText = "position:absolute;left:0;top:0;visibility:hidden;font-size:" + fs + "px";
            pr.textContent = "0".repeat(40);
            document.getElementById("world").appendChild(pr);
            const w = pr.getBoundingClientRect().width;
            const k = pr.offsetWidth / 40;
            pr.remove();
            return (CW[fs] = k || (w / 40));
          }
          function compress(beforeSel, afterSel, t, style, opts) {
            const o = Object.assign({ dur: 0.6, match: "", stage: 1.5, afterDelay: 0 }, opts || {});
            const bEl = document.querySelector(beforeSel);
            const aEl = document.querySelector(afterSel);
            const arrive = t + o.dur;
            const L = o.stage;
            const tMark = arrive - L, tFold = arrive - 0.8 * L, tTravel = arrive - 0.4 * L;
            const bx = +bEl.dataset.x, by = +bEl.dataset.y, blh = +bEl.dataset.lh, bfs = +bEl.dataset.fs;
            const ax = +aEl.dataset.x, ay = +aEl.dataset.y, alh = +aEl.dataset.lh, afs = +aEl.dataset.fs;
            const bToks = Array.from(bEl.querySelectorAll(".t"));
            const aToks = Array.from(aEl.querySelectorAll(".t"));
            const norm = (x) => x.replace(/["'`,:()\[\]{}]/g, "");
            const want = (o.match || "").split(/\s+/).map(norm).filter((w) => w.length > 1);
            const used = new Set();
            const pairs = [];
            let last = -1;
            aToks.forEach((at) => {
              const n = norm(at.textContent);
              if (!want.includes(n)) return;
              const order = bToks.map((_, k) => k).filter((k) => k > last).concat(bToks.map((_, k) => k).filter((k) => k <= last));
              let hit = order.find((k) => !used.has(k) && norm(bToks[k].textContent) === n);
              let sub = -1;
              if (hit === undefined && n.length >= 6) {
                hit = order.find((k) => !used.has(k) && bToks[k].textContent.includes(n));
                if (hit !== undefined) sub = bToks[hit].textContent.indexOf(n);
              }
              if (hit === undefined) return;
              used.add(hit); last = hit;
              pairs.push({ bt: bToks[hit], at: at, sub: sub, text: sub >= 0 ? n : null });
            });
            // marks from the tired stretch clear out before the fold; late ones never show
            (MARKS[beforeSel] || []).forEach((mk) => {
              if (mk.t > tFold - 0.3) mk.els.forEach((e) => (e.style.display = "none"));
              else tl.to(mk.els, { opacity: 0, duration: 0.2 }, tFold - 0.05);
            });
            // 1 MARK
            const sTok = pairs.map((p) => p.bt);
            if (sTok.length) tl.fromTo(sTok, { backgroundColor: "rgba(142,192,124,0)", boxShadow: "0 0 0 0px rgba(142,192,124,0)" },
              { backgroundColor: "rgba(142,192,124,0.26)", boxShadow: "0 0 0 3px rgba(142,192,124,0.85)", duration: 0.25, stagger: 0.03, ease: "power2.out", immediateRender: false }, tMark);
            // 2 FOLD: boilerplate lines collapse in place; the surviving lines condense right above their
            //   slots in the RubyLLM line, in destination order, and the dark panel shrinks around them
            const lines = Array.from(bEl.querySelectorAll(".ln"));
            const keep = new Set(pairs.map((p) => p.bt.closest(".ln")));
            let fold = lines.map((ln, k) => k).filter((k) => !keep.has(lines[k]) && lines[k].textContent.trim().length);
            const blank = lines.map((ln, k) => k).filter((k) => !keep.has(lines[k]) && !lines[k].textContent.trim().length);
            const mid = (lines.length - 1) / 2;
            if (style === "fold") fold.sort((a, b) => a - b);
            else if (style === "slam") fold.sort((a, b) => b - a);
            else fold.sort((a, b) => Math.abs(b - mid) - Math.abs(a - mid));
            fold = fold.concat(blank);
            const W = tTravel - tFold - 0.02;
            const Wf = W * 0.7;
            const d = Math.min(0.22, Wf * 0.5);
            const step = fold.length > 1 ? (Wf - d) / (fold.length - 1) : 0;
            fold.forEach((f, j) => {
              tl.fromTo(lines[f], { scaleY: 1, opacity: 1, transformOrigin: "50% 50%" }, { scaleY: 0, opacity: 0, duration: d, ease: "power2.inOut", immediateRender: false }, tFold + j * step);
            });
            // the survivors gather into a formation that is their exact slots, lifted by D (or dropped, from below):
            //   travel is then one uniform short move, so no two tokens ever cross on the way in
            const cwA = 0.6 * afs;
            const rowOf = (at) => +at.closest(".ln").dataset.ln;
            pairs.sort((p, q) => rowOf(p.at) - rowOf(q.at) || +p.at.dataset.c - +q.at.dataset.c);
            const rows = pairs.map((p) => rowOf(p.at));
            const r0 = rows.length ? Math.min(...rows) : 0, r1 = rows.length ? Math.max(...rows) : 0;
            const below = o.from === "below";
            const D = ((r1 - r0 + 1) + 0.45) * alh * (below ? -1 : 1);
            const slotTop = ay + r0 * alh, slotBot = ay + (r1 + 1) * alh;
            const hoverTop = below ? slotTop - D : slotTop - D, hoverBottom = below ? slotBot - D : slotBot - D;
            let hx0 = ax, hx1 = ax + 400;
            pairs.forEach((p) => { const x = ax + +p.at.dataset.c * cwA; hx0 = Math.min(hx0, x); hx1 = Math.max(hx1, x + (p.text || p.at.textContent).length * cwA); });
            const rest = bToks.filter((x) => !sTok.includes(x));
            // keep-line leftovers fade as their survivors lift out
            const restKeep = rest.filter((x) => keep.has(x.closest(".ln")));
            if (restKeep.length) tl.to(restKeep, { opacity: 0, duration: 0.35, ease: "power1.in" }, tFold + 0.1);
            // the dark panel shrinks around the formation, then clears as it drops into place
            const reg = o.noRegion ? null : REGQ.shift();
            if (reg) {
              const re = document.querySelector(reg);
              const rx = parseFloat(re.style.left), ry = parseFloat(re.style.top), rw = parseFloat(re.style.width), rh = parseFloat(re.style.height);
              const B = [hx0 - 40, hoverTop - 24, hx1 - hx0 + 80, hoverBottom - hoverTop + 48];
              const sx = Math.min(0.999, B[2] / rw), sy = Math.min(0.999, B[3] / rh);
              const Ox = (B[0] - sx * rx) / (1 - sx), Oy = (B[1] - sy * ry) / (1 - sy);
              tl.fromTo(re, { scaleX: 1, scaleY: 1, opacity: 1, transformOrigin: (Ox - rx) + "px " + (Oy - ry) + "px" },
                { scaleX: sx, scaleY: sy, duration: W, ease: "power2.inOut", immediateRender: false }, tFold);
              tl.to(re, { opacity: 0, duration: 0.18, ease: "power1.in" }, tTravel - 0.05);
            }
            // the destination: the RubyLLM line at 35%, every slot outlined, before anything moves
            const aPend = aEl.classList.contains("pending") && !aEl.classList.contains("shown");
            const matched = pairs.map((p) => p.at);
            const slot = { outline: "2px dashed rgba(179,0,0,0.55)", outlineOffset: "3px", borderRadius: "4px" };
            if (matched.length) {
              tl.set(matched, slot, tFold);
              tl.fromTo(matched, { opacity: aPend ? 0 : 1 }, { opacity: 0.35, duration: 0.3, immediateRender: false }, tFold);
              tl.set(matched, { outline: "0px dashed rgba(179,0,0,0)" }, arrive);
            }
            if (aPend) {
              const hidden = (at) => { const y = ay + rowOf(at) * alh; return y < hoverBottom - 2 && y + alh > hoverTop + 2; };
              const vis = aToks.filter((at) => !matched.includes(at) && !hidden(at));
              if (vis.length) tl.fromTo(vis, { opacity: 0 }, { opacity: 0.35, duration: 0.3, immediateRender: false }, tFold);
            }
            LASTHOVER = { top: Math.min(hoverTop, slotTop) };
            // the camera frames the formation and the target tight, then holds through travel and settle
            if (o.camTo) cam(tFold + 0.05, 0.5, Object.assign({ r: 0, ry: 0, rx: 0 }, o.camTo), "power2.inOut");
            else if (!o.noCam) {
              const mw = (el) => Math.max(...Array.from(el.querySelectorAll(".ln")).map((l) => l.textContent.length)) * 0.6 * +el.dataset.fs;
              const x0 = Math.min(hx0, ax), x1 = Math.max(hx1, ax + mw(aEl));
              const y0 = Math.min(hoverTop, ay), y1 = Math.max(hoverBottom, ay + aEl.querySelectorAll(".ln").length * alh);
              const sc = Math.min(1920 / (x1 - x0 + 260), 1080 / (y1 - y0 + 260), 1.15);
              cam(tFold + 0.05, 0.5, { x: (x0 + x1) / 2, y: (y0 + y1) / 2, s: sc, r: 0, ry: 0, rx: 0 }, "power2.inOut");
            }
            // gather (during the fold) and travel (one uniform move by D into the slots)
            const s = afs / bfs;
            const tG = tFold + 0.12;
            pairs.forEach((p, k) => {
              const ln = +p.bt.closest(".ln").dataset.ln;
              const w = document.createElement("div");
              w.className = "cb dark cclone";
              w.style.cssText = "position:absolute;left:" + bx + "px;top:" + by + "px;font-size:" + bfs + "px;line-height:" + blh + "px;opacity:0;visibility:hidden;z-index:5;white-space:pre";
              const tok = p.bt.cloneNode(true);
              if (p.text) tok.textContent = p.text;
              tok.style.display = "block";
              tok.style.backgroundColor = "rgba(142,192,124,0.26)";
              tok.style.boxShadow = "0 0 0 3px rgba(142,192,124,0.85)";
              w.appendChild(tok);
              bEl.parentNode.appendChild(w);
              const aln = rowOf(p.at);
              const fx = () => (+p.bt.dataset.c + Math.max(0, p.sub)) * charW(bfs);
              const fy = () => ln * blh;
              const tx = () => ax - bx + +p.at.dataset.c * charW(afs);
              const ty = () => ay - by + aln * alh + alh / 2 - (blh * s) / 2;
              const hy = () => ty() - D;
              // one destination row gathers at a time, so the rows never cross each other
              const nG = r1 - r0 + 1, Wg = (tTravel - tG) / nG;
              const g0 = tG + (aln - r0) * Wg + k * 0.01 * (nG === 1);
              tl.set(w, { autoAlpha: 1 }, g0);
              tl.set(p.bt, { opacity: 0 }, g0);
              tl.fromTo(w, { x: fx, y: fy, scale: 1, transformOrigin: "0 0" }, { x: tx, y: hy, scale: s, duration: Math.max(0.12, g0 < tTravel - Wg / 2 ? tG + (aln - r0 + 1) * Wg - g0 : tTravel - g0), ease: "power2.inOut", immediateRender: false }, g0);
              tl.fromTo(w, { y: hy }, { y: ty, duration: arrive - tTravel, ease: "power2.inOut", immediateRender: false }, tTravel);
              tl.to(tok, { backgroundColor: "rgba(142,192,124,0)", boxShadow: "0 0 0 0px rgba(142,192,124,0)", color: "#2c2926", duration: arrive - tTravel, ease: "power2.in" }, tTravel);
              tl.set(w, { autoAlpha: 0 }, arrive);
              tl.set(p.at, { opacity: 1 }, arrive);
            });
            tl.set(bEl, { opacity: 0 }, arrive);
            // 4 SETTLE
            const others = aToks.filter((at) => !pairs.some((p) => p.at === at));
            if (aPend) tl.to(others, { opacity: 1, duration: 0.12, ease: "power1.out" }, arrive);
            if (!o.noFx) {
              tl.fromTo(aEl, { scaleX: 1, scaleY: 1, transformOrigin: "0% 50%" }, { scaleX: 1.02, scaleY: 0.88, duration: 0.07, ease: "power2.out", immediateRender: false }, arrive);
              tl.to(aEl, { scaleX: 1, scaleY: 1, duration: 0.45, ease: "elastic.out(1, 0.5)" }, arrive + 0.07);
              tl.fromTo("#" + SID + "-shake", { scale: 1 }, { scale: 1.015, duration: 0.08, ease: "power2.out", immediateRender: false }, arrive);
              tl.to("#" + SID + "-shake", { scale: 1, duration: 0.45, ease: "power3.out" }, arrive + 0.08);
              shake(arrive, Math.min(3, o.shake || 3));
            }
            return arrive;
          }
          // Show an after block without a compression (tokens drop in).
          function afterIn(sel, t, stagger) {
            tl.fromTo(sel + " .t", { opacity: 0, y: 24, scale: 1.3 }, { opacity: 1, y: 0, scale: 1, duration: 0.35, ease: "back.out(2)", stagger: stagger || 0.02 }, t);
          }
          function words(sel, text) {
            const box = document.querySelector(sel);
            text.split(" ").forEach((w, i, all) => {
              const s = document.createElement("span");
              s.className = "tok";
              s.textContent = i < all.length - 1 ? w + " " : w;
              box.appendChild(s);
            });
            return box.querySelectorAll(".tok");
          }
          function pop(sel, t, origin) {
            tl.fromTo(sel, { opacity: 0, y: 24, scale: 0.9, transformOrigin: origin || "50% 50%" }, { opacity: 1, y: 0, scale: 1, duration: 0.45, ease: "back.out(1.8)" }, t);
          }
          function headIn(sel, t) {
            tl.fromTo(sel + " .w", { opacity: 0, y: 40, rotationX: -50 }, { opacity: 1, y: 0, rotationX: 0, duration: 0.45, ease: "expo.out", stagger: 0.045 }, t);
          }
          function out(sel, t, d) {
            tl.to(sel, { opacity: 0, y: -20, filter: "blur(6px)", duration: d || 0.25, ease: "power2.in" }, t);
          }
          // Spotlight: dim every line of a box except [a, b], then restore.
          function focus(boxSel, a, b, t, dur) {
            const lines = Array.from(document.querySelectorAll(boxSel + " .ln"));
            const dim = lines.filter((l) => +l.dataset.ln < a || +l.dataset.ln > b);
            if (dim.length) {
              tl.to(dim, { opacity: 0.28, duration: 0.25, ease: "power2.out" }, t);
              tl.to(dim, { opacity: 1, duration: 0.25, ease: "power2.out" }, t + dur);
            }
          }
          // Swap one after box for another at the same place (flip down / up).
          function swapBox(fromSel, toSel, t) {
            tl.to(fromSel + " .t", { opacity: 0, y: -26, duration: 0.18, ease: "power2.in", stagger: 0.004 }, t);
            tl.fromTo(toSel + " .t", { opacity: 0, y: 26 }, { opacity: 1, y: 0, duration: 0.3, ease: "back.out(2)", stagger: 0.006 }, t + 0.12);
          }
          // ---- end engine ----
