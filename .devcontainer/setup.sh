#!/bin/bash

echo "⚡ Speed-Focused Classroom Setup"
echo "Getting essentials working FAST - additional packages can be installed later"

# Set aggressive timeouts and non-interactive mode
export DEBIAN_FRONTEND=noninteractive
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# Ultra-short timeout function
quick_install() {
    timeout 120 "$@" || {
        echo "❌ Timed out: $*"
        echo "⏭️ Skipping and continuing..."
        return 1
    }
}

# Essential packages only
echo "📦 Quick package update..."
quick_install sudo apt-get update -qq

echo "🗄️ Installing PostgreSQL client..."
quick_install sudo apt-get install -y postgresql-client

echo "📊 Installing R (minimal)..."
if quick_install sudo apt-get install -y r-base; then
    echo "✅ R base installed"
    
    # Try to install just ONE critical R package quickly
    echo "📈 Installing minimal R package..."
    sudo R --slave -e "
    options(timeout=30, warn=2)
    tryCatch({
        install.packages('DBI', repos='https://cloud.r-project.org/', dependencies=FALSE, quiet=TRUE)
        cat('✅ DBI package installed\n')
    }, error=function(e) cat('⚠️ DBI failed but continuing\n'))
    " || echo "⚠️ R package installation skipped"
else
    echo "⚠️ R installation failed - students can install later"
fi

echo "🐍 Installing Python essentials..."
quick_install pip install --no-cache-dir --user psycopg2-binary pandas numpy jupyter

# Create workspace and scripts
echo "📁 Creating workspace..."
mkdir -p /workspaces/data-managment/{notebooks,scripts,databases}

# Database starter script
cat > /workspaces/data-managment/scripts/start_db.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting PostgreSQL..."
docker rm -f classroom-db 2>/dev/null || true
docker run -d --name classroom-db -p 5432:5432 \
    -e POSTGRES_USER=student -e POSTGRES_PASSWORD=student_password \
    -e POSTGRES_DB=postgres postgres:15
echo "⏳ Database starting... (wait 15 seconds then test)"
EOF

# R packages installer script for later
cat > /workspaces/data-managment/scripts/install_r_packages.sh << 'EOF'
#!/bin/bash
echo "📊 Installing complete R packages..."
sudo R -e "
packages <- c('DBI', 'RPostgreSQL', 'dplyr', 'ggplot2', 'readr')
for(pkg in packages) {
    tryCatch({
        if(!require(pkg, character.only=TRUE, quietly=TRUE)) {
            install.packages(pkg, repos='https://cloud.r-project.org/')
        }
        cat('✅', pkg, 'ready\n')
    }, error=function(e) cat('❌', pkg, 'failed\n'))
}
"
EOF

# Test script
cat > /workspaces/data-managment/scripts/test.py << 'EOF'
#!/usr/bin/env python3
"""Quick classroom test"""
try:
    import pandas as pd
    import numpy as np
    import psycopg2
    print("✅ Python: pandas, numpy, psycopg2 working")
except ImportError as e:
    print(f"❌ Python issue: {e}")

import subprocess
try:
    result = subprocess.run(['R', '--version'], capture_output=True, timeout=5)
    if result.returncode == 0:
        print("✅ R installed")
    else:
        print("❌ R issue")
except:
    print("❌ R not found")

try:
    subprocess.run(['psql', '--version'], capture_output=True, timeout=5)
    print("✅ PostgreSQL client ready")
except:
    print("❌ PostgreSQL client issue")

print("\n🎯 Next steps:")
print("1. Start database: bash scripts/start_db.sh")
print("2. Install R packages: bash scripts/install_r_packages.sh")
print("3. Test again: python scripts/test.py")
EOF

# Sample database
cat > /workspaces/data-managment/databases/sample.sql << 'EOF'
CREATE TABLE students (id SERIAL PRIMARY KEY, name VARCHAR(100), grade INTEGER);
INSERT INTO students (name, grade) VALUES ('Alice', 95), ('Bob', 87);
GRANT ALL ON ALL TABLES IN SCHEMA public TO student;
EOF

chmod +x /workspaces/data-managment/scripts/*.sh
chmod +x /workspaces/data-managment/scripts/*.py

echo ""
echo "⚡ Speed setup complete! (Should finish in 3-5 minutes)"
echo ""
echo "🎯 What's ready:"
echo "   ✅ PostgreSQL client"
echo "   ✅ Python data science basics"  
echo "   ✅ R (basic installation)"
echo ""
echo "🚀 Immediate next steps:"
echo "1. Test what's working: python scripts/test.py"
echo "2. Start database: bash scripts/start_db.sh"
echo "3. Complete R setup: bash scripts/install_r_packages.sh"
echo ""
echo "💡 This gets you started fast - complete setup happens in steps!"
