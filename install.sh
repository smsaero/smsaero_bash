#!/bin/bash

INSTALL_DIR="/usr/local/bin"

cp lib/smsaero.sh $INSTALL_DIR
cp bin/smsaero_send.sh $INSTALL_DIR/smsaero_send

chmod +x $INSTALL_DIR/smsaero_send

if ! grep -q "source $INSTALL_DIR/smsaero.sh" ~/.bashrc; then
    echo "source $INSTALL_DIR/smsaero.sh" >> ~/.bashrc
fi

echo "Installation complete. Restart the terminal or execute 'source ~/.bashrc' to use the library."

