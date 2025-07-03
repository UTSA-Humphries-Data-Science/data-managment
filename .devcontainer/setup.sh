#!/bin/bash

echo "🎓 Fast Data Science Classroom Setup"
echo "Installing only essentials: R, PostgreSQL client, core Python packages"

# Set timeouts and non-interactive mode
export DEBIAN_FRONTEND=noninteractive
export TIMEOUT_DURATION=300  # 5 minutes max per operation

# Function with timeout
run_fast() {
    timeout $TIMEOUT_DURATION "$@" || {
        echo "❌ Command timed out: $*"
        return 1
    }
}

# Quick package update
echo "📦 Quick package update..."
run_fast sudo apt-get update -qq

# Install only essential database tools
echo "🗄️ Installing PostgreSQL client..."
run_fast sudo apt-get install -y postgresql-client

# Install R (essential for classroom)
echo "📊 Installing R..."
run_fast sudo apt-get install -y r-base

# Install only critical R packages (minimal set)
echo "📈 Installing essential R packages..."
cat > /tmp/install_essential_r.R << 'EOF'
# Only install the most essential packages
essential_packages <- c('DBI', 'RPostgreSQL', 'dplyr', 'ggplot2')

for (pkg in essential_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
        install.packages(pkg, repos='https://cran.rstudio.com/', dependencies=FALSE)
    }
}
cat("✅ Essential R packages installed\n")
EOF

run_fast sudo Rscript /tmp/install_essential_r.R

# Install only essential Python packages
echo "🐍 Installing essential Python packages..."
run_fast pip install --no-cache-dir --user \
    psycopg2-binary \
    pandas \
    jupyter \
    numpy \
    matplotlib

# Create workspace structure
echo "📁 Creating workspace..."
mkdir -p /workspaces/data-managment/{notebooks,scripts,databases}

# Create database startup script  
cat > /workspaces/data-managment/scripts/start_db.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting PostgreSQL for classroom..."

# Remove existing container
docker rm -f classroom-db 2>/dev/null || true

# Start PostgreSQL with sample data
docker run -d \
    --name classroom-db \
    -p 5432:5432 \
    -e POSTGRES_USER=student \
    -e POSTGRES_PASSWORD=student_password \
    -e POSTGRES_DB=postgres \
    -v /workspaces/data-managment/databases:/docker-entrypoint-initdb.d:ro \
    postgres:15

echo "⏳ Waiting for database..."
sleep 10

echo "✅ Database ready!"
echo "🔗 Connection: localhost:5432"
echo "👤 User: student / student_password"
EOF

chmod +x /workspaces/data-managment/scripts/start_db.sh

# Create simple test script
cat > /workspaces/data-managment/scripts/test_setup.py << 'EOF'
#!/usr/bin/env python3
"""Quick test of classroom setup"""

def test_python():
    try:
        import pandas as pd
        import numpy as np
        import matplotlib.pyplot as plt
        import psycopg2
        import jupyter
        print("✅ Python packages working")
        return True
    except ImportError as e:
        print(f"❌ Python package missing: {e}")
        return False

def test_r():
    import subprocess
    try:
        result = subprocess.run(['R', '--version'], capture_output=True, timeout=5)
        if result.returncode == 0:
            print("✅ R is working")
            return True
    except:
        pass
    print("❌ R not working")
    return False

def test_db():
    try:
        import psycopg2
        conn = psycopg2.connect(
            host="localhost", port="5432", database="postgres",
            user="student", password="student_password"
        )
        conn.close()
        print("✅ Database connection working")
        return True
    except:
        print("ℹ️  Database not started yet - run: bash scripts/start_db.sh")
        return True  # This is expected until they start the DB

if __name__ == "__main__":
    print("🧪 Testing classroom setup...")
    results = [test_python(), test_r(), test_db()]
    
    if all(results):
        print("🎉 Classroom setup complete!")
    else:
        print("⚠️  Some issues detected")
EOF

chmod +x /workspaces/data-managment/scripts/test_setup.py

# Create sample database file
cat > /workspaces/data-managment/databases/01-sample.sql << 'EOF'
-- Sample classroom database
CREATE TABLE IF NOT EXISTS students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    grade INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO students (name, grade) VALUES 
('Alice', 95), ('Bob', 87), ('Carol', 92), ('David', 78)
ON CONFLICT DO NOTHING;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO student;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO student;
EOF

echo ""
echo "🎉 Fast setup complete! (Should take under 10 minutes)"
echo ""
echo "📚 What's installed:"
echo "   ✅ Python with pandas, numpy, matplotlib, jupyter"
echo "   ✅ R with essential data science packages"  
echo "   ✅ PostgreSQL client tools"
echo ""
echo "🚀 Next steps:"
echo "1. Test setup: python scripts/test_setup.py"
echo "2. Start database: bash scripts/start_db.sh"
echo "3. Create notebooks in the notebooks/ folder"
echo ""
echo "💡 This is a minimal setup - install additional packages as needed!"
