"""
tutor_view.py  — Gamified Sign-Language Practice Tutor
"""
import random
import customtkinter as ctk
from core.gesture_model import GestureModel, load_dictionary
from core.progress_store import ProgressStore

BG      = "#0f1117"
CARD    = "#1a1d27"
ACCENT  = "#6c63ff"
ACCENT2 = "#00d4aa"
TXT     = "#e8eaf6"
MUTED   = "#5c6080"
SUCCESS = "#4caf50"
WARNING = "#ff9800"
DANGER  = "#f44336"


class TutorView(ctk.CTkFrame):
    """Interactive sign-practice challenge panel."""

    # Motion signs are useful reference material but cannot be fairly graded
    # from a single camera frame, so only static recognisable poses are used.
    CHALLENGES = list(GestureModel.supported_signs)

    def __init__(self, master, tracker, **kwargs):
        super().__init__(master, fg_color=BG, **kwargs)
        self.tracker      = tracker
        self.score        = 0
        self.streak       = 0
        self.best_streak  = 0
        self.current      = ""
        self.accuracy     = 0
        self._after_id    = None
        self._next_after_id = None
        self._challenge_complete = False
        self.progress = ProgressStore()

        # stat labels stored as instance attrs (no fragile introspection)
        self.score_lbl    = None
        self.streak_lbl   = None
        self.best_lbl     = None
        self.acc_lbl      = None

        self._build_ui()
        self._next_challenge()
        self._poll_loop()

    # ─────────────────────────────── UI BUILD ────────────────────────────────
    def _build_ui(self):
        self.grid_columnconfigure(0, weight=1)
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(2, weight=1)

        # ── Stats bar ──────────────────────────────────────────────────────
        stats_frame = ctk.CTkFrame(self, fg_color=CARD, corner_radius=14)
        stats_frame.grid(row=0, column=0, columnspan=2,
                         sticky="ew", padx=18, pady=(18, 8))
        stats_frame.grid_columnconfigure((0, 1, 2, 3), weight=1)

        self.score_lbl  = self._make_stat(stats_frame, "🏆 Score", 0)
        self.streak_lbl = self._make_stat(stats_frame, "🔥 Streak", 1)
        self.best_lbl   = self._make_stat(stats_frame, "⭐ Best Streak", 2)
        self.acc_lbl    = self._make_stat(stats_frame, "✅ Accuracy", 3)

        # ── Challenge card (left column) ───────────────────────────────────
        cc = ctk.CTkFrame(self, fg_color=CARD, corner_radius=16)
        cc.grid(row=1, column=0, sticky="nsew", padx=(18, 8), pady=8)
        cc.grid_rowconfigure(3, weight=1)
        cc.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(cc, text="Make the sign for:",
                     font=ctk.CTkFont(size=14), text_color=MUTED
                     ).grid(row=0, column=0, pady=(18, 4))

        self.challenge_lbl = ctk.CTkLabel(
            cc, text="",
            font=ctk.CTkFont(size=46, weight="bold"), text_color=ACCENT)
        self.challenge_lbl.grid(row=1, column=0, pady=8)

        self.hint_lbl = ctk.CTkLabel(
            cc, text="",
            font=ctk.CTkFont(size=12), text_color=MUTED, wraplength=280)
        self.hint_lbl.grid(row=2, column=0, padx=18, pady=4)

        # Accuracy gauge
        gf = ctk.CTkFrame(cc, fg_color="transparent")
        gf.grid(row=3, column=0, sticky="ew", padx=18, pady=8)
        ctk.CTkLabel(gf, text="Live accuracy match:",
                     font=ctk.CTkFont(size=12), text_color=MUTED).pack(anchor="w")
        self.acc_bar = ctk.CTkProgressBar(
            gf, height=18, corner_radius=9,
            fg_color="#2a2d3a", progress_color=ACCENT2)
        self.acc_bar.set(0)
        self.acc_bar.pack(fill="x", pady=(4, 2))
        self.acc_pct_lbl = ctk.CTkLabel(
            gf, text="0 %",
            font=ctk.CTkFont(size=13, weight="bold"), text_color=ACCENT2)
        self.acc_pct_lbl.pack(anchor="e")

        # Feedback
        self.feedback_lbl = ctk.CTkLabel(
            cc, text="",
            font=ctk.CTkFont(size=15, weight="bold"), text_color=SUCCESS)
        self.feedback_lbl.grid(row=4, column=0, pady=(4, 8))

        # Buttons
        br = ctk.CTkFrame(cc, fg_color="transparent")
        br.grid(row=5, column=0, pady=(4, 18))
        ctk.CTkButton(br, text="⏭  Next",
                      width=130, height=40, corner_radius=10,
                      fg_color=ACCENT, hover_color="#4a41d0",
                      font=ctk.CTkFont(size=13, weight="bold"),
                      command=self._next_challenge).pack(side="left", padx=5)
        ctk.CTkButton(br, text="💡 Hint",
                      width=100, height=40, corner_radius=10,
                      fg_color="#2a2d3a", hover_color="#3a3f5a",
                      font=ctk.CTkFont(size=13),
                      command=self._show_hint).pack(side="left", padx=5)
        ctk.CTkButton(br, text="🔄 Reset",
                      width=90, height=40, corner_radius=10,
                      fg_color="#3a1f1f", hover_color="#5a2f2f",
                      font=ctk.CTkFont(size=13),
                      command=self._reset_game).pack(side="left", padx=5)

        # ── Activity log (right column) ────────────────────────────────────
        lc = ctk.CTkFrame(self, fg_color=CARD, corner_radius=16)
        lc.grid(row=1, column=1, sticky="nsew", padx=(8, 18), pady=8)
        lc.grid_rowconfigure(1, weight=1)
        lc.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(lc, text="📋  Activity Log",
                     font=ctk.CTkFont(size=14, weight="bold"), text_color=ACCENT
                     ).grid(row=0, column=0, sticky="w", padx=14, pady=(12, 6))

        self.log_box = ctk.CTkTextbox(
            lc, corner_radius=10,
            fg_color="#0f1117", text_color=TXT,
            font=ctk.CTkFont(size=12))
        self.log_box.grid(row=1, column=0, padx=12, pady=(0, 12), sticky="nsew")
        self.log_box.configure(state="disabled")

        # ── Sign reference grid (bottom row) ───────────────────────────────
        rc = ctk.CTkFrame(self, fg_color=CARD, corner_radius=16)
        rc.grid(row=2, column=0, columnspan=2, sticky="nsew",
                padx=18, pady=(0, 18))
        rc.grid_columnconfigure(0, weight=1)
        rc.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(rc, text="📖  Sign Reference",
                     font=ctk.CTkFont(size=14, weight="bold"), text_color=ACCENT
                     ).grid(row=0, column=0, sticky="w", padx=14, pady=(10, 6))

        ctk.CTkLabel(rc, text="Tutor challenges use the static poses recognised by the camera.",
                     font=ctk.CTkFont(size=11), text_color=MUTED
                     ).grid(row=0, column=0, sticky="e", padx=14, pady=(10, 6))

        scroll = ctk.CTkScrollableFrame(rc, fg_color="transparent", height=110)
        scroll.grid(row=1, column=0, sticky="nsew", padx=12, pady=(0, 12))

        dictionary = load_dictionary()
        cols = 4
        for i, (sign, desc) in enumerate(dictionary.items()):
            r, c = divmod(i, cols)
            scroll.grid_columnconfigure(c, weight=1)
            pill = ctk.CTkFrame(scroll, fg_color="#1e2130", corner_radius=10)
            pill.grid(row=r, column=c, padx=6, pady=4, sticky="ew")
            ctk.CTkLabel(pill, text=sign,
                         font=ctk.CTkFont(size=13, weight="bold"),
                         text_color=ACCENT2).pack(anchor="w", padx=8, pady=(6, 2))
            ctk.CTkLabel(pill, text=desc,
                         font=ctk.CTkFont(size=11), text_color=MUTED,
                         wraplength=160, justify="left"
                         ).pack(anchor="w", padx=8, pady=(0, 6))

    # ─────────────────────── STAT BOX HELPER ─────────────────────────────────
    def _make_stat(self, parent, label_text, col):
        """Build a stat tile and return the VALUE label so we can update it."""
        f = ctk.CTkFrame(parent, fg_color="#0f1117", corner_radius=12)
        f.grid(row=0, column=col, padx=10, pady=10, sticky="ew")
        ctk.CTkLabel(f, text=label_text,
                     font=ctk.CTkFont(size=12), text_color=MUTED).pack(pady=(8, 2))
        val_lbl = ctk.CTkLabel(f, text="0",
                               font=ctk.CTkFont(size=24, weight="bold"), text_color=TXT)
        val_lbl.pack(pady=(0, 8))
        return val_lbl          # <-- stored directly, no introspection needed

    # ────────────────────────── GAME LOGIC ───────────────────────────────────
    def _next_challenge(self):
        if self._next_after_id:
            # This also handles a user pressing Next during the success delay.
            try:
                self.after_cancel(self._next_after_id)
            except Exception:
                pass
        self._next_after_id = None
        choices = [sign for sign in self.CHALLENGES if sign != self.current]
        self.current  = random.choice(choices or self.CHALLENGES)
        self.accuracy = 0
        self._challenge_complete = False
        self.feedback_lbl.configure(text="")
        self.hint_lbl.configure(text="")
        self.acc_bar.set(0)
        self.acc_pct_lbl.configure(text="0 %")
        self.challenge_lbl.configure(text=self.current)

    def _show_hint(self):
        hint = load_dictionary().get(self.current, "No hint available")
        self.hint_lbl.configure(text=f"💡 {hint}")

    def _reset_game(self):
        if self._next_after_id:
            self.after_cancel(self._next_after_id)
            self._next_after_id = None
        self.score = self.streak = self.best_streak = 0
        self._refresh_stats()
        self._log("— Game reset —")
        self._next_challenge()

    def _refresh_stats(self):
        self.score_lbl.configure(text=str(self.score))
        self.streak_lbl.configure(text=str(self.streak))
        self.best_lbl.configure(text=str(self.best_streak))
        self.acc_lbl.configure(text=f"{int(self.accuracy)} %")

    def _log(self, msg: str):
        self.log_box.configure(state="normal")
        self.log_box.insert("end", msg + "\n")
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    # ─────────────────────── CAMERA POLL LOOP ────────────────────────────────
    def _poll_loop(self):
        _, gesture, confidence = self.tracker.get_frame()

        self.accuracy = confidence
        self.acc_bar.set(confidence / 100)
        self.acc_pct_lbl.configure(text=f"{confidence} %")

        if (not self._challenge_complete
                and gesture == self.current
                and confidence >= 80):
            self._challenge_complete = True
            self.score  += 10
            self.streak += 1
            if self.streak > self.best_streak:
                self.best_streak = self.streak
            self.feedback_lbl.configure(text="✅ Correct! +10 pts", text_color=SUCCESS)
            self._log(f"✅  {self.current}  —  {confidence}% match  (+10)")
            try:
                self.progress.record(
                    sign=self.current,
                    accuracy=confidence,
                    points=10,
                    total_score=self.score,
                    streak=self.streak,
                )
            except Exception as error:
                self._log(f"⚠ Could not save progress: {error}")
            self._refresh_stats()
            self._next_after_id = self.after(1200, self._next_challenge)
        elif not self._challenge_complete:
            self.feedback_lbl.configure(text="")

        self._refresh_stats()
        self._after_id = self.after(100, self._poll_loop)

    def destroy(self):
        if self._after_id:
            self.after_cancel(self._after_id)
        if self._next_after_id:
            self.after_cancel(self._next_after_id)
        super().destroy()
