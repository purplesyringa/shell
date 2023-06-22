# shell

Alisa Sireneva's dynamic replacement for bash's PS1 written mainly in bash.

```
. shell.sh                 # for nerdfont mode
PS1_MODE=text . shell.sh   # for text mode
```

Execute in bash shell or add to your `.bashrc`.

Two modes are available --- "nerdfont" and "text", former is default, latter is toggled by setting `PS1_MODE=text` before applying prompt.

# What does

Pure bash (kind of) implementation of "git status into PS1" which does not break on empty repos; output format taken from [p10k](https://github.com/romkatv/powerlevel10k).

Replace `/path/to/home/yuki` with `~yuki` if home directory of user `yuki` when using any other user.

