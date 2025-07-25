pkg install git
nano fix_termux_build.sh
chmod +x fix_termux_build.sh
./fix_termux_build.sh
termux-setup-storage
java -version
echo $JAVA_HOME
echo $PATH
#!/data/data/com.termux/files/usr/bin/bash

# Termux-ready script to fix Gradle build error: Unsupported class file major version 65
# Installs SDKMAN, Java 17.0.12-tem, configures environment, and builds termux-app

set -e  # Exit on error

# Define project directory
PROJECT_DIR="$HOME/termux-app"
# Define SDKMAN and Java paths
SDKMAN_DIR="/data/data/com.termux/files/usr/local/sdkman"
JAVA_VERSION="17.0.12-tem"
JAVA_HOME="$SDKMAN_DIR/candidates/java/$JAVA_VERSION"

echo "Starting Termux-ready setup for termux-app build..."

# Step 1: Install or update SDKMAN
if [ -d "$SDKMAN_DIR" ]; then
    echo "SDKMAN found at $SDKMAN_DIR. Updating..."
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    sdk selfupdate force || {
        echo "Failed to update SDKMAN. Exiting."
        exit 1
    }
else
    echo "Installing SDKMAN..."
    pkg_install_curl=$(pkg_install_curl 2>/dev/null || command -v curl)
    if [ -z "$pkg_install_curl" ]; then
        echo "Installing curl..."
        pkg install curl -y || {
            echo "Failed to install curl. Please install it manually with 'pkg install curl'."
            exit 1
        }
    }
    curl -s "https://get.sdkman.io" | bash || {
        echo "Failed to install SDKMAN. Check your internet connection."
        exit 1
    }
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
fi

# Verify SDKMAN installation
sdk_version=$(sdk version 2>/dev/null) || {
    echo "SDKMAN initialization failed. Check $SDKMAN_DIR/bin/sdkman-init.sh."
    exit 1
}
echo "SDKMAN version: $sdk_version"

# Step 2: Install Java 17.0.12-tem
if sdk list java | grep -q "$JAVA_VERSION"; then
    if sdk list java | grep -q "* $JAVA_VERSION"; then
        echo "Java $JAVA_VERSION already installed."
    else
        echo "Installing Java $JAVA_VERSION..."
        sdk install java $JAVA_VERSION || {
            echo "Failed to install Java $JAVA_VERSION. Check SDKMAN and internet connection."
            exit 1
        }
    fi
else
    echo "Java $JAVA_VERSION not found in SDKMAN candidates."
    exit 1
fi

# Step 3: Activate Java 17
echo "Activating Java $JAVA_VERSION..."
sdk use java $JAVA_VERSION || {
    echo "Failed to activate Java $JAVA_VERSION."
    exit 1
}
# Set JAVA_HOME and PATH
export JAVA_HOME="$JAVA_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

# Verify Java version
java_version=$(java -version 2>&1 | head -n 1)
if [[ "$java_version" == *"17.0.12"* ]]; then
    echo "Java version verified: $java_version"
else
    echo "Java version mismatch. Expected 17.0.12, got $java_version."
    exit 1
fi

# Step 4: Persist environment variables in Termux profile
TERMUX_PROFILE="$HOME/.bashrc"
if ! grep -q "JAVA_HOME=$JAVA_HOME" "$TERMUX_PROFILE"; then
    echo "Adding JAVA_HOME and PATH to $TERMUX_PROFILE..."
    echo "export JAVA_HOME=$JAVA_HOME" >> "$TERMUX_PROFILE"
    echo "export PATH=$JAVA_HOME/bin:\$PATH" >> "$TERMUX_PROFILE"
    echo "source $SDKMAN_DIR/bin/sdkman-init.sh" >> "$TERMUX_PROFILE"
fi
source "$TERMUX_PROFILE"

# Step 5: Clear Gradle cache
echo "Clearing Gradle cache..."
rm -rf "$HOME/.gradle/caches" || {
    echo "Failed to clear Gradle cache. Continuing anyway..."
}

# Step 6: Verify project directory
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Project directory $PROJECT_DIR not found. Please ensure termux-app is cloned."
    exit 1
fi
cd "$PROJECT_DIR" || {
    echo "Failed to change to $PROJECT_DIR."
    exit 1
}

# Step 7: Run Gradle build
echo "Running Gradle clean build..."
if [ ! -f "./gradlew" ]; then
    echo "gradlew not found in $PROJECT_DIR. Ensure the Gradle wrapper is present."
    exit 1
fi
chmod +x ./gradlew
./gradlew clean build || {
    echo "Gradle build failed. Running with debug output..."
    ./gradlew clean build --stacktrace --debug > build_debug.log 2>&1
    echo "Debug output saved to $PROJECT_DIR/build_debug.log."
    echo "Please share build_debug.log for further assistance."
    exit 1
}

echo "Build completed successfully!"
echo "To verify, check the build output in $PROJECT_DIR/build."
echo "If you use VS Code, set 'java.home' to $JAVA_HOME in settings."
