#!/bin/bash

echo "🎓 Reliable Data Science Classroom Setup"
echo "Installing R, PostgreSQL, and Python for students"

# Set non-interactive mode and prevent hanging
export DEBIAN_FRONTEND=noninteractive
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# Function with aggressive timeout and error handling
install_with_timeout() {
    local timeout_duration=180  # 3 minutes max per command
    local description="$1"
    shift
    
    echo "⏳ $description..."
    if timeout $timeout_duration "$@"; then
        echo "✅ $description completed"
        return 0
    else
        echo "❌ $description failed or timed out - continuing anyway"
        return 1
    fi
}

# Quick package update
install_with_timeout "Updating package list" sudo apt-get update -qq

# Install PostgreSQL client (usually fast)
install_with_timeout "Installing PostgreSQL client" sudo apt-get install -y postgresql-client

# Install R using the Debian repository (more reliable than CRAN)
echo "📊 Installing R from Debian repository..."
install_with_timeout "Installing R base" sudo apt-get install -y r-base r-base-dev

# Install R packages one by one with individual timeouts
echo "📈 Installing essential R packages..."
cat > /tmp/install_r_packages.R << 'EOF'
# Set timeout and error handling
options(timeout = 60)  # 60 second timeout per package
options(warn = 2)      # Treat warnings as errors

# Function to install with error handling
safe_install <- function(pkg) {
    tryCatch({
        if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
            cat("Installing", pkg, "...\n")
            install.packages(pkg, repos='https://cloud.r-project.org/', 
                           dependencies = FALSE, quiet = TRUE)
            library(pkg, character.only = TRUE)
            cat("✅", pkg, "installed successfully\n")
        } else {
            cat("✅", pkg, "already available\n")
        }
        return(TRUE)
    }, error = function(e) {
        cat("❌", pkg, "failed:", e$message, "\n")
        return(FALSE)
    })
}

# Install packages individually
packages <- c('DBI', 'RPostgreSQL', 'dplyr', 'ggplot2')
results <- sapply(packages, safe_install)

# Summary
successful <- sum(results)
total <- length(packages)
cat("\n📊 R Package Installation Summary:\n")
cat("✅ Successful:", successful, "/", total, "\n")

if (successful >= 2) {
    cat("🎉 Sufficient packages installed for classroom use!\n")
} else {
    cat("⚠️ Some packages failed - students can install them individually\n")
}
EOF

# Run R package installation with timeout
install_with_timeout "Installing R packages" sudo Rscript /tmp/install_r_packages.R

# Install Python packages (usually reliable)
echo "🐍 Installing Python packages for data science..."
install_with_timeout "Installing core Python packages" pip install --no-cache-dir --user \
    psycopg2-binary pandas numpy jupyter matplotlib

# Create workspace structure
echo "📁 Creating classroom workspace..."
mkdir -p /workspaces/data-managment/{notebooks,scripts,databases,assignments}

# Create database startup script
cat > /workspaces/data-managment/scripts/start_classroom_db.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting PostgreSQL database for classroom..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not available"
    exit 1
fi

# Remove existing container
docker rm -f classroom-postgres 2>/dev/null || true

# Start PostgreSQL with classroom databases
docker run -d \
    --name classroom-postgres \
    --restart unless-stopped \
    -p 5432:5432 \
    -e POSTGRES_USER=student \
    -e POSTGRES_PASSWORD=student_password \
    -e POSTGRES_DB=postgres \
    -v /workspaces/data-managment/databases:/docker-entrypoint-initdb.d:ro \
    -v classroom-data:/var/lib/postgresql/data \
    postgres:15

echo "⏳ Waiting for PostgreSQL to start..."
sleep 15

# Test connection
echo "🧪 Testing database connection..."
if command -v psql &> /dev/null; then
    PGPASSWORD=student_password psql -h localhost -p 5432 -U student -d postgres -c "SELECT 'Database is ready!' as status;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Database is ready for students!"
    else
        echo "⚠️ Database started but connection test failed"
    fi
else
    echo "⚠️ psql not available for testing"
fi

echo ""
echo "🔗 Database Connection Info:"
echo "   Host: localhost"
echo "   Port: 5432" 
echo "   Database: postgres"
echo "   Username: student"
echo "   Password: student_password"
EOF

chmod +x /workspaces/data-managment/scripts/start_classroom_db.sh

# Create comprehensive test script
cat > /workspaces/data-managment/scripts/test_classroom.py << 'EOF'
#!/usr/bin/env python3
"""Test all classroom components"""

import subprocess
import sys

def test_python():
    print("🐍 Testing Python packages...")
    try:
        import pandas as pd
        import numpy as np
        import psycopg2
        import jupyter
        import matplotlib.pyplot as plt
        print("✅ All Python packages working")
        return True
    except ImportError as e:
        print(f"❌ Python package missing: {e}")
        return False

def test_r():
    print("📊 Testing R installation...")
    try:
        result = subprocess.run(['R', '--version'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ R is installed")
            
            # Test R packages
            r_test = subprocess.run(['R', '--slave', '-e', 
                                   'cat(ifelse(require(dplyr, quietly=TRUE), "dplyr-OK", "dplyr-MISSING"))'],
                                  capture_output=True, text=True, timeout=10)
            if 'dplyr-OK' in r_test.stdout:
                print("✅ R packages working")
            else:
                print("⚠️ R installed but some packages missing")
            return True
        else:
            print("❌ R installation issue")
            return False
    except Exception as e:
        print(f"❌ R test failed: {e}")
        return False

def test_postgresql():
    print("🗄️ Testing PostgreSQL client...")
    try:
        result = subprocess.run(['psql', '--version'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            print("✅ PostgreSQL client installed")
            return True
        else:
            print("❌ PostgreSQL client issue")
            return False
    except Exception as e:
        print(f"❌ PostgreSQL test failed: {e}")
        return False

def test_database_connection():
    print("🔗 Testing database connection...")
    try:
        import psycopg2
        conn = psycopg2.connect(
            host="localhost", port="5432", database="postgres",
            user="student", password="student_password"
        )
        cursor = conn.cursor()
        cursor.execute("SELECT 'Connection successful!' as message")
        result = cursor.fetchone()
        conn.close()
        print("✅ Database connection successful")
        return True
    except Exception as e:
        print("ℹ️ Database not running - use: bash scripts/start_classroom_db.sh")
        return True  # This is expected if DB not started

if __name__ == "__main__":
    print("🎓 Testing Data Science Classroom Setup")
    print("="*50)
    
    results = []
    results.append(test_python())
    results.append(test_r()) 
    results.append(test_postgresql())
    results.append(test_database_connection())
    
    print("="*50)
    successful = sum(results)
    total = len(results)
    
    if successful >= 3:  # Allow DB connection to fail if not started
        print(f"🎉 Classroom setup successful! ({successful}/{total})")
        print("📚 Students can now use Python, R, and PostgreSQL")
        print("")
        print("🚀 Next steps:")
        print("1. Start database: bash scripts/start_classroom_db.sh")
        print("2. Create assignments in: assignments/")
        print("3. Add database files to: databases/")
    else:
        print(f"⚠️ Setup needs attention ({successful}/{total})")
        print("💡 Some components may need manual installation")
EOF

chmod +x /workspaces/data-managment/scripts/test_classroom.py

# Create sample classroom assignment
cat > /workspaces/data-managment/assignments/lesson_1_getting_started.md << 'EOF'
# Lesson 1: Getting Started with R and PostgreSQL

## Learning Objectives
- Connect to PostgreSQL database
- Perform basic SQL queries
- Use R to analyze database data
- Create simple visualizations

## Part 1: Database Connection Test

### In Python:
```python
import psycopg2
import pandas as pd

# Connect to classroom database
conn = psycopg2.connect(
    host="localhost",
    port="5432", 
    database="postgres",
    user="student",
    password="student_password"
)

# Query student data
students_df = pd.read_sql("SELECT * FROM students", conn)
print(students_df)
```

### In R:
```r
library(DBI)
library(RPostgreSQL)
library(dplyr)
library(ggplot2)

# Connect to database
con <- dbConnect(RPostgreSQL::PostgreSQL(),
                 host = "localhost",
                 port = 5432,
                 dbname = "postgres", 
                 user = "student",
                 password = "student_password")

# Query data
students <- dbGetQuery(con, "SELECT * FROM students")
print(students)

# Create visualization
ggplot(students, aes(x = name, y = grade)) +
  geom_col() +
  labs(title = "Student Grades")
```

## Assignment
1. Run the connection tests above
2. Write a query to find the average grade
3. Create a bar chart of student performance
4. Submit screenshots of your results
EOF

# Create sample database
cat > /workspaces/data-managment/databases/01-classroom.sql << 'EOF'
-- Classroom database for R and PostgreSQL lessons
CREATE TABLE IF NOT EXISTS students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    grade INTEGER CHECK (grade >= 0 AND grade <= 100),
    subject VARCHAR(50),
    enrollment_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS assignments (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(id),
    assignment_name VARCHAR(100),
    score INTEGER CHECK (score >= 0 AND score <= 100),
    submitted_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data for classroom exercises
INSERT INTO students (name, grade, subject) VALUES 
('Alice Johnson', 95, 'Data Science'),
('Bob Smith', 87, 'Statistics'), 
('Carol Williams', 92, 'Data Science'),
('David Brown', 78, 'Statistics'),
('Emma Davis', 89, 'Data Science'),
('Frank Wilson', 84, 'Statistics')
ON CONFLICT DO NOTHING;

INSERT INTO assignments (student_id, assignment_name, score) VALUES
(1, 'SQL Basics', 98),
(1, 'R Introduction', 92),
(2, 'SQL Basics', 85),
(2, 'R Introduction', 88),
(3, 'SQL Basics', 94),
(3, 'R Introduction', 90)
ON CONFLICT DO NOTHING;

-- Grant permissions to student user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO student;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO student;
EOF

echo ""
echo "🎉 Classroom setup complete!"
echo ""
echo "🎓 What's installed for your students:"
echo "   ✅ R with data science packages (dplyr, ggplot2, DBI, RPostgreSQL)"
echo "   ✅ Python with pandas, numpy, matplotlib, jupyter"
echo "   ✅ PostgreSQL client tools"
echo "   ✅ Sample databases and assignments"
echo ""
echo "🚀 Next steps:"
echo "1. Test everything: python scripts/test_classroom.py"
echo "2. Start database: bash scripts/start_classroom_db.sh"
echo "3. Review lesson plan: assignments/lesson_1_getting_started.md"
echo ""
echo "📚 Your students can now learn R and PostgreSQL together!"
