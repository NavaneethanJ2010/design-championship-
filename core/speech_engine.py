"""Threaded text-to-speech and speech-to-text helpers.

Callbacks intentionally run on a worker thread. UI callers must put results in
a queue and render them from their GUI event loop.
"""
from __future__ import annotations

import threading
from collections.abc import Callable

try:
    import pyttsx3
    import speech_recognition as sr
except ImportError:  # Allows the rest of the application to start with clear UI feedback.
    pyttsx3 = None
    sr = None

try:
    import sounddevice as sd
except ImportError:
    sd = None


class SpeechEngine:
    """Non-blocking speech service with one listener and serialised TTS."""

    def __init__(self) -> None:
        self.engine = None
        self.recognizer = None
        self._speech_lock = threading.Lock()
        self._listen_lock = threading.Lock()
        self._listen_cancel = threading.Event()
        self._listening = False
        self.last_error = ""
        self._use_pyaudio = False

        if pyttsx3 is not None and sr is not None:
            try:
                self.engine = pyttsx3.init()
                self.engine.setProperty("rate", 150)
                self.recognizer = sr.Recognizer()
                try:
                    sr.Microphone.get_pyaudio()
                    self._use_pyaudio = True
                except AttributeError:
                    # MediaPipe includes sounddevice on current Windows builds.
                    # It is a reliable microphone backend when PyAudio has no
                    # wheel for the user's Python version.
                    if sd is None:
                        self.last_error = "Install PyAudio or sounddevice to use microphone input."
            except Exception as error:
                self.last_error = str(error)
                self.engine = None
                self.recognizer = None
                print(f"[SpeechEngine] Initialisation failed: {error}")
        else:
            self.last_error = "SpeechRecognition and pyttsx3 are not installed."

    @property
    def available(self) -> bool:
        return self.engine is not None and self.recognizer is not None

    @property
    def input_available(self) -> bool:
        """Whether a supported backend exists for microphone capture."""
        return self.recognizer is not None and (self._use_pyaudio or sd is not None)

    @property
    def listening(self) -> bool:
        with self._listen_lock:
            return self._listening

    def speak(self, text: str) -> bool:
        """Speak text in a daemon thread. Returns whether speech is available."""
        text = text.strip()
        if not text or self.engine is None:
            return False

        def worker() -> None:
            # pyttsx3 is not safe to drive concurrently from multiple threads.
            with self._speech_lock:
                try:
                    self.engine.say(text)
                    self.engine.runAndWait()
                except Exception as error:
                    self.last_error = str(error)
                    print(f"[SpeechEngine] Speech error: {error}")

        threading.Thread(target=worker, daemon=True, name="sign-assistant-tts").start()
        return True

    def listen(self, callback: Callable[[str], None]) -> bool:
        """Capture one short utterance asynchronously and invoke ``callback`` once."""
        if not self.input_available or sr is None:
            callback("[Speech input is unavailable. Install PyAudio or sounddevice.]")
            return False

        with self._listen_lock:
            if self._listening:
                return False
            self._listening = True
            self._listen_cancel.clear()

        def finish(message: str) -> None:
            with self._listen_lock:
                cancelled = self._listen_cancel.is_set()
                self._listening = False
            if not cancelled:
                callback(message)

        def worker() -> None:
            try:
                if self._use_pyaudio:
                    with sr.Microphone() as source:
                        self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                        audio = self.recognizer.listen(source, timeout=5, phrase_time_limit=5)
                else:
                    # Record a short, mono 16 kHz clip using sounddevice, then
                    # hand it to SpeechRecognition for transcription.
                    recording = sd.rec(
                        int(5 * 16_000), samplerate=16_000,
                        channels=1, dtype="int16",
                    )
                    sd.wait()
                    audio = sr.AudioData(recording.tobytes(), 16_000, 2)
                finish(self.recognizer.recognize_google(audio))
            except sr.WaitTimeoutError:
                finish("[No speech detected - timed out]")
            except sr.UnknownValueError:
                finish("[Could not understand audio]")
            except sr.RequestError as error:
                finish(f"[Speech recognition service error: {error}]")
            except Exception as error:
                finish(f"[Microphone error: {error}]")

        threading.Thread(target=worker, daemon=True, name="sign-assistant-stt").start()
        return True

    def cancel_listen(self) -> None:
        """Ignore the eventual result of the active microphone operation."""
        with self._listen_lock:
            self._listen_cancel.set()
            self._listening = False
