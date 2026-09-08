"""
main.py  — Application entry point
Run:  python main.py
"""
import sys, os
# make sure project root is on the path
sys.path.insert(0, os.path.dirname(__file__))

from ui.app import run

if __name__ == "__main__":
    run()
