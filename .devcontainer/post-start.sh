#!/bin/bash

# Post-Start Script - Runs every time the container starts
echo "🔄 Starting services..."

# Start PostgreSQL
sudo service postgresql start

# Start RStudio Server
sudo systemctl start rstudio-server

# Load database credentials
source ~/.pg_credentials 2>/dev/null || true

# Add to bashrc if not already there
if ! grep -q "source ~/.pg_credentials" ~/.bashrc; then
    echo "source ~/.pg_credentials 2>/dev/null || true" >> ~/.bashrc
fi

# Create helpful aliases
cat >> ~/.bashrc << 'EOF'

# Data Science Environment Aliases
alias jlab='jupyter lab --ip=0.0.0.0 --port=8888 --no-browser'
alias jnb='jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser'  
alias r-console='R'
alias dblist='./db-manager.sh list'
alias dbcreate='./db-manager.sh create'
alias dbconnect='./db-manager.sh connect'
alias workspace='cd /workspaces'
EOF

echo "✅ Services started and environment configured!"

# Navigate to workspace
cd /workspaces/$(basename $GITHUB_REPOSITORY) 2>/dev/null || cd /workspaces
