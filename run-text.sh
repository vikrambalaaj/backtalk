#!/bin/bash
# backtalk text mode — mic input, screen output, no TTS.
# Same as run.sh but passes --text-mode to disable spoken replies.
cd "$(dirname "$0")"
exec ./run.sh --text-mode
