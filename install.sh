#!/usr/bin/env bash
#ps -ef | grep $$ | awk '{print $8}'
#exit
REPO="https://github.com/rbatista/gitlab-flow.git"

INSTALL_DIR=${1:-$HOME}
DIRNAME=".gitlab-flow"

echo "Installing into $INSTALL_DIR/$DIRNAME"

# Create the install directory if it doesn't exist.
[ -d "$INSTALL_DIR" ] || mkdir -p $INSTALL_DIR;

if [ $? -ne 0 ]; then 
  echo "Cannot create the install dir."
  exit 1
fi

cd $INSTALL_DIR

if [ -d "$DIRNAME" ]; then
    cd $DIRNAME
    echo "git-lab-flow already installed, update from origin." 
    git pull origin master
else
    git clone $REPO $DIRNAME
fi

# Only modify the path if the newly installed ghf doesn't exist.
if [ ! $(echo $PATH | fgrep "$INSTALL_DIR/$DIRNAME/bin") ] ; then
    echo "Adding $DIRNAME to path."
    [ -f "$HOME/.bashrc" ] && echo -e "\nexport PATH=$INSTALL_DIR/$DIRNAME/bin:\$PATH" >> $HOME/.bashrc
    [ -f "$HOME/.zshrc" ] && echo -e "\nexport PATH=$INSTALL_DIR/$DIRNAME/bin:\$PATH" >> $HOME/.zshrc

    if [ "x$BASH" != "x" ]; then source $HOME/.bashrc; fi
    if [ "x$ZSH_NAME" != "x" ]; then source $HOME/.zshrc; fi
fi

