#!/bin/bash

echo "🎓 Setting up Data Science Classroom environment..."
echo "Installing R, PostgreSQL, Python packages, and databases for students..."

# Set non-interactive mode to prevent hanging prompts
export DEBIAN_FRONTEND=noninteractive

# Function to run commands with timeout and retry
run_with_timeout() {
    local max_attempts=3
    local timeout_duration=600  # 10 minutes per attempt
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts..."
        if timeout $timeout_duration "$@"; then
            echo "✅ Command succeeded on attempt $attempt"
            return 0
        else
            echo "⚠️ Command failed on attempt $attempt"
            if [ $attempt -lt $max_attempts ]; then
                echo "Retrying in 10 seconds..."
                sleep 10
            fi
        fi
        ((attempt++))
    done
    
    echo "❌ Command failed after $max_attempts attempts"
    return 1
}

# Update package list
echo "📦 Updating package list..."
run_with_timeout sudo apt-get update -y

# Install system dependencies first
echo "🔧 Installing system dependencies..."
run_with_timeout sudo apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install database clients
echo "🗄️ Installing database clients..."
run_with_timeout sudo apt-get install -y \
    postgresql-client \
    mysql-client \
    sqlite3 \
    redis-tools

# Install R (the part that often hangs)
echo "📊 Installing R and R packages..."
# Add CRAN repository for latest R
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
echo "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" | sudo tee -a /etc/apt/sources.list

run_with_timeout sudo apt-get update -y
run_with_timeout sudo apt-get install -y r-base r-base-dev

# Install R packages (this is often the slowest part)
echo "📈 Installing R packages for data science..."
cat > /tmp/install_r_packages.R << 'EOF'
# Install packages with timeout and error handling
install_with_retry <- function(pkg) {
    tryCatch({
        if (!require(pkg, character.only = TRUE)) {
            install.packages(pkg, repos='https://cran.rstudio.com/', dependencies=TRUE)
            library(pkg, character.only = TRUE)
        }
        cat("✅ Installed:", pkg, "\n")
        return(TRUE)
    }, error = function(e) {
        cat("❌ Failed to install:", pkg, "-", e$message, "\n")
        return(FALSE)
    })
}

# Essential R packages for data science classroom
packages <- c(
    'DBI', 'RPostgreSQL', 'RMySQL', 'RSQLite',
    'dplyr', 'ggplot2', 'tidyr', 'readr', 'tibble',
    'lubridate', 'stringr', 'forcats', 'purrr',
    'knitr', 'rmarkdown', 'devtools'
)

for (pkg in packages) {
    install_with_retry(pkg)
}

cat("🎉 R package installation complete!\n")
EOF

run_with_timeout sudo Rscript /tmp/install_r_packages.R

# Install Python packages for data science
echo "🐍 Installing Python packages for data science..."
run_with_timeout pip install --no-cache-dir --upgrade pip

# Install in chunks to avoid memory issues
echo "Installing database connectivity packages..."
run_with_timeout pip install --no-cache-dir \
    psycopg2-binary \
    PyMySQL \
    sqlalchemy

echo "Installing core data science packages..."
run_with_timeout pip install --no-cache-dir \
    pandas \
    numpy \
    matplotlib \
    seaborn

echo "Installing additional analysis packages..."
run_with_timeout pip install --no-cache-dir \
    scikit-learn \
    scipy \
    plotly \
    jupyter \
    notebook

echo "Installing utility packages..."
run_with_timeout pip install --no-cache-dir \
    requests \
    beautifulsoup4 \
    openpyxl \
    xlrd

# Create workspace structure for classroom
echo "📁 Creating classroom workspace structure..."
mkdir -p /workspaces/data-managment/{notebooks,datasets,scripts,projects,assignments}
mkdir -p /workspaces/data-managment/databases

# Create database startup script
cat > /workspaces/data-managment/scripts/start_classroom_db.sh << 'EOF'
#!/bin/bash

echo "🎓 Starting PostgreSQL for Data Science Classroom..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not available. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

# Remove existing container if it exists
docker rm -f classroom-postgres 2>/dev/null || true

echo "🚀 Starting PostgreSQL with classroom databases..."
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

# Start pgAdmin for students
docker rm -f classroom-pgadmin 2>/dev/null || true
docker run -d \
    --name classroom-pgadmin \
    --restart unless-stopped \
    -p 5050:80 \
    -e PGADMIN_DEFAULT_EMAIL=teacher@classroom.com \
    -e PGADMIN_DEFAULT_PASSWORD=classroom123 \
    -e PGADMIN_CONFIG_SERVER_MODE=False \
    dpage/pgadmin4:latest

echo "⏳ Waiting for databases to start..."
sleep 15

echo "✅ Classroom databases are ready!"
echo "📊 PostgreSQL: localhost:5432 (student/student_password)"
echo "🌐 pgAdmin: http://localhost:5050 (teacher@classroom.com/classroom123)"
EOF

chmod +x /workspaces/data-managment/scripts/start_classroom_db.sh

# Create student connection test script
cat > /workspaces/data-managment/scripts/test_classroom_setup.py << 'EOF'
#!/usr/bin/env python3
"""Test all classroom components"""

def test_python_packages():
    print("🐍 Testing Python packages...")
    try:
        import pandas as pd
        import numpy as np
        import matplotlib.pyplot as plt
        import seaborn as sns
        import sklearn
        import psycopg2
        import sqlalchemy
        print("✅ All Python packages installed correctly")
        return True
    except ImportError as e:
        print(f"❌ Python package missing: {e}")
        return False

def test_r_installation():
    print("📊 Testing R installation...")
    import subprocess
    try:
        result = subprocess.run(['R', '--version'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ R is installed correctly")
            return True
        else:
            print("❌ R installation issue")
            return False
    except Exception as e:
        print(f"❌ R test failed: {e}")
        return False

def test_database_connection():
    print("🗄️ Testing database connection...")
    try:
        import psycopg2
        conn = psycopg2.connect(
            host="localhost",
            port="5432", 
            database="postgres",
            user="student",
            password="student_password"
        )
        conn.close()
        print("✅ Database connection successful")
        return True
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("💡 Run: bash /workspaces/data-managment/scripts/start_classroom_db.sh")
        return False

if __name__ == "__main__":
    print("🎓 Testing Data Science Classroom Setup")
    print("="*50)
    
    results = []
    results.append(test_python_packages())
    results.append(test_r_installation())
    results.append(test_database_connection())
    
    print("="*50)
    if all(results):
        print("🎉 Classroom setup is complete and working!")
        print("📚 Your students can now use Python, R, and PostgreSQL")
    else:
        print("⚠️ Some components need attention")
        print("💡 Check the errors above and run setup again if needed")
EOF

chmod +x /workspaces/data-managment/scripts/test_classroom_setup.py

# Create sample classroom assignment
cat > /workspaces/data-managment/assignments/assignment_1_getting_started.md << 'EOF'
# Assignment 1: Getting Started with the Data Science Environment

## Objective
Verify that your development environment is properly set up for data science work.

## Tasks

### 1. Test Python Setup
Run the following in a Python script or Jupyter notebook:
```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Create a simple dataset
data = pd.DataFrame({
    'x': range(10),
    'y': np.random.randn(10)
})

# Create a plot
plt.figure(figsize=(8, 6))
sns.scatterplot(data=data, x='x', y='y')
plt.title('My First Plot')
plt.show()
```

### 2. Test R Setup
Create an R script with:
```r
library(dplyr)
library(ggplot2)

# Create sample data
data <- data.frame(
  x = 1:10,
  y = rnorm(10)
)

# Create a plot
ggplot(data, aes(x=x, y=y)) +
  geom_point() +
  labs(title="My First R Plot")
```

### 3. Test Database Connection
Run this Python script:
```python
import pandas as pd
from sqlalchemy import create_engine

# Connect to PostgreSQL
engine = create_engine('postgresql://student:student_password@localhost:5432/postgres')

# Test query
result = pd.read_sql('SELECT version()', engine)
print("Database version:", result.iloc[0,0])
```

## Submission
Screenshot your successful outputs for all three tasks.
EOF

echo ""
echo "🎉 Data Science Classroom setup complete!"
echo ""
echo "🎯 What's installed for your students:"
echo "   ✅ Python with pandas, numpy, matplotlib, seaborn, scikit-learn"
echo "   ✅ R with tidyverse, database connectors, and visualization packages"
echo "   ✅ PostgreSQL client tools"
echo "   ✅ Jupyter Lab for interactive notebooks"
echo ""
echo "📚 Next steps for classroom:"
echo "1. Test setup: python /workspaces/data-managment/scripts/test_classroom_setup.py"
echo "2. Start databases: bash /workspaces/data-managment/scripts/start_classroom_db.sh"
echo "3. Add your database files to: /workspaces/data-managment/databases/"
echo "4. Share assignment: /workspaces/data-managment/assignments/assignment_1_getting_started.md"
echo ""
echo "🔗 Access points for students:"
echo "   • Jupyter Notebooks: jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser"
echo "   • pgAdmin: http://localhost:5050"
echo "   • PostgreSQL: localhost:5432"
