"""
translator_view.py  — Two-Way Sign <-> Speech Translator
"""
from queue import SimpleQueue

import customtkinter as ctk

BG      = "#0f1117"
CARD    = "#1a1d27"
ACCENT  = "#6c63ff"
ACCENT2 = "#00d4aa"
TXT     = "#e8eaf6"
MUTED   = "#5c6080"
SUCCESS = "#4caf50"
WARNING = "#ff9800"


class TranslatorView(ctk.CTkFrame):
    """Live Sign-to-Text and Speech-to-Sign panel."""

    def __init__(self, master, tracker, speech_engine, **kwargs):
        super().__init__(master, fg_color=BG, **kwargs)
        self.tracker    = tracker
        self.speech     = speech_engine
        self.transcript = []
        self.listening  = False
        self._after_id  = None
        self._voice_results = SimpleQueue()
        self._build_ui()
        self._poll_camera()

    # ──────────────────────────── UI BUILD ────────────────────────────────────
    def _build_ui(self):
        self.grid_columnconfigure(0, weight=3)
        self.grid_columnconfigure(1, weight=2)
        self.grid_rowconfigure(1, weight=1)

        # ── Header ─────────────────────────────────────────────────────────
        hdr = ctk.CTkFrame(self, fg_color=CARD, corner_radius=14)
        hdr.grid(row=0, column=0, columnspan=2,
                 sticky="ew", padx=18, pady=(18, 8))
        ctk.CTkLabel(hdr, text="🤟  Two-Way Translator",
                     font=ctk.CTkFont(size=20, weight="bold"),
                     text_color=TXT).pack(side="left", padx=18, pady=12)
        ctk.CTkLabel(hdr, text="Sign → Text  |  Voice → Sign",
                     font=ctk.CTkFont(size=13), text_color=MUTED
                     ).pack(side="left", padx=4)

        # ── LEFT: camera card ───────────────────────────────────────────────
        cam = ctk.CTkFrame(self, fg_color=CARD, corner_radius=16)
        cam.grid(row=1, column=0, sticky="nsew", padx=(18, 8), pady=8)
        cam.grid_rowconfigure(1, weight=1)
        cam.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(cam, text="📷  Live Camera",
                     font=ctk.CTkFont(size=14, weight="bold"),
                     text_color=ACCENT).grid(row=0, column=0, sticky="w",
                                             padx=16, pady=(12, 4))

        # placeholder label (acts as the camera canvas for now)
        self.cam_canvas = ctk.CTkLabel(
            cam,
            text="📷\n\nWaiting for the camera feed…\n\nCheck the sidebar status if it stays here.",
            font=ctk.CTkFont(size=13), text_color=MUTED,
            fg_color="#0a0c12", corner_radius=12,
            width=440, height=300)
        self.cam_canvas.grid(row=1, column=0, padx=12, pady=(4, 8), sticky="nsew")

        # Confidence row
        cr = ctk.CTkFrame(cam, fg_color="transparent")
        cr.grid(row=2, column=0, sticky="ew", padx=12, pady=4)
        ctk.CTkLabel(cr, text="Confidence:",
                     font=ctk.CTkFont(size=12), text_color=MUTED).pack(side="left")
        self.conf_bar = ctk.CTkProgressBar(
            cr, width=240, height=10,
            fg_color="#2a2d3a", progress_color=ACCENT2)
        self.conf_bar.set(0)
        self.conf_bar.pack(side="left", padx=10)
        self.conf_label = ctk.CTkLabel(
            cr, text="0 %", font=ctk.CTkFont(size=12), text_color=ACCENT2)
        self.conf_label.pack(side="left")

        # Detected sign row
        dr = ctk.CTkFrame(cam, fg_color="transparent")
        dr.grid(row=3, column=0, sticky="ew", padx=12, pady=(4, 12))
        ctk.CTkLabel(dr, text="Detected:",
                     font=ctk.CTkFont(size=12), text_color=MUTED).pack(side="left")
        self.sign_badge = ctk.CTkLabel(
            dr, text="  ---  ",
            font=ctk.CTkFont(size=14, weight="bold"),
            fg_color=ACCENT, text_color="#ffffff",
            corner_radius=8, padx=10, pady=4)
        self.sign_badge.pack(side="left", padx=10)
        ctk.CTkButton(
            dr, text="＋ Add to Transcript",
            width=160, height=30,
            fg_color=ACCENT2, hover_color="#00a88a",
            text_color="#000000", font=ctk.CTkFont(size=12, weight="bold"),
            corner_radius=8, command=self._add_sign
        ).pack(side="left", padx=6)

        # ── RIGHT: transcript + voice + lookup ─────────────────────────────
        right = ctk.CTkFrame(self, fg_color="transparent")
        right.grid(row=1, column=1, sticky="nsew", padx=(8, 18), pady=8)
        right.grid_rowconfigure(1, weight=1)
        right.grid_columnconfigure(0, weight=1)

        # Transcript card
        tc = ctk.CTkFrame(right, fg_color=CARD, corner_radius=16)
        tc.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        tc.grid_columnconfigure(0, weight=1)

        th = ctk.CTkFrame(tc, fg_color="transparent")
        th.grid(row=0, column=0, sticky="ew", padx=14, pady=(12, 6))
        ctk.CTkLabel(th, text="📝  Transcript",
                     font=ctk.CTkFont(size=14, weight="bold"),
                     text_color=ACCENT).pack(side="left")
        ctk.CTkButton(th, text="🗑 Clear", width=70, height=28,
                      fg_color="#3a1f1f", hover_color="#5a2f2f",
                      font=ctk.CTkFont(size=12), corner_radius=8,
                      command=self._clear_transcript).pack(side="right")
        ctk.CTkButton(th, text="🔊 Speak", width=80, height=28,
                      fg_color=ACCENT, hover_color="#4a41d0",
                      font=ctk.CTkFont(size=12), corner_radius=8,
                      command=self._speak_transcript).pack(side="right", padx=6)

        self.transcript_box = ctk.CTkTextbox(
            tc, height=120, corner_radius=10,
            fg_color="#0f1117", text_color=TXT,
            font=ctk.CTkFont(size=14))
        self.transcript_box.grid(row=1, column=0, padx=12,
                                 pady=(0, 12), sticky="ew")
        self.transcript_box.configure(state="disabled")

        # Voice listener card
        vc = ctk.CTkFrame(right, fg_color=CARD, corner_radius=16)
        vc.grid(row=1, column=0, sticky="nsew", pady=(0, 8))
        vc.grid_columnconfigure(0, weight=1)
        vc.grid_rowconfigure(2, weight=1)

        ctk.CTkLabel(vc, text="🎙  Voice → Sign",
                     font=ctk.CTkFont(size=14, weight="bold"),
                     text_color=ACCENT
                     ).grid(row=0, column=0, sticky="w", padx=14, pady=(12, 6))

        self.mic_btn = ctk.CTkButton(
            vc, text="🎤  Start Listening",
            height=44, corner_radius=12,
            fg_color=SUCCESS, hover_color="#388e3c",
            font=ctk.CTkFont(size=14, weight="bold"),
            command=self._toggle_listen)
        self.mic_btn.grid(row=1, column=0, padx=14, pady=6, sticky="ew")

        self.voice_result = ctk.CTkTextbox(
            vc, height=90, corner_radius=10,
            fg_color="#0f1117", text_color=TXT,
            font=ctk.CTkFont(size=13))
        self.voice_result.grid(row=2, column=0, padx=12,
                               pady=(4, 12), sticky="nsew")
        self.voice_result.insert("end", "Recognised speech will appear here…")
        self.voice_result.configure(state="disabled")

        self.voice_sign_result = ctk.CTkLabel(
            vc, text="Say a supported word, e.g. 'Hello' or 'Thank You'.",
            font=ctk.CTkFont(size=12), text_color=ACCENT2,
            wraplength=330, justify="left",
        )
        self.voice_sign_result.grid(row=3, column=0, padx=14, pady=(0, 12), sticky="ew")

        # Sign lookup card
        lc = ctk.CTkFrame(right, fg_color=CARD, corner_radius=16)
        lc.grid(row=2, column=0, sticky="ew")
        lc.grid_columnconfigure(1, weight=1)

        ctk.CTkLabel(lc, text="🔍 Sign for:",
                     font=ctk.CTkFont(size=12), text_color=MUTED
                     ).grid(row=0, column=0, padx=(14, 6), pady=12)
        self.lookup_entry = ctk.CTkEntry(
            lc, placeholder_text="e.g. Hello",
            height=32, corner_radius=8,
            fg_color="#0f1117", text_color=TXT, border_color=ACCENT)
        self.lookup_entry.grid(row=0, column=1, sticky="ew", pady=12)
        ctk.CTkButton(lc, text="Look up", width=80, height=32,
                      fg_color=ACCENT, hover_color="#4a41d0",
                      font=ctk.CTkFont(size=12), corner_radius=8,
                      command=self._lookup_sign
                      ).grid(row=0, column=2, padx=(6, 14), pady=12)

        self.lookup_result = ctk.CTkLabel(
            lc, text="",
            font=ctk.CTkFont(size=12), text_color=ACCENT2, wraplength=280)
        self.lookup_result.grid(row=1, column=0, columnspan=3,
                                padx=14, pady=(0, 10))

    # ────────────────────────── ACTIONS ──────────────────────────────────────
    def _add_sign(self):
        label = self.sign_badge.cget("text").strip()
        if label and label != "---":
            self.transcript.append(label)
            self._refresh_transcript()

    def _refresh_transcript(self):
        self.transcript_box.configure(state="normal")
        self.transcript_box.delete("1.0", "end")
        self.transcript_box.insert("end", "  ".join(self.transcript))
        self.transcript_box.configure(state="disabled")

    def _speak_transcript(self):
        text = "  ".join(self.transcript)
        if text:
            self.speech.speak(text)

    def _clear_transcript(self):
        self.transcript.clear()
        self._refresh_transcript()

    def _toggle_listen(self):
        if not self.listening:
            self.listening = True
            self.mic_btn.configure(
                text="⏹  Stop Listening",
                fg_color=WARNING, hover_color="#e65100")
            if not self.speech.listen(self._queue_voice_result):
                self.listening = False
                self._on_voice_result("[Speech input is unavailable.]")
        else:
            self.listening = False
            self.speech.cancel_listen()
            self.mic_btn.configure(
                text="🎤  Start Listening",
                fg_color=SUCCESS, hover_color="#388e3c")

    def _queue_voice_result(self, text: str):
        """Receive worker-thread speech results without touching Tk widgets."""
        self._voice_results.put(text)

    def _on_voice_result(self, text: str):
        self.voice_result.configure(state="normal")
        self.voice_result.delete("1.0", "end")
        self.voice_result.insert("end", text)
        self.voice_result.configure(state="disabled")
        self.listening = False
        self.mic_btn.configure(
            text="🎤  Start Listening",
            fg_color=SUCCESS, hover_color="#388e3c")
        self._show_voice_sign(text)

    def _show_voice_sign(self, text: str):
        """Turn recognised speech into a local sign reference instruction."""
        from core.gesture_model import load_dictionary

        if text.startswith("["):
            self.voice_sign_result.configure(text="Voice input needs attention; see the message above.")
            return

        dictionary = load_dictionary()
        spoken = text.casefold()
        match = next(
            (sign for sign in sorted(dictionary, key=len, reverse=True)
             if sign.casefold() in spoken),
            None,
        )
        if match:
            self.lookup_entry.delete(0, "end")
            self.lookup_entry.insert(0, match)
            self.lookup_result.configure(text=f"👐 {dictionary[match]}")
            self.voice_sign_result.configure(
                text=f"Sign instruction: {match} — {dictionary[match]}"
            )
        else:
            supported = ", ".join(dictionary)
            self.voice_sign_result.configure(
                text=f"No sign reference found for that phrase. Try: {supported}."
            )

    def _lookup_sign(self):
        from core.gesture_model import load_dictionary
        word = self.lookup_entry.get().strip()
        d    = load_dictionary()
        hint = d.get(word, d.get(word.capitalize(),
               "Not found. Try: Hello, Yes, No, A-E, Thank You…"))
        self.lookup_result.configure(text=f"👐 {hint}")

    # ─────────────────────── CAMERA POLL ────────────────────────────────────
    def _poll_camera(self):
        while not self._voice_results.empty():
            self._on_voice_result(self._voice_results.get())

        ctk_img, gesture, confidence = self.tracker.get_frame()

        if gesture and gesture != "---":
            self.sign_badge.configure(text=f"  {gesture}  ")
            self.conf_bar.set(confidence / 100)
            self.conf_label.configure(text=f"{confidence} %")
        else:
            self.sign_badge.configure(text="  ---  ")
            self.conf_bar.set(0)
            self.conf_label.configure(text="0 %")

        if ctk_img is not None:
            # Store reference to prevent garbage collection, then display
            self._current_frame = ctk_img
            self.cam_canvas.configure(image=ctk_img, text="")
        # else: placeholder text stays visible

        self._after_id = self.after(33, self._poll_camera)   # ~30 fps

    def destroy(self):
        if self._after_id:
            self.after_cancel(self._after_id)
        super().destroy()
