# agy-patcher

Antigravity CLI incorrectly logs error messages when it receives `EAGAIN`. This
causes the log in ~/.gemini/antigravity-cli/log/ to grow to enormous size (one
time I left agy running overnight, and woke up to find no space in home
directory, and log being hundres of gigabytes).

This script tries to hack agy binary, installed as FreeBSD port, to prevent
this logging.

Run it with root rights. It might do what you want, or it might kill your cat.
You've been warned.

License is [BSD 2-clause](LICENSE).
