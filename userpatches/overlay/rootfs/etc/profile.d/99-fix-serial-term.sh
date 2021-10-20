# fix terminal for UART user
if [ "$TERM" == "unknown" ]; then
    TERM="xterm"
fi

export TERM
