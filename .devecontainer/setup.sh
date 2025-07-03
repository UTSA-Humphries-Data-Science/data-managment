#!/bin/bash

# Dev Container Setup Script for Data Science Classroom
# This runs once when the container is created

set -e

echo "🚀 Setting up Data Science Environment in Codespace..."
echo "======================================================"

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Install additional system dependencies
echo "🔧 Installing system dependencies..."
sudo apt-get install -y \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    unzip \
    tree \
    htop \
    jq \
    postgresql-client \
    sqlite3

# Install PostgreSQL
echo "🐘 Installing PostgreSQL..."
sudo apt-get install -y postgresql postgresql-contrib
sudo service postgresql start

# Configure PostgreSQL for Codespace
echo "⚙️ Configuring PostgreSQL..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"

# Get unique identifier for this student
if [ ! -z "$GITHUB_USER" ]; then
    STUDENT_ID="$GITHUB_USER"
elif [ ! -z "$CODESPACE_NAME" ]; then
    STUDENT_ID=$(echo "$CODESPACE_NAME" | cut -d'-' -f1)
else
    STUDENT_ID="student$(date +%s)"
fi

# Convert to lowercase and remove special characters
STUDENT_ID=$(echo "$STUDENT_ID" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
DB_NAME="${STUDENT_ID}_db"
DB_USER="$STUDENT_ID"
DB_PASSWORD="${STUDENT_ID}_$(openssl rand -hex 4)"

echo "Creating database for student: $STUDENT_ID"

# Create user and database
sudo -u postgres createuser --createdb --login "$DB_USER" 2>/dev/null || echo "User '$DB_USER' already exists"
sudo -u postgres psql -c "ALTER USER $DB_USER PASSWORD '$DB_PASSWORD';"
sudo -u postgres createdb "$DB_NAME" --owner="$DB_USER" 2>/dev/null || echo "Database '$DB_NAME' already exists"

# Grant necessary permissions
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;"

# Store credentials
cat > ~/.pg_credentials << EOF
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=$DB_NAME
export PGUSER=$DB_USER
export PGPASSWORD=$DB_PASSWORD
EOF

echo "✅ PostgreSQL configured for student: $STUDENT_ID"

# Install Python packages
echo "🐍 Installing Python data science packages..."
pip install --upgrade pip setuptools wheel

# Core data science packages
pip install \
    jupyter \
    jupyterlab \
    notebook \
    pandas \
    numpy \
    scipy \
    matplotlib \
    seaborn \
    plotly \
    bokeh \
    altair \
    scikit-learn \
    statsmodels \
    tensorflow \
    torch \
    transformers \
    xgboost \
    lightgbm \
    catboost

# Database packages
pip install \
    sqlalchemy \
    psycopg2-binary \
    pymongo \
    redis

# Additional packages
pip install \
    requests \
    beautifulsoup4 \
    openpyxl \
    xlrd \
    pyyaml \
    python-dotenv \
    streamlit \
    dash \
    fastapi \
    uvicorn \
    black \
    flake8 \
    pytest \
    ipykernel \
    jupyter-dash \
    jupyterlab-git \
    ipywidgets

# Install R packages
echo "📈 Installing R packages..."
sudo Rscript -e "
if (!require('pacman', quietly = TRUE)) install.packages('pacman', repos='https://cran.rstudio.com/')
pacman::p_load(
    tidyverse,
    dplyr,
    ggplot2,
    plotly,
    shiny,
    shinydashboard,
    DT,
    leaflet,
    rmarkdown,
    knitr,
    devtools,
    here,
    janitor,
    lubridate,
    readxl,
    writexl,
    jsonlite,
    httr,
    rvest,
    DBI,
    RPostgreSQL,
    RSQLite,
    dbplyr,
    caret,
    randomForest,
    xgboost,
    tidymodels,
    update = FALSE
)
"

# Configure Jupyter with both Python and R kernels
echo "🔧 Configuring Jupyter..."
python -m ipykernel install --user --name=python3 --display-name="Python 3"

# Install R kernel for Jupyter
echo "📊 Installing R kernel for Jupyter..."
sudo Rscript -e "
install.packages('IRkernel', repos='https://cran.rstudio.com/')
IRkernel::installspec(user = FALSE)
"

# Create Jupyter config for Codespace
mkdir -p ~/.jupyter
cat > ~/.jupyter/jupyter_lab_config.py << 'EOF'
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.allow_root = False
c.ServerApp.allow_origin = '*'
c.ServerApp.disable_check_xsrf = True
EOF

# Install RStudio Server
echo "💻 Installing RStudio Server..."
cd /tmp
wget -q https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2023.12.1-402-amd64.deb
sudo dpkg -i rstudio-server-2023.12.1-402-amd64.deb || sudo apt-get install -f -y
rm rstudio-server-2023.12.1-402-amd64.deb

# Configure RStudio for Codespace
sudo tee /etc/rstudio/rserver.conf > /dev/null << 'EOF'
www-port=8787
www-address=0.0.0.0
auth-none=1
auth-validate-users=0
server-user=codespace
EOF

sudo systemctl enable rstudio-server
sudo systemctl start rstudio-server

# Create project structure
echo "📁 Creating project structure..."
mkdir -p /workspaces/$(basename $GITHUB_REPOSITORY)/{data,notebooks,scripts,docs,tests,assignments}
mkdir -p /workspaces/$(basename $GITHUB_REPOSITORY)/data/{raw,processed,external}

# Create database management script
cat > /workspaces/$(basename $GITHUB_REPOSITORY)/db-manager.sh << 'EOF'
#!/bin/bash

# Database Management Helper Script for Codespace
source ~/.pg_credentials 2>/dev/null || { echo "❌ Database credentials not found"; exit 1; }

case "$1" in
    "list")
        echo "📋 Your databases:"
        psql -h $PGHOST -p $PGPORT -U $PGUSER -d postgres -c "\l" | grep $PGUSER
        ;;
    "create")
        if [ -z "$2" ]; then
            echo "Usage: ./db-manager.sh create <database_name>"
            exit 1
        fi
        DB_NAME="${PGUSER}_$2"
        echo "🔨 Creating database: $DB_NAME"
        createdb -h $PGHOST -p $PGPORT -U $PGUSER $DB_NAME
        echo "✅ Database $DB_NAME created successfully!"
        ;;
    "connect")
        if [ -z "$2" ]; then
            psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE
        else
            DB_NAME="${PGUSER}_$2"
            psql -h $PGHOST -p $PGPORT -U $PGUSER -d $DB_NAME
        fi
        ;;
    *)
        echo "Usage: ./db-manager.sh [list|create|connect] [database_name]"
        ;;
esac
EOF

chmod +x /workspaces/$(basename $GITHUB_REPOSITORY)/db-manager.sh

# Create environment setup script
cat > /workspaces/$(basename $GITHUB_REPOSITORY)/setup-env.sh << 'EOF'
#!/bin/bash
# Load database credentials and set up environment

source ~/.pg_credentials

echo "✅ Data Science Environment Ready!"
echo "Database: $PGDATABASE | User: $PGUSER"
echo ""
echo "Quick commands:"
echo "  jupyter lab --ip=0.0.0.0 --port=8888"
echo "  ./db-manager.sh list"
echo "  ./db-manager.sh create myproject"
EOF

chmod +x /workspaces/$(basename $GITHUB_REPOSITORY)/setup-env.sh

# Create sample files
cat > /workspaces/$(basename $GITHUB_REPOSITORY)/README.md << 'EOF'
# Data Science Classroom Environment

Welcome to your personal data science environment! This Codespace includes:

## 🛠️ Available Tools
- **Python 3.11** with comprehensive data science packages
- **R** with tidyverse and statistical packages
- **Jupyter Lab** - Access at port 8888
- **RStudio Server** - Access at port 8787  
- **PostgreSQL** - Your personal database server
- **VSCode** with data science extensions

## 🚀 Getting Started

### 1. Setup Environment
```bash
./setup-env.sh
```

### 2. Start Jupyter Lab
```bash
jupyter lab --ip=0.0.0.0 --port=8888
```

### 3. Access RStudio
Click on the "Ports" tab and open port 8787

### 4. Database Management
```bash
./db-manager.sh list                 # List your databases
./db-manager.sh create assignment1   # Create new database
./db-manager.sh connect assignment1  # Connect to database
```

## 📁 Project Structure
```
├── data/
│   ├── raw/          # Raw data files
│   ├── processed/    # Cleaned data
│   └── external/     # External datasets
├── notebooks/        # Jupyter notebooks  
├── scripts/          # Python/R scripts
├── assignments/      # Course assignments
├── docs/            # Documentation
└── tests/           # Test files
```

## 🔗 Useful Links
- [Jupyter Lab](../../ports/8888) - Interactive notebooks
- [RStudio](../../ports/8787) - R development environment

Happy coding! 🎯
EOF

# Create sample notebook
cat > /workspaces/$(basename $GITHUB_REPOSITORY)/notebooks/welcome.ipynb << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Welcome to Your Data Science Environment! 🚀\n",
    "\n",
    "This notebook will help you test your environment setup."
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Test Python packages\n",
    "import pandas as pd\n",
    "import numpy as np\n",
    "import matplotlib.pyplot as plt\n",
    "import seaborn as sns\n",
    "from sqlalchemy import create_engine\n",
    "import os\n",
    "\n",
    "print(\"✅ All imports successful!\")\n",
    "print(f\"Pandas: {pd.__version__}\")\n",
    "print(f\"NumPy: {np.__version__}\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Test database connection\n",
    "exec(open('/home/codespace/.pg_credentials').read())\n",
    "\n",
    "try:\n",
    "    db_url = f\"postgresql://{os.environ['PGUSER']}:{os.environ['PGPASSWORD']}@{os.environ['PGHOST']}:{os.environ['PGPORT']}/{os.environ['PGDATABASE']}\"\n",
    "    engine = create_engine(db_url)\n",
    "    \n",
    "    with engine.connect() as conn:\n",
    "        result = conn.execute('SELECT version()')\n",
    "        version = result.fetchone()[0]\n",
    "        print(\"✅ Database connection successful!\")\n",
    "        print(f\"Connected to: {os.environ['PGDATABASE']}\")\n",
    "        print(f\"PostgreSQL version: {version.split(',')[0]}\")\n",
    "        \n",
    "except Exception as e:\n",
    "    print(f\"❌ Database connection failed: {e}\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Create sample data and visualization\n",
    "np.random.seed(42)\n",
    "data = {\n",
    "    'x': np.random.randn(100),\n",
    "    'y': np.random.randn(100),\n",
    "    'category': np.random.choice(['A', 'B', 'C'], 100)\n",
    "}\n",
    "\n",
    "df = pd.DataFrame(data)\n",
    "\n",
    "plt.figure(figsize=(10, 6))\n",
    "sns.scatterplot(data=df, x='x', y='y', hue='category')\n",
    "plt.title('Sample Data Visualization')\n",
    "plt.show()\n",
    "\n",
    "print(\"✅ Visualization working!\")"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.11.0"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF

echo ""
echo "🎉 Data Science Environment Setup Complete!"
echo "============================================="
echo ""
echo "📋 What's been installed:"
echo "  ✅ Python with data science packages"
echo "  ✅ R with tidyverse"
echo "  ✅ PostgreSQL database (student: $STUDENT_ID)"  
echo "  ✅ Jupyter Lab (port 8888)"
echo "  ✅ RStudio Server (port 8787)"
echo "  ✅ VSCode extensions"
echo "  ✅ Project struc
