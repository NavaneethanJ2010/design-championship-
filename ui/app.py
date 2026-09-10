"""
app.py
Root window + sidebar navigation shell.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import customtkinter as ctk
from ui.translator_view import TranslatorView
from ui.tutor_view       import TutorView
from core.vision_tracker import VisionTracker
from core.speech_engine  import SpeechEngine

# ── global palette ─────────────────────────────────────────────────────────────
BG       = "#0f1117"
SIDEBAR  = "#13151f"
ACCENT   = "#6c63ff"
ACCENT2  = "#00d4aa"
TXT      = "#e8eaf6"
MUTED    = "#5c6080"
SEL_BG   = "#1e2032"

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")


class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Sign Language Assistant")
        self.geometry("1100x680")
        self.minsize(900, 580)
        self.configure(fg_color=BG)

        # Shared services are owned by the root so only one camera is opened.
        self.tracker = VisionTracker()
        self.speech  = SpeechEngine()

        self._active_btn  = None
        self._active_view = None
        self._status_after_id = None

        self._build_sidebar()
        self._build_content_area()

        # default view
        self._show_view("translator")
        self._refresh_backend_status()

        self.protocol("WM_DELETE_WINDOW", self._on_close)

    # ── Layout ────────────────────────────────────────────────────────────────
    def _build_sidebar(self):
        self.sidebar = ctk.CTkFrame(self, width=210, fg_color=SIDEBAR, corner_radius=0)
        self.sidebar.pack(side="left", fill="y")
        self.sidebar.pack_propagate(False)

        # logo area
        logo_frame = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        logo_frame.pack(fill="x", pady=(24, 10))

        ctk.CTkLabel(
            logo_frame,
            text="🤟",
            font=ctk.CTkFont(size=36)
        ).pack()
        ctk.CTkLabel(
            logo_frame,
            text="Sign Assistant",
            font=ctk.CTkFont(size=16, weight="bold"),
            text_color=TXT
        ).pack()
        ctk.CTkLabel(
            logo_frame,
            text="v1.0  •  Python Edition",
            font=ctk.CTkFont(size=10),
            text_color=MUTED
        ).pack(pady=(2, 0))

        ctk.CTkFrame(self.sidebar, height=1, fg_color="#2a2d3a").pack(
            fill="x", padx=16, pady=14)

        # nav label
        ctk.CTkLabel(
            self.sidebar, text="NAVIGATE",
            font=ctk.CTkFont(size=10, weight="bold"),
            text_color=MUTED
        ).pack(anchor="w", padx=18, pady=(0, 6))

        # nav buttons
        self.btn_translator = self._nav_btn("🔄   Translator", "translator")
        self.btn_tutor      = self._nav_btn("🎓   Practice Tutor", "tutor")

        # spacer + status card
        ctk.CTkFrame(self.sidebar, fg_color="transparent").pack(fill="y", expand=True)

        status_card = ctk.CTkFrame(self.sidebar, fg_color="#1a1d27", corner_radius=12)
        status_card.pack(fill="x", padx=12, pady=(0, 16))

        ctk.CTkLabel(status_card, text="⚙️  Backend Status",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=MUTED).pack(anchor="w", padx=12, pady=(10, 4))

        self.camera_status = self._status_row(status_card, "Camera")
        self.model_status = self._status_row(status_card, "AI Model")
        self.speech_status = self._status_row(status_card, "Voice Input")

        ctk.CTkFrame(status_card, height=1, fg_color="#2a2d3a").pack(
            fill="x", padx=8, pady=(6, 10)
        )

    def _status_row(self, parent, label):
        row = ctk.CTkFrame(parent, fg_color="transparent")
        row.pack(fill="x", padx=12, pady=1)
        ctk.CTkLabel(row, text=label+":", font=ctk.CTkFont(size=11),
                     text_color=MUTED, width=70, anchor="w").pack(side="left")
        value = ctk.CTkLabel(row, text="Checking…", font=ctk.CTkFont(size=11),
                             text_color=MUTED)
        value.pack(side="left")
        return value

    def _nav_btn(self, text, view_name):
        btn = ctk.CTkButton(
            self.sidebar,
            text=text,
            height=44, corner_radius=10,
            anchor="w",
            fg_color="transparent",
            hover_color=SEL_BG,
            text_color=MUTED,
            font=ctk.CTkFont(size=14),
            command=lambda n=view_name: self._show_view(n)
        )
        btn.pack(fill="x", padx=10, pady=3)
        return btn

    def _build_content_area(self):
        self.content = ctk.CTkFrame(self, fg_color=BG, corner_radius=0)
        self.content.pack(side="left", fill="both", expand=True)
        self.content.grid_rowconfigure(0, weight=1)
        self.content.grid_columnconfigure(0, weight=1)

    def _refresh_backend_status(self):
        """Show actual device/module availability instead of fixed green labels."""
        statuses = (
            (self.camera_status, self.tracker.camera_available),
            (self.model_status, self.tracker.model_available),
            (self.speech_status, self.speech.input_available),
        )
        for label, available in statuses:
            label.configure(
                text="● Ready" if available else "● Unavailable",
                text_color=ACCENT2 if available else "#f44336",
            )
        self._status_after_id = self.after(1500, self._refresh_backend_status)

    # ── Navigation ────────────────────────────────────────────────────────────
    def _show_view(self, name: str):
        # deselect previous button
        for btn in (self.btn_translator, self.btn_tutor):
            btn.configure(fg_color="transparent", text_color=MUTED)

        # destroy old view
        if self._active_view:
            self._active_view.destroy()
            self._active_view = None

        if name == "translator":
            self.btn_translator.configure(fg_color=SEL_BG, text_color=TXT)
            self._active_view = TranslatorView(
                self.content, self.tracker, self.speech)
        elif name == "tutor":
            self.btn_tutor.configure(fg_color=SEL_BG, text_color=TXT)
            self._active_view = TutorView(
                self.content, self.tracker)

        if self._active_view:
            self._active_view.grid(row=0, column=0, sticky="nsew")

    # ── Cleanup ───────────────────────────────────────────────────────────────
    def _on_close(self):
        if self._status_after_id:
            self.after_cancel(self._status_after_id)
        if self._active_view:
            self._active_view.destroy()
        self.tracker.release()
        self.destroy()


def run():
    app = App()
    app.mainloop()
