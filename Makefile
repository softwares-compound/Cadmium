# Variables
VENV_DIR = venv
AI_SERVICE_DIR = ai-service
PYTHON = $(VENV_DIR)/bin/python
PIP = $(VENV_DIR)/bin/pip
ELECTRON_DIR = electron-app
ELECTRON_FRONTEND_DIR = $(ELECTRON_DIR)/cadmium-frontend
COMPILED_BACKEND_DIR = $(ELECTRON_DIR)/compiled-backend
BIN_DIR = bin  # Output directory for compiled backend

# Commands
PYTHON = python3
PIP = $(VENV_DIR)/bin/pip
NPM = npm

# Setup virtual environment for AI Service
.PHONY: setup-venv
setup-venv:
	@echo "Creating Python virtual environment..."
	@if [ ! -d "$(VENV_DIR)" ]; then $(PYTHON) -m venv $(VENV_DIR); fi
	@echo "Installing Python dependencies..."
	@$(PIP) install --upgrade pip
	@$(PIP) install -r $(AI_SERVICE_DIR)/dev-requirements.in

# Install Node.js dependencies for Electron App
.PHONY: install-node-modules
install-node-modules:
	@echo "Installing Node.js dependencies..."
	@cd $(ELECTRON_DIR) && $(NPM) install
	@cd $(ELECTRON_FRONTEND_DIR) && $(NPM) install 

# Create shared directories
.PHONY: create-shared-dirs
create-shared-dirs:
	@echo "Creating shared directories..."
	@mkdir -p $(COMPILED_BACKEND_DIR)

# Initialize the environment (setup everything)
.PHONY: init
init: setup-venv install-node-modules create-shared-dirs
	@echo "Environment setup completed!"

# Compile the AI Service (Backend)
.PHONY: compile-ai-service
compile-ai-service:
	@echo "Compiling backend with Nuitka..."
	. $(VENV_DIR)/bin/activate && cd $(AI_SERVICE_DIR) && \
	nuitka --standalone --include-package=websockets --include-package=websockets.asyncio.client \
	       --output-dir=$(BIN_DIR) app/main.py

# Copy compiled backend to Electron app directory
.PHONY: build-backend
build-backend: compile-ai-service
	@echo "Copying compiled backend to Electron app directory..."
	@mkdir -p $(COMPILED_BACKEND_DIR)
	@cp -r $(AI_SERVICE_DIR)/$(BIN_DIR)/* $(COMPILED_BACKEND_DIR)

# Build the Electron App (Frontend)
.PHONY: build-electron
build-electron: build-backend
	@echo "Building the Electron app..."
	@cd $(ELECTRON_DIR) && $(NPM) run build

# Package the Electron App (with Backend)
.PHONY: package
package: build-electron
	@echo "Packaging the Electron app..."
	@cd $(ELECTRON_DIR) && $(NPM) run package

# Ensure Ollama is running
.PHONY: ensure-ollama
ensure-ollama:
	@echo "Checking if Ollama is running..."
	@if ! pgrep -x "ollama" > /dev/null; then \
		echo "Starting Ollama..."; \
		ollama start & \
		sleep 2; \
	else \
		echo "Ollama is already running."; \
	fi

# Start AI Service
.PHONY: start-ai-service
start-ai-service: ensure-ollama
	@echo "Starting AI Service..."
	@. $(VENV_DIR)/bin/activate && PYTHONPATH=$(shell pwd)/$(AI_SERVICE_DIR) $(PYTHON) $(AI_SERVICE_DIR)/app/main.py

# Start Electron App
.PHONY: start-electron-app
start-electron-app:
	@echo "Starting Electron App..."
	@cd $(ELECTRON_DIR) && $(NPM) run dev

# Start all services (Backend, Electron App, and Ollama)
.PHONY: start-all
start-all:
	@echo "Starting all services..."
	@make ensure-ollama && \
	(. $(VENV_DIR)/bin/activate && PYTHONPATH=$(shell pwd)/$(AI_SERVICE_DIR) $(PYTHON) $(AI_SERVICE_DIR)/app/main.py) & \
	(cd $(ELECTRON_DIR) && $(NPM) run dev)

# Clean up build artifacts
.PHONY: clean
clean:
	@echo "Cleaning up environment and build artifacts..."
	@rm -rf $(VENV_DIR)
	@rm -rf $(ELECTRON_DIR)/node_modules
	@rm -rf $(COMPILED_BACKEND_DIR)
	@rm -rf $(AI_SERVICE_DIR)/$(BIN_DIR)
	@cd $(AI_SERVICE_DIR) && make clean
	@cd $(ELECTRON_DIR) && $(NPM) run clean
	@echo "Clean up completed!"

# Generate a directory tree excluding node_modules, venv, and __pycache__
.PHONY: print-tree
print-tree:
	@echo "Generating filtered directory tree..."
	@tree -I "node_modules|venv|__pycache__" | tee directory_tree.txt | pbcopy
	@echo "Directory tree copied to clipboard and saved to 'directory_tree.txt'."

# Install dependencies via script
.PHONY: install-dependencies
install-dependencies:
	@echo "Running dependency installation script..."
	@bash scripts/install_dependencies.sh
