# shell

Alisa Sireneva's dynamic replacement for bash's PS1 written mainly in bash.

> **This project is no longer actively maintained. Consider using [Yuki's Rust port instead](https://github.com/yuki0iq/bash-status-line-2).**

## Usage

```
. shell.sh                 # for nerdfont mode
PS1_MODE=text . shell.sh   # for text mode
```

Execute in bash shell or add to your `.bashrc`.

Two modes are available --- "nerdfont" and "text", former is default, latter is toggled by setting `PS1_MODE=text` before applying prompt.

## Requirements

- `bash`
- `ripgrep`
- maybe something else

## What does

Pure bash (kind of) implementation of "git status into PS1" which does not break on empty repos; output format taken from [p10k](https://github.com/romkatv/powerlevel10k).

Replace `/path/to/home/yuki` with `~yuki` if home directory of user `yuki` when using any other user.

