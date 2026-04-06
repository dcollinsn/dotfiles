go install github.com/justjanne/powerline-go@latest
cp powerlinegotheme.json ~/.local/config/

echo "Place the following in your shell RC"
cat << HERE
function _update_ps1() {
    export POWERLINE_GO_SHELL_VAR="dcollins"
    export POWERLINE_GO_MODULES="host,shell-var,ssh,cwd,perms,git,venv,exit,root"
    export POWERLINE_GO_SHELL_VAR_BG="blue"
    export POWERLINE_GO_SHELL_VAR_FG="white"
    export POWERLINE_GO_GIT_BRANCH_BG="darkgreen"
    export POWERLINE_GO_GIT_BRANCH_FG="white"
    PS1="\$(~/.local/bin/powerline-go -error \$? -modules host,shell-var,cwd,perms,git,venv,exit,root -shell-var POWERLINE_GO_SHELL_VAR -theme ~/.local/config/powerlinegotheme.json)"
}
PROMPT_COMMAND="_update_ps1"
HERE
