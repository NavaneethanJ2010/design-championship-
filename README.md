# Sign Language Assistant

A Python desktop prototype for basic static sign recognition, speech output,
speech-to-text, and a practice tutor. The interface is built with
CustomTkinter; webcam landmarks come from MediaPipe.

## Run locally

Use Python 3.10 or 3.11 on Windows. From this folder:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python main.py
```

Allow Windows camera and microphone access if prompted. A missing device is
shown as **Unavailable** in the sidebar rather than silently reported as ready.

## What the camera can recognise

The rule-based recogniser uses one still frame and supports these static pose
targets: **A, B, C, D, E, Hello, and I Love You**. Its confidence is a
geometry-fit score, not a trained-model probability. Movement-dependent signs
such as *Thank You*, *Yes*, *No*, *Please*, and *Sorry* remain in the reference
dictionary for learning, but are intentionally not selected as tutor challenges.

## Saved tutor data

Each completed challenge appends a row to `data/progress_stats.csv` while
running from source. The columns are timestamp, sign, accuracy, points, total
score, and streak. In the packaged executable, the file is stored in
`%LOCALAPPDATA%\SignAssistant\progress_stats.csv` so it persists across app
updates.

## Build the Windows executable

After the dependencies are installed, run:

```powershell
.\build_exe.bat
```

The output is `dist\SignAssistant.exe`. The build script bundles the MediaPipe
task model and sign dictionary, which are required at runtime.

## Presentation and 45-second demo outline

1. Show the pipeline: **Webcam → MediaPipe hand landmarks → normalised
   geometry rules → CustomTkinter UI**.
2. Open Translator, demonstrate the skeleton, detected static sign, transcript
   button, and spoken playback.
3. Use voice input and show the recognised text.
4. Open Practice Tutor, complete one static-pose challenge, then point out the
   score, streak, live accuracy gauge, and saved CSV entry.
5. Close with the accessibility purpose and the clear limitation: this is a
   rule-based static-pose prototype, not a comprehensive sign-language model.
