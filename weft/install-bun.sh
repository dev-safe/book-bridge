#!/usr/bin/env bash

curl -fsSL https://bun.sh/install | bash

echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
